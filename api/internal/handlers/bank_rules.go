package handlers

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

// BankAlbumRulePayload represents a bank configuration with customizable album keywords and logo URL.
type BankAlbumRulePayload struct {
	ID            string   `json:"id"`
	Name          string   `json:"name"`
	AppName       string   `json:"appName"`
	BankType      string   `json:"bankType"`
	LogoURL       string   `json:"logoUrl,omitempty"`
	AlbumKeywords []string `json:"albumKeywords"`
	IsEnabled     bool     `json:"isEnabled"`
	IsCustom      bool     `json:"isCustom"`
	ColorHex      string   `json:"colorHex,omitempty"`
	Priority      int      `json:"priority,omitempty"`
	UpdatedAt     string   `json:"updatedAt,omitempty"`
}

// In-memory fallback cache per user in case the Supabase table has not been migrated yet.
var (
	userRulesCache = make(map[string][]BankAlbumRulePayload)
	userRulesMu    sync.RWMutex
)

// DefaultBankRules provides the out-of-the-box bank album configuration.
func DefaultBankRules() []BankAlbumRulePayload {
	return []BankAlbumRulePayload{
		{
			ID:            "kbank",
			Name:          "กสิกรไทย",
			AppName:       "K PLUS • Kasikornbank",
			BankType:      "kbank",
			LogoURL:       "/images/banks/kbank.png",
			AlbumKeywords: []string{"k plus", "kplus", "k-plus", "kasikorn", "กสิกร"},
			IsEnabled:     true,
			IsCustom:      false,
			ColorHex:      "#00A950",
			Priority:      1,
		},
		{
			ID:            "scb",
			Name:          "ไทยพาณิชย์",
			AppName:       "SCB EASY • แม่มณี",
			BankType:      "scb",
			LogoURL:       "/images/banks/scb.png",
			AlbumKeywords: []string{"scb easy", "scbeasy", "scb", "แม่มณี", "ไทยพาณิชย์"},
			IsEnabled:     true,
			IsCustom:      false,
			ColorHex:      "#4E2A84",
			Priority:      2,
		},
		{
			ID:            "krungsri",
			Name:          "กรุงศรีอยุธยา",
			AppName:       "KMA • Bank of Ayudhya",
			BankType:      "krungsri",
			LogoURL:       "/images/banks/krungsri.png",
			AlbumKeywords: []string{"krungsri", "kma", "bay", "กรุงศรี"},
			IsEnabled:     true,
			IsCustom:      false,
			ColorHex:      "#7A6400",
			Priority:      3,
		},
		{
			ID:            "truemoney",
			Name:          "ทรูมันนี่",
			AppName:       "TrueMoney Wallet",
			BankType:      "truemoney",
			LogoURL:       "/images/banks/truemoney.png",
			AlbumKeywords: []string{"truemoney", "true money", "ทรูมันนี่", "tmn"},
			IsEnabled:     true,
			IsCustom:      false,
			ColorHex:      "#FF6600",
			Priority:      4,
		},
	}
}

// HandleGetBankLogo serves bank logos stored in Cloudflare R2 bucket savfor/bank-logos/.
func HandleGetBankLogo(c *gin.Context) {
	name := strings.TrimSpace(c.Param("name"))
	if name == "" {
		c.Status(http.StatusBadRequest)
		return
	}
	if !strings.HasSuffix(name, ".png") && !strings.HasSuffix(name, ".webp") && !strings.HasSuffix(name, ".jpg") {
		name += ".png"
	}
	// Sanitize path traversal
	name = strings.ReplaceAll(name, "/", "")
	name = strings.ReplaceAll(name, "..", "")

	cfg, err := loadR2Config()
	if err == nil {
		objectKey := "bank-logos/" + name
		status, imageBytes, err := doR2Request(cfg, http.MethodGet, objectKey, "", nil)
		if err == nil && status == http.StatusOK && len(imageBytes) > 0 {
			c.Header("Cache-Control", "public, max-age=86400")
			c.Data(http.StatusOK, "image/png", imageBytes)
			return
		}
	}

	c.Status(http.StatusNotFound)
}

// HandleGetBankRules handles GET /api/v1/bank-rules.
func HandleGetBankRules(c *gin.Context) {
	user, _ := authenticatedUserDetails(c)
	userID := user.ID

	// 1. Check in-memory store for this user
	if userID != "" {
		userRulesMu.RLock()
		if rules, exists := userRulesCache[userID]; exists && len(rules) > 0 {
			userRulesMu.RUnlock()
			c.JSON(http.StatusOK, gin.H{
				"rules": rules,
				"count": len(rules),
			})
			return
		}
		userRulesMu.RUnlock()
	}

	// 2. Try fetching from Supabase if configured
	supabaseURL := strings.TrimRight(strings.TrimSpace(os.Getenv("SUPABASE_URL")), "/")
	supabaseKey := strings.TrimSpace(os.Getenv("SUPABASE_SERVICE_KEY"))
	if supabaseURL != "" && supabaseKey != "" && userID != "" {
		targetURL := supabaseURL + "/rest/v1/bank_album_rules?user_id=eq." + userID + "&order=created_at.asc"
		req, err := http.NewRequest(http.MethodGet, targetURL, nil)
		if err == nil {
			req.Header.Set("apikey", supabaseKey)
			req.Header.Set("Authorization", "Bearer "+supabaseKey)
			client := &http.Client{Timeout: 5 * time.Second}
			resp, err := client.Do(req)
			if err == nil {
				defer resp.Body.Close()
				if resp.StatusCode == http.StatusOK {
					var rawRules []BankAlbumRulePayload
					if err := json.NewDecoder(resp.Body).Decode(&rawRules); err == nil && len(rawRules) > 0 {
						userRulesMu.Lock()
						userRulesCache[userID] = rawRules
						userRulesMu.Unlock()
						c.JSON(http.StatusOK, gin.H{
							"rules": rawRules,
							"count": len(rawRules),
						})
						return
					}
				}
			}
		}
	}

	// 3. Fallback to defaults
	defaults := DefaultBankRules()
	c.JSON(http.StatusOK, gin.H{
		"rules": defaults,
		"count": len(defaults),
	})
}

// HandleSaveBankRules handles POST /api/v1/bank-rules.
func HandleSaveBankRules(c *gin.Context) {
	user, _ := authenticatedUserDetails(c)
	userID := user.ID

	bodyBytes, err := io.ReadAll(c.Request.Body)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	// Support either a raw array or {"rules": [...]}
	var rules []BankAlbumRulePayload
	if err := json.Unmarshal(bodyBytes, &rules); err != nil {
		var wrapper struct {
			Rules []BankAlbumRulePayload `json:"rules"`
		}
		if err2 := json.Unmarshal(bodyBytes, &wrapper); err2 != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Payload must be a list of bank rules or an object with 'rules'"})
			return
		}
		rules = wrapper.Rules
	}

	// Sanitize and ensure each rule has keywords
	for i := range rules {
		cleanedKeywords := make([]string, 0, len(rules[i].AlbumKeywords))
		for _, kw := range rules[i].AlbumKeywords {
			trimmed := strings.TrimSpace(kw)
			if trimmed != "" {
				cleanedKeywords = append(cleanedKeywords, trimmed)
			}
		}
		rules[i].AlbumKeywords = cleanedKeywords
	}

	// Save to in-memory user cache
	if userID != "" {
		userRulesMu.Lock()
		userRulesCache[userID] = rules
		userRulesMu.Unlock()
	}

	// Attempt saving to Supabase if configured (async background or non-blocking)
	supabaseURL := strings.TrimRight(strings.TrimSpace(os.Getenv("SUPABASE_URL")), "/")
	supabaseKey := strings.TrimSpace(os.Getenv("SUPABASE_SERVICE_KEY"))
	if supabaseURL != "" && supabaseKey != "" && userID != "" {
		go func(uID string, toSave []BankAlbumRulePayload) {
			// Try upserting to rest/v1/bank_album_rules
			type supabaseRuleRow struct {
				UserID        string   `json:"user_id"`
				BankID        string   `json:"bank_id"`
				Name          string   `json:"name"`
				AppName       string   `json:"app_name"`
				BankType      string   `json:"bank_type"`
				AlbumKeywords []string `json:"album_keywords"`
				IsEnabled     bool     `json:"is_enabled"`
				IsCustom      bool     `json:"is_custom"`
				ColorHex      string   `json:"color_hex"`
			}
			var rows []supabaseRuleRow
			for _, r := range toSave {
				rows = append(rows, supabaseRuleRow{
					UserID:        uID,
					BankID:        r.ID,
					Name:          r.Name,
					AppName:       r.AppName,
					BankType:      r.BankType,
					AlbumKeywords: r.AlbumKeywords,
					IsEnabled:     r.IsEnabled,
					IsCustom:      r.IsCustom,
					ColorHex:      r.ColorHex,
				})
			}
			payloadBytes, _ := json.Marshal(rows)
			targetURL := supabaseURL + "/rest/v1/bank_album_rules"
			req, err := http.NewRequest(http.MethodPost, targetURL, bytes.NewReader(payloadBytes))
			if err == nil {
				req.Header.Set("apikey", supabaseKey)
				req.Header.Set("Authorization", "Bearer "+supabaseKey)
				req.Header.Set("Content-Type", "application/json")
				req.Header.Set("Prefer", "resolution=merge-duplicates")
				client := &http.Client{Timeout: 5 * time.Second}
				_, _ = client.Do(req)
			}
		}(userID, rules)
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Bank rules updated successfully",
		"rules":   rules,
		"count":   len(rules),
	})
}
