package handlers

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	pathpkg "path"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
)

func SetupRouter() *gin.Engine {
	r := gin.Default()
	allowedOrigin := strings.TrimSpace(os.Getenv("CORS_ALLOWED_ORIGIN"))
	if allowedOrigin == "" {
		allowedOrigin = "*"
	}

	// CORS Middleware เพื่ออนุญาตการเชื่อมต่อจากโทรศัพท์มือถือจริงในวงแลนเดียวกัน
	r.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", allowedOrigin)
		c.Writer.Header().Set("Access-Control-Allow-Credentials", strconv.FormatBool(allowedOrigin != "*"))
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With, apikey")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, PATCH, DELETE")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	})

	// ตรวจสอบสถานะการเชื่อมต่อ API
	// All non-auth API routes require a valid Supabase user session. The data
	// proxy uses the server service key, so this is the authorization boundary
	// for every request that reaches user data.
	r.Use(func(c *gin.Context) {
		path := c.Request.URL.Path
		if path == "/ping" || !strings.HasPrefix(path, "/api/v1/") || strings.HasPrefix(path, "/api/v1/auth/") || strings.HasPrefix(path, "/api/v1/bank-logos/") {
			c.Next()
			return
		}
		if _, ok := authenticatedUserDetails(c); !ok {
			c.Abort()
			return
		}
		c.Next()
	})

	r.GET("/ping", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "pong from savefor api!",
		})
	})

	// Flutter Web is served by the same Render service as the API. Only API
	// routes use the authentication middleware above; public web pages do not.
	r.NoRoute(serveFlutterWeb)

	v1 := r.Group("/api/v1")
	{
		// Proxy การยืนยันตัวตนไปยัง Supabase Auth
		v1.POST("/auth/register", func(c *gin.Context) {
			handleSupabaseProxy(c, "POST", "/auth/v1/signup")
		})
		v1.POST("/auth/login", func(c *gin.Context) {
			handleSupabaseProxy(c, "POST", "/auth/v1/token?grant_type=password")
		})
		v1.POST("/auth/google/android", func(c *gin.Context) {
			handleSupabaseProxy(c, "POST", "/auth/v1/token?grant_type=id_token")
		})
		v1.POST("/auth/apple", func(c *gin.Context) {
			handleSupabaseProxy(c, "POST", "/auth/v1/token?grant_type=id_token")
		})
		v1.POST("/auth/id-token", func(c *gin.Context) {
			handleSupabaseProxy(c, "POST", "/auth/v1/token?grant_type=id_token")
		})
		v1.POST("/auth/refresh", func(c *gin.Context) {
			handleSupabaseProxy(c, "POST", "/auth/v1/token?grant_type=refresh_token")
		})
		v1.POST("/auth/change-password", handleChangePassword)

		// New routes for Google OAuth and passwordless OTP
		v1.GET("/auth/google/url", func(c *gin.Context) {
			supabaseURL := os.Getenv("SUPABASE_URL")
			if supabaseURL == "" {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Supabase URL is not configured"})
				return
			}
			redirectTo := c.Query("redirect_to")
			if redirectTo == "" {
				redirectTo = "http://localhost:8080"
			}
			authURL := supabaseURL + "/auth/v1/authorize?provider=google&redirect_to=" + redirectTo
			c.JSON(http.StatusOK, gin.H{"url": authURL})
		})

		v1.POST("/auth/otp", func(c *gin.Context) {
			handleSupabaseProxy(c, "POST", "/auth/v1/otp")
		})

		v1.GET("/auth/user", func(c *gin.Context) {
			supabaseURL := os.Getenv("SUPABASE_URL")
			supabaseKey := os.Getenv("SUPABASE_SERVICE_KEY")
			if supabaseURL == "" || supabaseKey == "" {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Supabase credentials are not configured"})
				return
			}
			authorization := c.GetHeader("Authorization")
			if authorization == "" {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "No token provided"})
				return
			}
			req, err := http.NewRequest("GET", supabaseURL+"/auth/v1/user", nil)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create request: " + err.Error()})
				return
			}
			req.Header.Set("apikey", supabaseKey)
			req.Header.Set("Authorization", authorization)

			resp, err := (&http.Client{}).Do(req)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to connect to Supabase: " + err.Error()})
				return
			}
			defer resp.Body.Close()

			respBytes, err := io.ReadAll(resp.Body)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read response: " + err.Error()})
				return
			}
			c.Data(resp.StatusCode, resp.Header.Get("Content-Type"), respBytes)
		})

		// Proxy ข้อมูลโปรไฟล์ผู้ใช้
		v1.GET("/profile", func(c *gin.Context) {
			handleSupabaseProxy(c, "GET", "/rest/v1/profiles")
		})
		v1.POST("/profile", func(c *gin.Context) {
			handleSupabaseProxy(c, "POST", "/rest/v1/profiles")
		})
		v1.PATCH("/profile", func(c *gin.Context) {
			handleSupabaseProxy(c, "PATCH", "/rest/v1/profiles")
		})
		v1.GET("/profile/avatar", handleGetProfileAvatar)
		v1.GET("/profile/avatar/file", handleProfileAvatarFile)
		v1.POST("/profile/avatar", handleUploadProfileAvatar)
		v1.DELETE("/profile/avatar", handleDeleteProfileAvatar)
		v1.POST("/notifications/device-token", handleNotificationDeviceToken)
		v1.GET("/notifications", handleListNotifications)
		v1.GET("/notifications/unread-count", handleUnreadNotificationCount)
		v1.PATCH("/notifications/:id/read", handleReadNotification)
		v1.GET("/support/channels", handleListSupportChannels)
		v1.GET("/support/tickets", handleListSupportTickets)
		v1.POST("/support/tickets", handleCreateSupportTicket)
		v1.GET("/feature-requests", handleListFeatureRequests)
		v1.POST("/feature-requests", handleCreateFeatureRequest)

		// อัปโหลดและดาวน์โหลดรูปสลิปผ่าน Cloudflare R2 (แยกตาม User ID)
		v1.POST("/transactions/slip/upload", handleUploadSlipImage)
		v1.GET("/transactions/slip/file", handleGetSlipImageFile)

		// Proxy การจัดเก็บข้อมูลธุรกรรมไปยังฐานข้อมูล Supabase PostgreSQL
		v1.GET("/transactions", func(c *gin.Context) {
			handleSupabaseProxy(c, "GET", "/rest/v1/transactions")
		})
		v1.POST("/transactions", func(c *gin.Context) {
			handleSupabaseProxy(c, "POST", "/rest/v1/transactions")
		})
		v1.PATCH("/transactions", func(c *gin.Context) {
			handleSupabaseProxy(c, "PATCH", "/rest/v1/transactions")
		})
		v1.PUT("/transactions", func(c *gin.Context) {
			handleSupabaseProxy(c, "PUT", "/rest/v1/transactions")
		})
		v1.DELETE("/transactions", func(c *gin.Context) {
			handleSupabaseProxy(c, "DELETE", "/rest/v1/transactions")
		})

		// Proxy ระบบเป้าหมายความฝัน (Dreams)
		v1.GET("/dreams", func(c *gin.Context) {
			handleSupabaseProxy(c, "GET", "/rest/v1/dreams")
		})
		v1.POST("/dreams", func(c *gin.Context) {
			handleSupabaseProxy(c, "POST", "/rest/v1/dreams")
		})
		v1.PATCH("/dreams", func(c *gin.Context) {
			handleSupabaseProxy(c, "PATCH", "/rest/v1/dreams")
		})
		v1.DELETE("/dreams", func(c *gin.Context) {
			handleSupabaseProxy(c, "DELETE", "/rest/v1/dreams")
		})

		// Proxy แผนค่าใช้จ่ายประจำและรายรับประจำ
		v1.GET("/recurring/expenses", func(c *gin.Context) {
			handleSupabaseProxy(c, "GET", "/rest/v1/fixed_expenses")
		})
		v1.POST("/recurring/expenses", func(c *gin.Context) {
			handleSupabaseProxy(c, "POST", "/rest/v1/fixed_expenses")
		})
		v1.DELETE("/recurring/expenses", func(c *gin.Context) {
			handleSupabaseProxy(c, "DELETE", "/rest/v1/fixed_expenses")
		})
		v1.PATCH("/recurring/expenses", func(c *gin.Context) {
			handleSupabaseProxy(c, "PATCH", "/rest/v1/fixed_expenses")
		})
		v1.GET("/recurring/sources", func(c *gin.Context) {
			handleSupabaseProxy(c, "GET", "/rest/v1/income_sources")
		})
		v1.POST("/recurring/sources", func(c *gin.Context) {
			handleSupabaseProxy(c, "POST", "/rest/v1/income_sources")
		})
		v1.DELETE("/recurring/sources", func(c *gin.Context) {
			handleSupabaseProxy(c, "DELETE", "/rest/v1/income_sources")
		})
		v1.PATCH("/recurring/sources", func(c *gin.Context) {
			handleSupabaseProxy(c, "PATCH", "/rest/v1/income_sources")
		})

		// Dynamic bank album detection rules & Cloudflare R2 logos
		v1.GET("/bank-rules", HandleGetBankRules)
		v1.POST("/bank-rules", HandleSaveBankRules)
		v1.GET("/bank-logos/:name", HandleGetBankLogo)
	}

	return r
}

func serveFlutterWeb(c *gin.Context) {
	requestPath := strings.TrimPrefix(c.Request.URL.Path, "/")
	if strings.HasPrefix(requestPath, "api/") {
		c.JSON(http.StatusNotFound, gin.H{"error": "API route not found"})
		return
	}

	cleanPath := pathpkg.Clean("/" + requestPath)
	relativePath := strings.TrimPrefix(cleanPath, "/")
	if relativePath == "" || strings.HasPrefix(relativePath, "..") {
		relativePath = "index.html"
	}

	filePath := filepath.Join("web", filepath.FromSlash(relativePath))
	if info, err := os.Stat(filePath); err == nil && !info.IsDir() {
		c.File(filePath)
		return
	}

	indexPath := filepath.Join("web", "index.html")
	if _, err := os.Stat(indexPath); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "web client is not deployed"})
		return
	}
	c.File(indexPath)
}

func handleSupabaseProxy(c *gin.Context, method string, path string) {
	supabaseURL := os.Getenv("SUPABASE_URL")
	supabaseKey := os.Getenv("SUPABASE_SERVICE_KEY")

	if supabaseURL == "" || supabaseKey == "" {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Supabase credentials are not configured in backend .env"})
		return
	}

	isDataProxy := strings.HasPrefix(path, "/rest/v1/")
	userID := ""
	if isDataProxy {
		userID = c.GetString(authenticatedUserIDContextKey)
		if userID == "" {
			if user, ok := authenticatedUserDetails(c); ok {
				userID = user.ID
			}
		}
		if userID == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Please sign in again"})
			return
		}
	}

	bodyBytes := []byte(nil)
	if c.Request.Body != nil {
		bodyBytes, _ = io.ReadAll(c.Request.Body)
	}
	if isDataProxy {
		var scopeErr error
		bodyBytes, scopeErr = enforceUserScope(c, method, path, bodyBytes, userID)
		if scopeErr != nil {
			status := http.StatusForbidden
			if strings.Contains(scopeErr.Error(), "invalid JSON") {
				status = http.StatusBadRequest
			}
			c.JSON(status, gin.H{"error": scopeErr.Error()})
			return
		}
	}

	query := c.Request.URL.Query()
	if isDataProxy {
		if path == "/rest/v1/profiles" {
			query.Set("id", "eq."+userID)
		} else {
			query.Set("user_id", "eq."+userID)
		}
	}
	targetURL := supabaseURL + path
	if !isDataProxy && c.Request.URL.RawQuery != "" {
		if strings.Contains(targetURL, "?") {
			targetURL += "&" + c.Request.URL.RawQuery
		} else {
			targetURL += "?" + c.Request.URL.RawQuery
		}
	} else if encodedQuery := query.Encode(); encodedQuery != "" {
		targetURL += "?" + encodedQuery
	}

	var bodyReader io.Reader
	if len(bodyBytes) > 0 {
		bodyReader = bytes.NewReader(bodyBytes)
	}

	req, err := http.NewRequest(method, targetURL, bodyReader)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create proxy request: " + err.Error()})
		return
	}

	// เพิ่ม Headers สำหรับเรียกใช้งานบริการของ Supabase REST
	req.Header.Set("apikey", supabaseKey)
	req.Header.Set("Authorization", "Bearer "+supabaseKey)
	req.Header.Set("Content-Type", "application/json")

	// สั่งให้คืนค่า JSON ก้อนที่บันทึกกลับมาเมื่อทำรายการแบบ POST
	if method == "POST" {
		req.Header.Set("Prefer", "return=representation")
	}

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to connect to Supabase backend: " + err.Error()})
		return
	}
	defer resp.Body.Close()

	respBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read Supabase backend response: " + err.Error()})
		return
	}

	c.Data(resp.StatusCode, resp.Header.Get("Content-Type"), respBytes)
}

// enforceUserScope prevents a client from changing the owner field or using
// a different owner filter while the API is proxying with its service key.
func enforceUserScope(c *gin.Context, method, path string, body []byte, userID string) ([]byte, error) {
	ownerField := "user_id"
	if path == "/rest/v1/profiles" {
		ownerField = "id"
	}

	expectedFilter := "eq." + userID
	if current := c.Request.URL.Query().Get(ownerField); current != "" && current != expectedFilter {
		return nil, fmt.Errorf("the request is not allowed for this user")
	}

	if method != http.MethodPost && method != http.MethodPatch && method != http.MethodPut {
		return body, nil
	}
	if len(body) == 0 {
		return body, nil
	}

	var payload map[string]any
	if err := json.Unmarshal(body, &payload); err != nil {
		return nil, fmt.Errorf("invalid JSON request")
	}
	if current, exists := payload[ownerField]; exists && fmt.Sprint(current) != userID {
		return nil, fmt.Errorf("the request is not allowed for this user")
	}
	payload[ownerField] = userID
	return json.Marshal(payload)
}
