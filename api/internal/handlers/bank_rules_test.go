package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestBankRulesAPI(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	v1 := r.Group("/api/v1")
	{
		v1.GET("/bank-rules", HandleGetBankRules)
		v1.POST("/bank-rules", HandleSaveBankRules)
	}

	// 1. Test GET /bank-rules returns defaults
	reqGet, _ := http.NewRequest(http.MethodGet, "/api/v1/bank-rules", nil)
	wGet := httptest.NewRecorder()
	r.ServeHTTP(wGet, reqGet)

	if wGet.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", wGet.Code)
	}

	var respGet struct {
		Rules []BankAlbumRulePayload `json:"rules"`
		Count int                    `json:"count"`
	}
	if err := json.Unmarshal(wGet.Body.Bytes(), &respGet); err != nil {
		t.Fatalf("failed to parse GET response: %v", err)
	}
	if respGet.Count < 4 {
		t.Fatalf("expected at least 4 default rules, got %d", respGet.Count)
	}

	// Verify KBank has multiple keywords
	kbank := respGet.Rules[0]
	if kbank.ID != "kbank" || len(kbank.AlbumKeywords) < 2 {
		t.Fatalf("expected kbank with >=2 keywords, got: %+v", kbank)
	}

	// 2. Test POST /bank-rules with custom album keywords (multiple album names per bank)
	customRules := []BankAlbumRulePayload{
		{
			ID:            "kbank",
			Name:          "กสิกรไทย",
			AppName:       "K PLUS",
			BankType:      "kbank",
			AlbumKeywords: []string{"k plus", "กสิกร", "สลิปที่ทำงาน", "Work_Slips"},
			IsEnabled:     true,
			IsCustom:      false,
			ColorHex:      "#00A950",
		},
		{
			ID:            "custom_ktb",
			Name:          "กรุงไทย",
			AppName:       "Krungthai NEXT",
			BankType:      "ktb",
			AlbumKeywords: []string{"krungthai", "ktb", "สลิปกรุงไทย"},
			IsEnabled:     true,
			IsCustom:      true,
			ColorHex:      "#00AEEF",
		},
	}

	bodyBytes, _ := json.Marshal(customRules)
	reqPost, _ := http.NewRequest(http.MethodPost, "/api/v1/bank-rules", bytes.NewReader(bodyBytes))
	reqPost.Header.Set("Content-Type", "application/json")
	wPost := httptest.NewRecorder()
	r.ServeHTTP(wPost, reqPost)

	if wPost.Code != http.StatusOK {
		t.Fatalf("expected status 200 on POST, got %d: %s", wPost.Code, wPost.Body.String())
	}

	var respPost struct {
		Rules []BankAlbumRulePayload `json:"rules"`
		Count int                    `json:"count"`
	}
	if err := json.Unmarshal(wPost.Body.Bytes(), &respPost); err != nil {
		t.Fatalf("failed to parse POST response: %v", err)
	}
	if respPost.Count != 2 {
		t.Fatalf("expected 2 rules saved, got %d", respPost.Count)
	}
	if len(respPost.Rules[0].AlbumKeywords) != 4 {
		t.Fatalf("expected 4 keywords for kbank, got %d", len(respPost.Rules[0].AlbumKeywords))
	}
}
