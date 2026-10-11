package handlers

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"

	"github.com/gin-gonic/gin"
)

// RevenueCatWebhookPayload represents the incoming webhook structure from RevenueCat
type RevenueCatWebhookPayload struct {
	APIVersion string              `json:"api_version"`
	Event      RevenueCatEventBody `json:"event"`
}

type RevenueCatEventBody struct {
	ID                    string   `json:"id"`
	Type                  string   `json:"type"`
	AppUserID             string   `json:"app_user_id"`
	OriginalAppUserID     string   `json:"original_app_user_id"`
	ProductID             string   `json:"product_id"`
	EntitlementID         string   `json:"entitlement_id"`
	EntitlementIDs        []string `json:"entitlement_ids"`
	PeriodType            string   `json:"period_type"`
	PurchasedAtMs         int64    `json:"purchased_at_ms"`
	ExpirationAtMs        int64    `json:"expiration_at_ms"`
	Environment           string   `json:"environment"`
	Store                 string   `json:"store"`
	PresentedOfferingID   string   `json:"presented_offering_id"`
	TransactionID         string   `json:"transaction_id"`
	OriginalTransactionID string   `json:"original_transaction_id"`
}

var (
	revenueCatGrantEvents = map[string]bool{
		"INITIAL_PURCHASE":      true,
		"RENEWAL":               true,
		"PRODUCT_CHANGE":        true,
		"UNCANCELLATION":        true,
		"SUBSCRIPTION_EXTENDED": true,
		"NON_RENEWING_PURCHASE": true,
	}

	revenueCatRevokeEvents = map[string]bool{
		"EXPIRATION": true,
		"REVOCATION": true,
	}
)

// HandleRevenueCatWebhook processes subscription lifecycle events from RevenueCat
func HandleRevenueCatWebhook(c *gin.Context) {
	// 1. Verify Webhook Secret if configured
	expectedSecret := strings.TrimSpace(os.Getenv("REVENUECAT_WEBHOOK_SECRET"))
	if expectedSecret != "" {
		authHeader := strings.TrimSpace(c.GetHeader("Authorization"))
		authSecret := strings.TrimPrefix(authHeader, "Bearer ")
		authSecret = strings.TrimSpace(authSecret)
		if authSecret != expectedSecret && authHeader != expectedSecret {
			log.Printf("[RevenueCat Webhook] Unauthorized request received")
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized webhook signature/token"})
			return
		}
	}

	bodyBytes, err := io.ReadAll(c.Request.Body)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Failed to read request body"})
		return
	}

	var payload RevenueCatWebhookPayload
	if err := json.Unmarshal(bodyBytes, &payload); err != nil {
		var directEvent RevenueCatEventBody
		if errDirect := json.Unmarshal(bodyBytes, &directEvent); errDirect == nil && directEvent.Type != "" {
			payload.Event = directEvent
		} else {
			log.Printf("[RevenueCat Webhook] Invalid JSON payload: %v", err)
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid JSON format"})
			return
		}
	}

	event := payload.Event
	eventType := strings.ToUpper(strings.TrimSpace(event.Type))

	// 2. Handle Synthetic / Ping / Test events
	if eventType == "TEST" || eventType == "PING" {
		log.Printf("[RevenueCat Webhook] Test/Ping event verified successfully")
		c.JSON(http.StatusOK, gin.H{"received": true, "test": true})
		return
	}

	appUserID := strings.TrimSpace(event.AppUserID)
	if appUserID == "" {
		appUserID = strings.TrimSpace(event.OriginalAppUserID)
	}

	if appUserID == "" {
		log.Printf("[RevenueCat Webhook] Ignored %s event because app_user_id is empty", eventType)
		c.JSON(http.StatusOK, gin.H{"received": true, "ignored": "missing_app_user_id"})
		return
	}

	log.Printf("[RevenueCat Webhook] Processing event %s for user %s (product=%s, store=%s)",
		eventType, appUserID, event.ProductID, event.Store)

	// 3. Determine tier action
	var targetTier string
	if revenueCatGrantEvents[eventType] {
		targetTier = "pro"
	} else if revenueCatRevokeEvents[eventType] {
		targetTier = "free"
	} else {
		// Non-blocking events (e.g. CANCELLATION, BILLING_ISSUE, SUBSCRIPTION_PAUSED)
		// For CANCELLATION, user remains PRO until EXPIRATION date is reached
		log.Printf("[RevenueCat Webhook] Non-blocking event %s for user %s", eventType, appUserID)
		c.JSON(http.StatusOK, gin.H{"received": true, "ignored": eventType})
		return
	}

	// 4. Update Supabase Database
	err = updateProfileSubscriptionTier(appUserID, targetTier)
	if err != nil {
		log.Printf("[RevenueCat Webhook] Failed to update user %s tier to %s: %v", appUserID, targetTier, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to update database: %v", err)})
		return
	}

	log.Printf("[RevenueCat Webhook] Successfully updated user %s tier to %s", appUserID, targetTier)
	c.JSON(http.StatusOK, gin.H{
		"received":    true,
		"app_user_id": appUserID,
		"tier":        targetTier,
		"event_type":  eventType,
	})
}

func updateProfileSubscriptionTier(userID, tier string) error {
	path := "/rest/v1/profiles?id=eq." + url.QueryEscape(userID)
	payload := map[string]any{
		"tier": tier,
	}

	status, respBody, err := doSupabaseJSON("PATCH", path, payload, "return=representation")
	if err != nil {
		return err
	}

	if status < 200 || status >= 300 {
		return fmt.Errorf("Supabase returned status %d: %s", status, string(respBody))
	}

	return nil
}
