package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"github.com/gin-gonic/gin"
	"google.golang.org/api/option"
)

const notificationChannelID = "savefor_reminders_v2"

type notificationDelivery struct {
	ID              string         `json:"id,omitempty"`
	UserID          string         `json:"user_id"`
	NotificationKey string         `json:"notification_key"`
	Type            string         `json:"type"`
	Title           string         `json:"title"`
	Body            string         `json:"body"`
	Data            map[string]any `json:"data"`
	SentAt          string         `json:"sent_at,omitempty"`
	ReadAt          any            `json:"read_at,omitempty"`
}

type recurringItem struct {
	ID       string  `json:"id"`
	UserID   string  `json:"user_id"`
	Name     string  `json:"name"`
	Category string  `json:"category"`
	Amount   float64 `json:"amount"`
	DueDay   int     `json:"due_day"`
}

type dreamItem struct {
	ID                  string  `json:"id"`
	UserID              string  `json:"user_id"`
	Title               string  `json:"title"`
	MonthlySavingTarget float64 `json:"monthly_saving_target"`
}

type transactionItem struct {
	UserID          string  `json:"user_id"`
	Type            string  `json:"type"`
	Amount          float64 `json:"amount"`
	Note            string  `json:"note"`
	TransactionDate string  `json:"transaction_date"`
	FixedExpenseID  any     `json:"fixed_expense_id"`
	IncomeSourceID  any     `json:"income_source_id"`
	DreamID         any     `json:"dream_id"`
	Source          string  `json:"source"`
	Bank            string  `json:"bank"`
}

func handleNotificationDeviceToken(c *gin.Context) {
	userID, ok := authenticatedUserID(c)
	if !ok {
		return
	}
	var input struct {
		Token    string `json:"token"`
		Platform string `json:"platform"`
		Enabled  *bool  `json:"enabled"`
	}
	if err := c.ShouldBindJSON(&input); err != nil || strings.TrimSpace(input.Token) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "A valid notification token is required"})
		return
	}
	input.Token = strings.TrimSpace(input.Token)
	if input.Enabled != nil && !*input.Enabled {
		status, _, err := doSupabaseJSON(http.MethodDelete,
			"/rest/v1/fcm_tokens?user_id=eq."+url.QueryEscape(userID)+"&token=eq."+url.QueryEscape(input.Token), nil, "")
		if err != nil || status < 200 || status >= 300 {
			c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to disable notifications"})
			return
		}
		c.Status(http.StatusNoContent)
		return
	}
	if input.Platform == "" {
		input.Platform = "android"
	}
	payload := map[string]any{
		"user_id":    userID,
		"token":      input.Token,
		"platform":   input.Platform,
		"updated_at": time.Now().UTC().Format(time.RFC3339),
	}
	status, body, err := doSupabaseJSON(http.MethodPost,
		"/rest/v1/fcm_tokens?on_conflict=token", payload,
		"resolution=merge-duplicates,return=representation")
	if err != nil || status < 200 || status >= 300 {
		log.Printf("notification token registration failed: status=%d err=%v body=%s", status, err, safeAPIError(body))
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to enable notifications"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"enabled": true})
}

func handleListNotifications(c *gin.Context) {
	userID, ok := authenticatedUserID(c)
	if !ok {
		return
	}
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	if limit < 1 {
		limit = 1
	}
	if limit > 100 {
		limit = 100
	}
	path := fmt.Sprintf("/rest/v1/notification_deliveries?user_id=eq.%s&select=id,type,title,body,data,sent_at,read_at&order=sent_at.desc&limit=%d", url.QueryEscape(userID), limit)
	status, body, err := doSupabaseJSON(http.MethodGet, path, nil, "")
	if err != nil || status < 200 || status >= 300 {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to load notifications"})
		return
	}
	c.Data(http.StatusOK, "application/json", body)
}

func handleUnreadNotificationCount(c *gin.Context) {
	userID, ok := authenticatedUserID(c)
	if !ok {
		return
	}
	path := "/rest/v1/notification_deliveries?user_id=eq." + url.QueryEscape(userID) + "&read_at=is.null&select=id"
	status, body, err := doSupabaseJSON(http.MethodGet, path, nil, "")
	if err != nil || status < 200 || status >= 300 {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to count notifications"})
		return
	}
	var rows []struct {
		ID string `json:"id"`
	}
	if err := json.Unmarshal(body, &rows); err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Invalid notification response"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"count": len(rows)})
}

func handleReadNotification(c *gin.Context) {
	userID, ok := authenticatedUserID(c)
	if !ok {
		return
	}
	id := strings.TrimSpace(c.Param("id"))
	if id == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Notification ID is required"})
		return
	}
	payload := map[string]string{"read_at": time.Now().UTC().Format(time.RFC3339)}
	path := "/rest/v1/notification_deliveries?id=eq." + url.QueryEscape(id) + "&user_id=eq." + url.QueryEscape(userID)
	status, _, err := doSupabaseJSON(http.MethodPatch, path, payload, "return=minimal")
	if err != nil || status < 200 || status >= 300 {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to update notification"})
		return
	}
	c.Status(http.StatusNoContent)
}

func StartNotificationScheduler() {
	client, err := newFirebaseMessagingClient()
	if err != nil {
		log.Printf("FCM scheduler disabled: %v", err)
		return
	}

	go func() {
		runNotificationCycle(client, time.Now())
		ticker := time.NewTicker(15 * time.Minute)
		defer ticker.Stop()
		for now := range ticker.C {
			runNotificationCycle(client, now)
		}
	}()
	log.Println("FCM notification scheduler started (Asia/Bangkok)")
}

func newFirebaseMessagingClient() (*messaging.Client, error) {
	path := strings.TrimSpace(os.Getenv("GOOGLE_APPLICATION_CREDENTIALS"))
	if path == "" || !fileExists(path) {
		candidates := []string{
			filepath.Join("secrets", "firebase-service-account.json"),
			filepath.Join("api", "secrets", "firebase-service-account.json"),
		}
		for _, candidate := range candidates {
			if fileExists(candidate) {
				path = candidate
				break
			}
		}
	}
	if path == "" || !fileExists(path) {
		return nil, fmt.Errorf("Firebase service account file was not found")
	}
	ctx := context.Background()
	app, err := firebase.NewApp(ctx, nil, option.WithCredentialsFile(path))
	if err != nil {
		return nil, fmt.Errorf("initialize Firebase Admin: %w", err)
	}
	client, err := app.Messaging(ctx)
	if err != nil {
		return nil, fmt.Errorf("initialize Firebase Messaging: %w", err)
	}
	return client, nil
}

func fileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func runNotificationCycle(client *messaging.Client, now time.Time) {
	location, err := time.LoadLocation("Asia/Bangkok")
	if err != nil {
		location = time.FixedZone("Asia/Bangkok", 7*60*60)
	}
	localNow := now.In(location)
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()

	if localNow.Hour() >= 9 {
		if err := processDueNotifications(ctx, client, localNow); err != nil {
			log.Printf("due notification cycle failed: %v", err)
		}
	}
	if localNow.Day()%3 == 0 && localNow.Hour() >= 19 {
		if err := processSavingNotifications(ctx, client, localNow); err != nil {
			log.Printf("saving notification cycle failed: %v", err)
		}
	}
}

func processDueNotifications(ctx context.Context, client *messaging.Client, now time.Time) error {
	var expenses []recurringItem
	if err := fetchSupabaseRows("/rest/v1/fixed_expenses?select=id,user_id,name,category,amount,due_day", &expenses); err != nil {
		return err
	}
	var incomes []recurringItem
	if err := fetchSupabaseRows("/rest/v1/income_sources?select=id,user_id,name,category,amount,due_day", &incomes); err != nil {
		return err
	}
	transactions, err := fetchMonthTransactions(now)
	if err != nil {
		return err
	}
	lastDay := time.Date(now.Year(), now.Month()+1, 0, 0, 0, 0, 0, now.Location()).Day()

	for _, item := range expenses {
		dueDay := min(max(item.DueDay, 1), lastDay)
		if dueDay != now.Day() || excludedMonthlyExpense(item) {
			continue
		}
		if matchedRecurringAmount(transactions, item, "expense") >= item.Amount {
			continue
		}
		delivery := notificationDelivery{
			UserID: item.UserID, NotificationKey: fmt.Sprintf("%s:expense:%s:%04d-%02d", item.UserID, item.ID, now.Year(), now.Month()),
			Type: "expense", Title: "ถึงกำหนดรายจ่ายแล้ว", Body: fmt.Sprintf("%s ครบกำหนดชำระแล้วนะ", item.Name),
			Data: map[string]any{"screen": "expense", "item_id": item.ID},
		}
		deliverNotification(ctx, client, delivery)
	}

	for _, item := range incomes {
		dueDay := min(max(item.DueDay, 1), lastDay)
		if dueDay != now.Day() || matchedRecurringAmount(transactions, item, "income") >= item.Amount {
			continue
		}
		delivery := notificationDelivery{
			UserID: item.UserID, NotificationKey: fmt.Sprintf("%s:income:%s:%04d-%02d", item.UserID, item.ID, now.Year(), now.Month()),
			Type: "income", Title: "เช็กรายรับวันนี้", Body: fmt.Sprintf("วันนี้ %s ของคุณเข้าหรือยังนะ?", item.Name),
			Data: map[string]any{"screen": "income", "item_id": item.ID},
		}
		deliverNotification(ctx, client, delivery)
	}
	return nil
}

func processSavingNotifications(ctx context.Context, client *messaging.Client, now time.Time) error {
	var dreams []dreamItem
	if err := fetchSupabaseRows("/rest/v1/dreams?select=id,user_id,title,monthly_saving_target&monthly_saving_target=gt.0", &dreams); err != nil {
		return err
	}
	transactions, err := fetchMonthTransactions(now)
	if err != nil {
		return err
	}
	for _, dream := range dreams {
		saved := savedForDreamThisMonth(transactions, dream)
		shortfall := dream.MonthlySavingTarget - saved
		if shortfall <= 0 {
			continue
		}
		body := fmt.Sprintf("เดือนนี้ยังออมไม่ครบ เหลืออีก %s บาท ถึงจะครบเป้าหมาย %s", formatBaht(shortfall), dream.Title)
		if saved <= 0 {
			body = fmt.Sprintf("เดือนนี้ยังไม่ได้ออมสำหรับ %s เริ่มวันนี้ยังทันนะ เป้าหมาย %s บาท", dream.Title, formatBaht(dream.MonthlySavingTarget))
		}
		delivery := notificationDelivery{
			UserID: dream.UserID, NotificationKey: fmt.Sprintf("%s:saving:%s:%04d-%02d-%02d", dream.UserID, dream.ID, now.Year(), now.Month(), now.Day()),
			Type: "saving", Title: "เป้าหมายเงินออมของคุณ", Body: body,
			Data: map[string]any{"screen": "dream", "item_id": dream.ID, "shortfall": shortfall},
		}
		deliverNotification(ctx, client, delivery)
	}
	return nil
}

func fetchMonthTransactions(now time.Time) ([]transactionItem, error) {
	start := fmt.Sprintf("%04d-%02d-01", now.Year(), now.Month())
	end := time.Date(now.Year(), now.Month()+1, 1, 0, 0, 0, 0, now.Location()).Format("2006-01-02")
	path := "/rest/v1/transactions?select=user_id,type,amount,note,transaction_date,fixed_expense_id,income_source_id&transaction_date=gte." + start + "&transaction_date=lt." + end
	var rows []transactionItem
	err := fetchSupabaseRows(path, &rows)
	return rows, err
}

func matchedRecurringAmount(transactions []transactionItem, item recurringItem, txType string) float64 {
	total := 0.0
	cleanName := normalizeName(item.Name)
	for _, tx := range transactions {
		if tx.UserID != item.UserID || tx.Type != txType {
			continue
		}
		linkedID := valueString(tx.FixedExpenseID)
		prefix := "[รายจ่ายประจำ]"
		if txType == "income" {
			linkedID = valueString(tx.IncomeSourceID)
			prefix = "[รายรับประจำ]"
		}
		cleanNote := normalizeName(strings.ReplaceAll(tx.Note, prefix, ""))
		isMatch := linkedID == item.ID || cleanNote == cleanName ||
			(cleanNote != "" && cleanName != "" && (strings.Contains(cleanNote, cleanName) || strings.Contains(cleanName, cleanNote)))
		if isMatch {
			total += tx.Amount
		}
	}
	return total
}

func savedForDreamThisMonth(transactions []transactionItem, dream dreamItem) float64 {
	needle := normalizeName("[ออม] หยอดกระปุก: " + dream.Title)
	cleanDreamTitle := normalizeName(dream.Title)
	total := 0.0
	for _, tx := range transactions {
		if tx.UserID == dream.UserID && tx.Type == "expense" {
			linkedDreamID := valueString(tx.DreamID)
			cleanNote := normalizeName(tx.Note)
			if (linkedDreamID != "" && linkedDreamID == dream.ID) || cleanNote == needle || cleanNote == cleanDreamTitle {
				total += tx.Amount
			}
		}
	}
	return total
}

func excludedMonthlyExpense(item recurringItem) bool {
	excluded := normalizeName("ค่าใช้จ่ายรายเดือน")
	return normalizeName(item.Name) == excluded || normalizeName(item.Category) == excluded
}

func normalizeName(value string) string {
	return strings.ToLower(strings.Join(strings.Fields(strings.TrimSpace(value)), " "))
}

func valueString(value any) string {
	if value == nil {
		return ""
	}
	return strings.TrimSpace(fmt.Sprint(value))
}

func formatBaht(value float64) string {
	if math.Abs(value-math.Round(value)) < 0.001 {
		return strconv.FormatInt(int64(math.Round(value)), 10)
	}
	return strconv.FormatFloat(value, 'f', 2, 64)
}

func deliverNotification(ctx context.Context, client *messaging.Client, delivery notificationDelivery) {
	created, err := reserveNotification(delivery)
	if err != nil {
		log.Printf("reserve notification %s failed: %v", delivery.NotificationKey, err)
		return
	}
	if !created {
		return
	}
	var tokens []struct {
		Token string `json:"token"`
	}
	path := "/rest/v1/fcm_tokens?user_id=eq." + url.QueryEscape(delivery.UserID) + "&select=token"
	if err := fetchSupabaseRows(path, &tokens); err != nil || len(tokens) == 0 {
		return
	}
	registrationTokens := make([]string, 0, len(tokens))
	for _, row := range tokens {
		if row.Token != "" {
			registrationTokens = append(registrationTokens, row.Token)
		}
	}
	if len(registrationTokens) == 0 {
		return
	}
	data := map[string]string{"type": delivery.Type, "title": delivery.Title, "body": delivery.Body}
	for key, value := range delivery.Data {
		data[key] = fmt.Sprint(value)
	}
	response, err := client.SendEachForMulticast(ctx, &messaging.MulticastMessage{
		Tokens:       registrationTokens,
		Notification: &messaging.Notification{Title: delivery.Title, Body: delivery.Body},
		Data:         data,
		Android: &messaging.AndroidConfig{
			Priority:     "high",
			Notification: &messaging.AndroidNotification{ChannelID: notificationChannelID, Sound: "alert_positive_marimba_swoop"},
		},
	})
	if err != nil {
		log.Printf("send notification %s failed: %v", delivery.NotificationKey, err)
		return
	}
	log.Printf("notification %s sent to %d/%d devices", delivery.NotificationKey, response.SuccessCount, len(registrationTokens))
}

func reserveNotification(delivery notificationDelivery) (bool, error) {
	status, body, err := doSupabaseJSON(http.MethodPost,
		"/rest/v1/notification_deliveries?on_conflict=notification_key", delivery,
		"resolution=ignore-duplicates,return=representation")
	if err != nil {
		return false, err
	}
	if status < 200 || status >= 300 {
		return false, fmt.Errorf("Supabase status %d: %s", status, safeAPIError(body))
	}
	var created []notificationDelivery
	if err := json.Unmarshal(body, &created); err != nil {
		return false, err
	}
	return len(created) > 0, nil
}

func fetchSupabaseRows(path string, destination any) error {
	status, body, err := doSupabaseJSON(http.MethodGet, path, nil, "")
	if err != nil {
		return err
	}
	if status < 200 || status >= 300 {
		return fmt.Errorf("Supabase status %d: %s", status, safeAPIError(body))
	}
	return json.Unmarshal(body, destination)
}

func doSupabaseJSON(method, path string, payload any, prefer string) (int, []byte, error) {
	baseURL := strings.TrimRight(strings.TrimSpace(os.Getenv("SUPABASE_URL")), "/")
	serviceKey := strings.TrimSpace(os.Getenv("SUPABASE_SERVICE_KEY"))
	if baseURL == "" || serviceKey == "" {
		return 0, nil, fmt.Errorf("Supabase credentials are not configured")
	}
	var reader io.Reader
	if payload != nil {
		encoded, err := json.Marshal(payload)
		if err != nil {
			return 0, nil, err
		}
		reader = bytes.NewReader(encoded)
	}
	req, err := http.NewRequest(method, baseURL+path, reader)
	if err != nil {
		return 0, nil, err
	}
	req.Header.Set("apikey", serviceKey)
	req.Header.Set("Authorization", "Bearer "+serviceKey)
	req.Header.Set("Content-Type", "application/json")
	if prefer != "" {
		req.Header.Set("Prefer", prefer)
	}
	resp, err := (&http.Client{Timeout: 20 * time.Second}).Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	return resp.StatusCode, body, err
}

func safeAPIError(body []byte) string {
	var message struct {
		Message string `json:"message"`
		Code    string `json:"code"`
	}
	if json.Unmarshal(body, &message) == nil {
		return strings.TrimSpace(message.Code + " " + message.Message)
	}
	return "upstream request failed"
}
