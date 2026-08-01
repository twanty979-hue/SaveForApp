package models

import "time"

type FixedExpense struct {
	ID        string    `json:"id" db:"id"`
	UserID    string    `json:"user_id" db:"user_id"`
	Name      string    `json:"name" db:"name"`
	Amount    float64   `json:"amount" db:"amount"`
	Category  string    `json:"category" db:"category"`
	DueDay    int       `json:"due_day" db:"due_day"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}
