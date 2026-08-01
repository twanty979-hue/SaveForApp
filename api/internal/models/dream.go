package models

import "time"

type Dream struct {
	ID                  string     `json:"id" db:"id"`
	UserID              string     `json:"user_id" db:"user_id"`
	Title               string     `json:"title" db:"title"`
	TargetAmount        float64    `json:"target_amount" db:"target_amount"`
	CurrentAmount       float64    `json:"current_amount" db:"current_amount"`
	TargetDate          *time.Time `json:"target_date,omitempty" db:"target_date"`
	Icon                string     `json:"icon" db:"icon"`
	MonthlySavingTarget float64    `json:"monthly_saving_target" db:"monthly_saving_target"`
	IsStarred           bool       `json:"is_starred" db:"is_starred"`
	CreatedAt           time.Time  `json:"created_at" db:"created_at"`
}
