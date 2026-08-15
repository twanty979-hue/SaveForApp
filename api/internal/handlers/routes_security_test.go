package handlers

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

func newTestContext(req *http.Request) (*gin.Context, *httptest.ResponseRecorder) {
	gin.SetMode(gin.TestMode)
	recorder := httptest.NewRecorder()
	ctx, _ := gin.CreateTestContext(recorder)
	ctx.Request = req
	return ctx, recorder
}

func TestEnforceUserScopeRejectsDifferentQueryOwner(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/api/v1/transactions?user_id=eq.other-user", nil)
	ctx, _ := newTestContext(req)

	_, err := enforceUserScope(ctx, http.MethodGet, "/rest/v1/transactions", nil, "current-user")
	if err == nil {
		t.Fatal("expected a request for another user to be rejected")
	}
}

func TestEnforceUserScopeRejectsDifferentBodyOwner(t *testing.T) {
	req := httptest.NewRequest(http.MethodPost, "/api/v1/transactions", strings.NewReader(`{"user_id":"other-user","amount":10}`))
	ctx, _ := newTestContext(req)

	_, err := enforceUserScope(ctx, http.MethodPost, "/rest/v1/transactions", []byte(`{"user_id":"other-user","amount":10}`), "current-user")
	if err == nil {
		t.Fatal("expected a request with another body owner to be rejected")
	}
}

func TestEnforceUserScopeSetsOwnerForValidBody(t *testing.T) {
	req := httptest.NewRequest(http.MethodPost, "/api/v1/transactions", strings.NewReader(`{"amount":10}`))
	ctx, _ := newTestContext(req)

	body, err := enforceUserScope(ctx, http.MethodPost, "/rest/v1/transactions", []byte(`{"amount":10}`), "current-user")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !strings.Contains(string(body), `"user_id":"current-user"`) {
		t.Fatalf("expected owner to be assigned from the authenticated user: %s", body)
	}
}
