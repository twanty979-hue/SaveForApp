package models

import "time"

type Transaction struct {
	ID              string    `json:"id" db:"id"`
	UserID          string    `json:"user_id" db:"user_id"`
	Type            string    `json:"type" db:"type"` // "expense" or "income"
	Amount          float64   `json:"amount" db:"amount"`
	Note            string    `json:"note" db:"note"`
	TransactionDate time.Time `json:"transaction_date" db:"transaction_date"`
	CreatedAt       time.Time `json:"created_at" db:"created_at"`
}
