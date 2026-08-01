package models

import "time"

type Profile struct {
	ID          string    `json:"id" db:"id"`
	DisplayName string    `json:"display_name" db:"display_name"`
	Tier        string    `json:"tier" db:"tier"` // "free" or "pro"
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}
