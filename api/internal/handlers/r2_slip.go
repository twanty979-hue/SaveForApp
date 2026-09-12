package handlers

import (
	"fmt"
	"io"
	"net/http"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

const maxSlipSize = 5 << 20 // 5 MB

var sanitizeFilenameRegex = regexp.MustCompile(`[^a-zA-Z0-9_\-]`)

// สร้าง Object Key สำหรับจัดเก็บสลิปโดยแยกโฟลเดอร์ตาม User ID: users/{userID}/slips/{filename}.webp
func slipObjectKey(userID, rawFilename string) string {
	cleanName := filepath.Base(rawFilename)
	ext := filepath.Ext(cleanName)
	base := strings.TrimSuffix(cleanName, ext)
	base = sanitizeFilenameRegex.ReplaceAllString(base, "_")
	if base == "" {
		base = fmt.Sprintf("slip_%d", time.Now().UnixNano())
	}
	// บังคับนามสกุล .webp เพื่อความเบาและรวดเร็ว
	if ext != ".webp" && ext != ".jpg" && ext != ".png" {
		ext = ".webp"
	}
	return fmt.Sprintf("users/%s/slips/%s%s", userID, base, ext)
}

// handleUploadSlipImage รับไฟล์สลิป (WebP/JPG/PNG) และอัปโหลดขึ้น Cloudflare R2 แยกตามไอดีผู้ใช้
func handleUploadSlipImage(c *gin.Context) {
	userID, ok := authenticatedUserID(c)
	if !ok {
		return
	}
	cfg, err := loadR2Config()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxSlipSize+(1<<20))
	file, header, err := c.Request.FormFile("slip")
	if err != nil {
		file, header, err = c.Request.FormFile("image")
	}
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Please attach a slip image in 'slip' or 'image' field"})
		return
	}
	defer file.Close()

	if header.Size <= 0 || header.Size > maxSlipSize {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Slip image size must not exceed 5 MB"})
		return
	}

	imageBytes, err := io.ReadAll(io.LimitReader(file, maxSlipSize+1))
	if err != nil || len(imageBytes) == 0 || len(imageBytes) > maxSlipSize {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Unable to read slip image"})
		return
	}

	contentType := http.DetectContentType(imageBytes)
	if contentType != "image/webp" && contentType != "image/jpeg" && contentType != "image/png" {
		// ตรวจสอบ Magic bytes ของ WebP: RIFF....WEBP
		if len(imageBytes) >= 12 && string(imageBytes[0:4]) == "RIFF" && string(imageBytes[8:12]) == "WEBP" {
			contentType = "image/webp"
		} else {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Only WebP, JPG, and PNG images are supported"})
			return
		}
	}

	rawFilename := c.PostForm("filename")
	if rawFilename == "" {
		rawFilename = c.PostForm("slip_id")
	}
	if rawFilename == "" {
		rawFilename = header.Filename
	}

	objectKey := slipObjectKey(userID, rawFilename)
	status, responseBody, err := doR2Request(cfg, http.MethodPut, objectKey, contentType, imageBytes)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to upload slip image"})
		return
	}
	if status < 200 || status >= 300 {
		c.JSON(http.StatusBadGateway, gin.H{
			"error":  "Cloudflare R2 rejected slip upload",
			"detail": strings.TrimSpace(string(responseBody)),
		})
		return
	}

	fileURL := "/transactions/slip/file?key=" + objectKey
	c.JSON(http.StatusOK, gin.H{
		"url":        fileURL,
		"object_key": objectKey,
		"size":       len(imageBytes),
	})
}

// handleGetSlipImageFile ดึงไฟล์รูปสลิปจาก R2 พร้อมตรวจสอบสิทธิ์ User ID ป้องกันการเข้าถึงข้ามบัญชี
func handleGetSlipImageFile(c *gin.Context) {
	userID, ok := authenticatedUserID(c)
	if !ok {
		return
	}
	cfg, err := loadR2Config()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	objectKey := c.Query("key")
	if objectKey == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Missing 'key' parameter"})
		return
	}

	// ตรวจสอบความปลอดภัยระดับสูงสุด: objectKey ต้องอยู่ใต้ users/{userID}/slips/ ของผู้ใช้คนนี้เท่านั้น
	expectedPrefix := fmt.Sprintf("users/%s/slips/", userID)
	if !strings.HasPrefix(objectKey, expectedPrefix) {
		c.JSON(http.StatusForbidden, gin.H{"error": "Access denied to this slip image"})
		return
	}

	status, imageBytes, err := doR2Request(cfg, http.MethodGet, objectKey, "", nil)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to load slip image from storage"})
		return
	}
	if status == http.StatusNotFound {
		c.Status(http.StatusNotFound)
		return
	}
	if status < 200 || status >= 300 || len(imageBytes) == 0 {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Cloudflare R2 returned invalid slip image"})
		return
	}

	contentType := http.DetectContentType(imageBytes)
	if len(imageBytes) >= 12 && string(imageBytes[0:4]) == "RIFF" && string(imageBytes[8:12]) == "WEBP" {
		contentType = "image/webp"
	}

	c.Header("Content-Type", contentType)
	c.Header("Cache-Control", "private, max-age=86400")
	c.Data(http.StatusOK, contentType, imageBytes)
}
