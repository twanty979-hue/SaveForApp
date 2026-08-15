package handlers

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

const maxAvatarSize = 5 << 20

type r2Config struct {
	accountID string
	accessKey string
	secretKey string
	bucket    string
	publicURL string
}

func loadR2Config() (r2Config, error) {
	cfg := r2Config{
		accountID: strings.TrimSpace(os.Getenv("CLOUDFLARE_ACCOUNT_ID")),
		accessKey: strings.TrimSpace(os.Getenv("CLOUDFLARE_R2_ACCESS_KEY_ID")),
		secretKey: strings.TrimSpace(os.Getenv("CLOUDFLARE_R2_SECRET_ACCESS_KEY")),
		bucket:    strings.TrimSpace(os.Getenv("CLOUDFLARE_R2_BUCKET_NAME")),
		publicURL: strings.TrimRight(strings.TrimSpace(os.Getenv("CLOUDFLARE_R2_PUBLIC_URL")), "/"),
	}
	if cfg.accountID == "" || cfg.accessKey == "" || cfg.secretKey == "" || cfg.bucket == "" || cfg.publicURL == "" {
		return r2Config{}, fmt.Errorf("Cloudflare R2 configuration is incomplete")
	}
	if parsed, err := url.Parse(cfg.publicURL); err != nil || parsed.Scheme != "https" || parsed.Host == "" {
		return r2Config{}, fmt.Errorf("CLOUDFLARE_R2_PUBLIC_URL must be a valid HTTPS URL")
	}
	return cfg, nil
}

func handleGetProfileAvatar(c *gin.Context) {
	userID, ok := authenticatedUserID(c)
	if !ok {
		return
	}
	cfg, err := loadR2Config()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	objectKey := avatarObjectKey(userID)
	status, _, err := doR2Request(cfg, http.MethodHead, objectKey, "", nil)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to check profile image"})
		return
	}
	if status == http.StatusNotFound {
		// Fallback: ดึงรูปโปรไฟล์จากตาราง public.profiles ในฐานข้อมูล (เช่น รูป Google avatar)
		supabaseURL := os.Getenv("SUPABASE_URL")
		supabaseKey := os.Getenv("SUPABASE_SERVICE_KEY")
		if supabaseURL != "" && supabaseKey != "" {
			reqProfile, err := http.NewRequest("GET", supabaseURL+"/rest/v1/profiles?id=eq."+userID+"&select=avatar_url", nil)
			if err == nil {
				reqProfile.Header.Set("apikey", supabaseKey)
				reqProfile.Header.Set("Authorization", "Bearer "+supabaseKey)
				respProfile, errProfile := (&http.Client{}).Do(reqProfile)
				if errProfile == nil && respProfile.StatusCode == 200 {
					defer respProfile.Body.Close()
					var profiles []struct {
						AvatarURL *string `json:"avatar_url"`
					}
					if errDec := json.NewDecoder(respProfile.Body).Decode(&profiles); errDec == nil && len(profiles) > 0 && profiles[0].AvatarURL != nil && *profiles[0].AvatarURL != "" {
						c.JSON(http.StatusOK, gin.H{"avatar_url": *profiles[0].AvatarURL})
						return
					}
				}
			}
		}
		c.JSON(http.StatusOK, gin.H{"avatar_url": nil})
		return
	}
	if status < 200 || status >= 300 {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Cloudflare R2 rejected the request"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"avatar_url": avatarClientURL(cfg, objectKey, false)})
}

func handleProfileAvatarFile(c *gin.Context) {
	userID, ok := authenticatedUserID(c)
	if !ok {
		return
	}
	cfg, err := loadR2Config()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	status, imageBytes, err := doR2Request(cfg, http.MethodGet, avatarObjectKey(userID), "", nil)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to load profile image"})
		return
	}
	if status == http.StatusNotFound {
		c.Status(http.StatusNotFound)
		return
	}
	if status < 200 || status >= 300 || len(imageBytes) == 0 || len(imageBytes) > maxAvatarSize {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Cloudflare R2 returned an invalid profile image"})
		return
	}
	contentType := http.DetectContentType(imageBytes)
	if contentType != "image/jpeg" && contentType != "image/png" && contentType != "image/webp" {
		c.JSON(http.StatusUnsupportedMediaType, gin.H{"error": "Unsupported profile image"})
		return
	}
	c.Header("Cache-Control", "private, max-age=3600")
	c.Data(http.StatusOK, contentType, imageBytes)
}

func handleUploadProfileAvatar(c *gin.Context) {
	userID, ok := authenticatedUserID(c)
	if !ok {
		return
	}
	cfg, err := loadR2Config()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxAvatarSize+(1<<20))
	file, header, err := c.Request.FormFile("avatar")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Please attach an image in the avatar field"})
		return
	}
	defer file.Close()
	if header.Size <= 0 || header.Size > maxAvatarSize {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Profile image must not exceed 5 MB"})
		return
	}

	imageBytes, err := io.ReadAll(io.LimitReader(file, maxAvatarSize+1))
	if err != nil || len(imageBytes) == 0 || len(imageBytes) > maxAvatarSize {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Unable to read profile image"})
		return
	}
	contentType := http.DetectContentType(imageBytes)
	if contentType != "image/jpeg" && contentType != "image/png" && contentType != "image/webp" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Only JPG, PNG, and WebP images are supported"})
		return
	}

	objectKey := avatarObjectKey(userID)
	status, responseBody, err := doR2Request(cfg, http.MethodPut, objectKey, contentType, imageBytes)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to upload profile image"})
		return
	}
	if status < 200 || status >= 300 {
		c.JSON(http.StatusBadGateway, gin.H{
			"error":  "Cloudflare R2 rejected the upload",
			"detail": strings.TrimSpace(string(responseBody)),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"avatar_url": avatarClientURL(cfg, objectKey, true),
	})
}

func handleDeleteProfileAvatar(c *gin.Context) {
	userID, ok := authenticatedUserID(c)
	if !ok {
		return
	}
	cfg, err := loadR2Config()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	status, _, err := doR2Request(cfg, http.MethodDelete, avatarObjectKey(userID), "", nil)
	if err != nil || status < 200 || status >= 300 {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to delete profile image"})
		return
	}
	c.Status(http.StatusNoContent)
}

func authenticatedUserID(c *gin.Context) (string, bool) {
	user, ok := authenticatedUserDetails(c)
	if !ok {
		return "", false
	}
	return user.ID, true
}

func avatarObjectKey(userID string) string {
	return "profiles/" + userID + "/avatar"
}

func publicAvatarURL(cfg r2Config, objectKey string) string {
	parts := strings.Split(objectKey, "/")
	for i := range parts {
		parts[i] = url.PathEscape(parts[i])
	}
	return cfg.publicURL + "/" + strings.Join(parts, "/")
}

func avatarClientURL(cfg r2Config, objectKey string, cacheBust bool) string {
	version := ""
	if cacheBust {
		version = "?v=" + fmt.Sprint(time.Now().Unix())
	}
	parsed, err := url.Parse(cfg.publicURL)
	if err != nil || strings.HasSuffix(strings.ToLower(parsed.Hostname()), ".r2.cloudflarestorage.com") {
		return "/profile/avatar/file" + version
	}
	return publicAvatarURL(cfg, objectKey) + version
}

func doR2Request(cfg r2Config, method, objectKey, contentType string, body []byte) (int, []byte, error) {
	now := time.Now().UTC()
	amzDate := now.Format("20060102T150405Z")
	dateStamp := now.Format("20060102")
	payloadHash := sha256Hex(body)
	host := cfg.accountID + ".r2.cloudflarestorage.com"
	canonicalURI := "/" + url.PathEscape(cfg.bucket) + "/" + escapeObjectKey(objectKey)

	canonicalHeaders := "host:" + host + "\n" +
		"x-amz-content-sha256:" + payloadHash + "\n" +
		"x-amz-date:" + amzDate + "\n"
	signedHeaders := "host;x-amz-content-sha256;x-amz-date"
	if contentType != "" {
		canonicalHeaders = "content-type:" + contentType + "\n" + canonicalHeaders
		signedHeaders = "content-type;" + signedHeaders
	}
	canonicalRequest := strings.Join([]string{
		method,
		canonicalURI,
		"",
		canonicalHeaders,
		signedHeaders,
		payloadHash,
	}, "\n")
	credentialScope := dateStamp + "/auto/s3/aws4_request"
	stringToSign := "AWS4-HMAC-SHA256\n" + amzDate + "\n" + credentialScope + "\n" + sha256Hex([]byte(canonicalRequest))
	signingKey := hmacSHA256([]byte("AWS4"+cfg.secretKey), dateStamp)
	signingKey = hmacSHA256(signingKey, "auto")
	signingKey = hmacSHA256(signingKey, "s3")
	signingKey = hmacSHA256(signingKey, "aws4_request")
	signature := hex.EncodeToString(hmacSHA256(signingKey, stringToSign))
	authorization := "AWS4-HMAC-SHA256 Credential=" + cfg.accessKey + "/" + credentialScope +
		", SignedHeaders=" + signedHeaders + ", Signature=" + signature

	req, err := http.NewRequest(method, "https://"+host+canonicalURI, bytes.NewReader(body))
	if err != nil {
		return 0, nil, err
	}
	req.Header.Set("Authorization", authorization)
	req.Header.Set("x-amz-content-sha256", payloadHash)
	req.Header.Set("x-amz-date", amzDate)
	if contentType != "" {
		req.Header.Set("Content-Type", contentType)
		req.Header.Set("Cache-Control", "public, max-age=3600")
	}

	resp, err := (&http.Client{Timeout: 30 * time.Second}).Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer resp.Body.Close()
	readLimit := int64(64 << 10)
	if method == http.MethodGet {
		readLimit = maxAvatarSize + 1
	}
	responseBody, readErr := io.ReadAll(io.LimitReader(resp.Body, readLimit))
	return resp.StatusCode, responseBody, readErr
}

func escapeObjectKey(objectKey string) string {
	parts := strings.Split(objectKey, "/")
	for i := range parts {
		parts[i] = url.PathEscape(parts[i])
	}
	return strings.Join(parts, "/")
}

func sha256Hex(data []byte) string {
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

func hmacSHA256(key []byte, data string) []byte {
	h := hmac.New(sha256.New, key)
	h.Write([]byte(data))
	return h.Sum(nil)
}
