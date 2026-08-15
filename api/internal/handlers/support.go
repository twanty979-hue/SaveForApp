package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"

	"github.com/gin-gonic/gin"
)

type supportTicket struct {
	ID         string `json:"id"`
	UserID     string `json:"user_id"`
	TicketType string `json:"ticket_type"`
	Subject    string `json:"subject"`
	Status     string `json:"status"`
	Priority   string `json:"priority"`
	CreatedAt  string `json:"created_at"`
	UpdatedAt  string `json:"updated_at"`
}

type createSupportTicketInput struct {
	TicketType string `json:"ticket_type"`
	Subject    string `json:"subject"`
	Message    string `json:"message"`
}

type createFeatureRequestInput struct {
	Title       string `json:"title"`
	Description string `json:"description"`
}

func handleListSupportChannels(c *gin.Context) {
	path := "/rest/v1/support_channels?is_active=eq.true&select=id,channel_key,label,address,url,icon_key&order=sort_order.asc"
	status, body, err := doSupabaseJSON(http.MethodGet, path, nil, "")
	if err != nil || status < 200 || status >= 300 {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to load support channels"})
		return
	}
	c.Data(http.StatusOK, "application/json", body)
}

func handleListSupportTickets(c *gin.Context) {
	userID, ok := authenticatedUserID(c)
	if !ok {
		return
	}
	path := "/rest/v1/support_tickets?user_id=eq." + url.QueryEscape(userID) +
		"&select=id,ticket_type,subject,status,priority,created_at,updated_at&order=created_at.desc&limit=100"
	status, body, err := doSupabaseJSON(http.MethodGet, path, nil, "")
	if err != nil || status < 200 || status >= 300 {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to load support requests"})
		return
	}
	c.Data(http.StatusOK, "application/json", body)
}

func handleCreateSupportTicket(c *gin.Context) {
	userID, ok := authenticatedUserID(c)
	if !ok {
		return
	}

	var input createSupportTicketInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid support request"})
		return
	}
	input.TicketType = strings.TrimSpace(strings.ToLower(input.TicketType))
	input.Subject = strings.TrimSpace(input.Subject)
	input.Message = strings.TrimSpace(input.Message)
	if input.TicketType != "bug" && input.TicketType != "contact" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Support request type must be bug or contact"})
		return
	}
	if len([]rune(input.Subject)) < 3 || len([]rune(input.Subject)) > 160 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Subject must be between 3 and 160 characters"})
		return
	}
	if len([]rune(input.Message)) < 1 || len([]rune(input.Message)) > 10000 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Message must be between 1 and 10000 characters"})
		return
	}

	ticketPayload := map[string]any{
		"user_id":     userID,
		"ticket_type": input.TicketType,
		"subject":     input.Subject,
		"status":      "open",
		"priority":    "normal",
	}
	status, body, err := doSupabaseJSON(
		http.MethodPost,
		"/rest/v1/support_tickets",
		ticketPayload,
		"return=representation",
	)
	if err != nil || status < 200 || status >= 300 {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to create support request"})
		return
	}

	var tickets []supportTicket
	if err := json.Unmarshal(body, &tickets); err != nil || len(tickets) == 0 || tickets[0].ID == "" {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Support request was created but could not be read"})
		return
	}
	ticket := tickets[0]

	messagePayload := map[string]any{
		"ticket_id":      ticket.ID,
		"author_user_id": userID,
		"author_type":    "user",
		"body":           input.Message,
	}
	messageStatus, _, messageErr := doSupabaseJSON(
		http.MethodPost,
		"/rest/v1/support_messages",
		messagePayload,
		"return=minimal",
	)
	if messageErr != nil || messageStatus < 200 || messageStatus >= 300 {
		_, _, _ = doSupabaseJSON(
			http.MethodDelete,
			"/rest/v1/support_tickets?id=eq."+url.QueryEscape(ticket.ID)+"&user_id=eq."+url.QueryEscape(userID),
			nil,
			"return=minimal",
		)
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to save support message"})
		return
	}

	c.JSON(http.StatusCreated, ticket)
}

func handleListFeatureRequests(c *gin.Context) {
	userID, ok := authenticatedUserID(c)
	if !ok {
		return
	}
	path := "/rest/v1/feature_requests?submitted_by=eq." + url.QueryEscape(userID) +
		"&select=id,title,description,status,created_at,updated_at&order=created_at.desc&limit=100"
	status, body, err := doSupabaseJSON(http.MethodGet, path, nil, "")
	if err != nil || status < 200 || status >= 300 {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to load feature requests"})
		return
	}
	c.Data(http.StatusOK, "application/json", body)
}

func handleCreateFeatureRequest(c *gin.Context) {
	userID, ok := authenticatedUserID(c)
	if !ok {
		return
	}

	var input createFeatureRequestInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid feature request"})
		return
	}
	input.Title = strings.TrimSpace(input.Title)
	input.Description = strings.TrimSpace(input.Description)
	if len([]rune(input.Title)) < 3 || len([]rune(input.Title)) > 160 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Title must be between 3 and 160 characters"})
		return
	}
	if len([]rune(input.Description)) < 1 || len([]rune(input.Description)) > 10000 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Description must be between 1 and 10000 characters"})
		return
	}

	payload := map[string]any{
		"submitted_by": userID,
		"title":        input.Title,
		"description":  input.Description,
		"status":       "submitted",
	}
	status, body, err := doSupabaseJSON(
		http.MethodPost,
		"/rest/v1/feature_requests",
		payload,
		"return=representation",
	)
	if err != nil || status < 200 || status >= 300 {
		c.JSON(http.StatusBadGateway, gin.H{"error": "Unable to save feature request"})
		return
	}

	var requests []map[string]any
	if err := json.Unmarshal(body, &requests); err != nil || len(requests) == 0 {
		c.JSON(http.StatusBadGateway, gin.H{"error": fmt.Sprintf("Feature request was saved but could not be read: %v", err)})
		return
	}
	c.JSON(http.StatusCreated, requests[0])
}
