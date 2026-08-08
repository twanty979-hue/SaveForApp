package handlers

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

type authenticatedUser struct {
	ID    string `json:"id"`
	Email string `json:"email"`
}

func handleChangePassword(c *gin.Context) {
	var input struct {
		CurrentPassword string `json:"current_password"`
		NewPassword     string `json:"new_password"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Please enter your current and new password"})
		return
	}
	if input.CurrentPassword == "" || len(input.NewPassword) < 8 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "The new password must be at least 8 characters"})
		return
	}
	if input.CurrentPassword == input.NewPassword {
		c.JSON(http.StatusBadRequest, gin.H{"error": "The new password must be different"})
		return
	}

	user, ok := authenticatedUserDetails(c)
	if !ok {
		return
	}
	baseURL := strings.TrimRight(strings.TrimSpace(os.Getenv("SUPABASE_URL")), "/")
	secretKey := strings.TrimSpace(os.Getenv("SUPABASE_SERVICE_KEY"))

	verified, err := verifyPassword(baseURL, secretKey, user.Email, input.CurrentPassword)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to verify the current password"})
		return
	}
	if !verified {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "The current password is incorrect"})
		return
	}

	status, responseBody, err := updatePassword(baseURL, secretKey, user.ID, input.NewPassword)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to change the password"})
		return
	}
	if status < 200 || status >= 300 {
		var upstream map[string]any
		_ = json.Unmarshal(responseBody, &upstream)
		message, _ := upstream["msg"].(string)
		if message == "" {
			message, _ = upstream["message"].(string)
		}
		if message == "" {
			message = "The new password does not meet the security requirements"
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": message})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Password changed"})
}

func authenticatedUserDetails(c *gin.Context) (authenticatedUser, bool) {
	authorization := strings.TrimSpace(c.GetHeader("Authorization"))
	if !strings.HasPrefix(authorization, "Bearer ") {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Please sign in again"})
		return authenticatedUser{}, false
	}
	baseURL := strings.TrimRight(strings.TrimSpace(os.Getenv("SUPABASE_URL")), "/")
	secretKey := strings.TrimSpace(os.Getenv("SUPABASE_SERVICE_KEY"))
	if baseURL == "" || secretKey == "" {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Supabase credentials are not configured"})
		return authenticatedUser{}, false
	}

	req, err := http.NewRequest(http.MethodGet, baseURL+"/auth/v1/user", nil)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Unable to validate user session"})
		return authenticatedUser{}, false
	}
	req.Header.Set("apikey", secretKey)
	req.Header.Set("Authorization", authorization)
	resp, err := (&http.Client{Timeout: 12 * time.Second}).Do(req)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to validate user session"})
		return authenticatedUser{}, false
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Your session has expired. Please sign in again"})
		return authenticatedUser{}, false
	}
	var user authenticatedUser
	if err := json.NewDecoder(resp.Body).Decode(&user); err != nil || user.ID == "" || user.Email == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unable to identify signed-in user"})
		return authenticatedUser{}, false
	}
	return user, true
}

func verifyPassword(baseURL, secretKey, email, password string) (bool, error) {
	body, _ := json.Marshal(gin.H{"email": email, "password": password})
	req, err := http.NewRequest(http.MethodPost, baseURL+"/auth/v1/token?grant_type=password", bytes.NewReader(body))
	if err != nil {
		return false, err
	}
	req.Header.Set("apikey", secretKey)
	req.Header.Set("Content-Type", "application/json")
	resp, err := (&http.Client{Timeout: 12 * time.Second}).Do(req)
	if err != nil {
		return false, err
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, resp.Body)
	return resp.StatusCode >= 200 && resp.StatusCode < 300, nil
}

func updatePassword(baseURL, secretKey, userID, password string) (int, []byte, error) {
	body, _ := json.Marshal(gin.H{"password": password})
	req, err := http.NewRequest(http.MethodPut, baseURL+"/auth/v1/admin/users/"+userID, bytes.NewReader(body))
	if err != nil {
		return 0, nil, err
	}
	req.Header.Set("apikey", secretKey)
	req.Header.Set("Authorization", "Bearer "+secretKey)
	req.Header.Set("Content-Type", "application/json")
	resp, err := (&http.Client{Timeout: 12 * time.Second}).Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer resp.Body.Close()
	responseBody, err := io.ReadAll(resp.Body)
	return resp.StatusCode, responseBody, err
}
