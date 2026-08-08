package handlers

import (
	"encoding/base64"
	"net/http"
	"os"
	"testing"

	"github.com/joho/godotenv"
)

func TestR2Connection(t *testing.T) {
	if os.Getenv("R2_INTEGRATION_TEST") != "1" {
		t.Skip("set R2_INTEGRATION_TEST=1 to verify Cloudflare R2 credentials")
	}
	if err := godotenv.Load("../../.env"); err != nil {
		t.Fatalf("load API environment: %v", err)
	}
	cfg, err := loadR2Config()
	if err != nil {
		t.Fatal(err)
	}
	objectKey := "connection-check/codex-profile-test.png"
	png, err := base64.StdEncoding.DecodeString("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")
	if err != nil {
		t.Fatal(err)
	}
	status, body, err := doR2Request(cfg, http.MethodPut, objectKey, "image/png", png)
	if err != nil {
		t.Fatalf("connect to Cloudflare R2: %v", err)
	}
	if status < 200 || status >= 300 {
		t.Fatalf("Cloudflare R2 returned HTTP %d: %s", status, body)
	}
	defer func() {
		_, _, _ = doR2Request(cfg, http.MethodDelete, objectKey, "", nil)
	}()

	status, downloaded, err := doR2Request(cfg, http.MethodGet, objectKey, "", nil)
	if err != nil {
		t.Fatalf("download the R2 test image: %v", err)
	}
	if status != http.StatusOK {
		t.Fatalf("R2 download returned HTTP %d: %s", status, downloaded)
	}
	if string(downloaded) != string(png) {
		t.Fatal("downloaded R2 object did not match the uploaded image")
	}
}
