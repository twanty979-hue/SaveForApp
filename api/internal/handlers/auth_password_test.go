package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestChangePasswordVerifiesCurrentPasswordBeforeAdminUpdate(t *testing.T) {
	gin.SetMode(gin.TestMode)
	adminUpdated := false
	supabase := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.URL.Path == "/auth/v1/user":
			if r.Header.Get("Authorization") != "Bearer user-access-token" {
				t.Fatalf("unexpected user authorization header")
			}
			_ = json.NewEncoder(w).Encode(map[string]string{"id": "user-1", "email": "user@example.com"})
		case r.URL.Path == "/auth/v1/token":
			var input map[string]string
			_ = json.NewDecoder(r.Body).Decode(&input)
			if input["password"] != "current-password" {
				w.WriteHeader(http.StatusBadRequest)
				return
			}
			_ = json.NewEncoder(w).Encode(map[string]string{"access_token": "verified"})
		case r.URL.Path == "/auth/v1/admin/users/user-1":
			if r.Method != http.MethodPut || r.Header.Get("Authorization") != "Bearer server-secret" {
				t.Fatalf("admin update did not use the server credential")
			}
			var input map[string]string
			_ = json.NewDecoder(r.Body).Decode(&input)
			if input["password"] != "new-password" {
				t.Fatalf("unexpected new password")
			}
			adminUpdated = true
			_ = json.NewEncoder(w).Encode(map[string]string{"id": "user-1"})
		default:
			http.NotFound(w, r)
		}
	}))
	defer supabase.Close()

	t.Setenv("SUPABASE_URL", supabase.URL)
	t.Setenv("SUPABASE_SERVICE_KEY", "server-secret")
	recorder := httptest.NewRecorder()
	context, _ := gin.CreateTestContext(recorder)
	context.Request = httptest.NewRequest(
		http.MethodPost,
		"/api/v1/auth/change-password",
		strings.NewReader(`{"current_password":"current-password","new_password":"new-password"}`),
	)
	context.Request.Header.Set("Authorization", "Bearer user-access-token")
	context.Request.Header.Set("Content-Type", "application/json")

	handleChangePassword(context)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", recorder.Code, recorder.Body.String())
	}
	if !adminUpdated {
		t.Fatal("expected the password to be updated after verification")
	}
}
