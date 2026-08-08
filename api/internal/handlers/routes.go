package handlers

import (
	"bytes"
	"io"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
)

func SetupRouter() *gin.Engine {
	r := gin.Default()

	// CORS Middleware เพื่ออนุญาตการเชื่อมต่อจากโทรศัพท์มือถือจริงในวงแลนเดียวกัน
	r.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With, apikey")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, PATCH, DELETE")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	})

	// ตรวจสอบสถานะการเชื่อมต่อ API
	r.GET("/ping", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "pong from savefor api!",
		})
	})

	v1 := r.Group("/api/v1")
	{
		// Proxy การยืนยันตัวตนไปยัง Supabase Auth
		v1.POST("/auth/register", func(c *gin.Context) {
			handleSupabaseProxy(c, "POST", "/auth/v1/signup")
		})
		v1.POST("/auth/login", func(c *gin.Context) {
			handleSupabaseProxy(c, "POST", "/auth/v1/token?grant_type=password")
		})
		v1.POST("/auth/refresh", func(c *gin.Context) {
			handleSupabaseProxy(c, "POST", "/auth/v1/token?grant_type=refresh_token")
		})
		v1.POST("/auth/change-password", handleChangePassword)

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

		// Proxy การจัดเก็บข้อมูลธุรกรรมไปยังฐานข้อมูล Supabase PostgreSQL
		v1.GET("/transactions", func(c *gin.Context) {
			handleSupabaseProxy(c, "GET", "/rest/v1/transactions")
		})
		v1.POST("/transactions", func(c *gin.Context) {
			handleSupabaseProxy(c, "POST", "/rest/v1/transactions")
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
	}

	return r
}

func handleSupabaseProxy(c *gin.Context, method string, path string) {
	supabaseURL := os.Getenv("SUPABASE_URL")
	supabaseKey := os.Getenv("SUPABASE_SERVICE_KEY")

	if supabaseURL == "" || supabaseKey == "" {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Supabase credentials are not configured in backend .env"})
		return
	}

	targetURL := supabaseURL + path
	if c.Request.URL.RawQuery != "" {
		targetURL += "?" + c.Request.URL.RawQuery
	}

	var bodyReader io.Reader
	if c.Request.Body != nil {
		bodyBytes, _ := io.ReadAll(c.Request.Body)
		bodyReader = bytes.NewBuffer(bodyBytes)
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
