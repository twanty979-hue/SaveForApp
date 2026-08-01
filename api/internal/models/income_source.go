package models

import "time"

type IncomeSource struct {
	ID         string    `json:"id" db:"id"`
	UserID     string    `json:"user_id" db:"user_id"`
	Name       string    `json:"name" db:"name"`
	Amount     float64   `json:"amount" db:"amount"`
	Category   string    `json:"category" db:"category"`
	ReceiveDay int       `json:"receive_day" db:"receive_day"`
	CreatedAt  time.Time `json:"created_at" db:"created_at"`
}
