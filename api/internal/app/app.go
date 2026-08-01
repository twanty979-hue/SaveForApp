package app

import (
	"fmt"
	"log"
	"savefor-api/internal/config"
	"savefor-api/internal/handlers"
)

func Run() {
	// โหลดคอนฟิก
	cfg := config.LoadConfig()

	// ตั้งค่าเราต์
	router := handlers.SetupRouter()

	// รันเซิร์ฟเวอร์
	log.Printf("Starting SaveFor API server on port %s", cfg.Port)
	if err := router.Run(fmt.Sprintf(":%s", cfg.Port)); err != nil {
		log.Fatalf("Failed to run API server: %v", err)
	}
}
