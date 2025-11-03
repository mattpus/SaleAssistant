package main

import (
	"log"
	"net/http"
	"os"
	"saleassist/middleware/internal/rates"
	"time"
)

const (
	defaultListenAddr = ":8080"
	defaultRatesURL   = "https://ile-b2p4.essentialdeveloper.com/rates"
)

func main() {

	ratesURL := defaultRatesURL

	// option for overwritting the rates endpoint by the configuration
	if envURL := os.Getenv("RATES_ENDPOINT_URL"); envURL != "" {
		ratesURL = envURL
	}

	// Shared http.Client with request timeout
	client := &http.Client{Timeout: 5 * time.Second}
	handler := rates.NewHandler(&rates.HTTPFetcher{
		Client: client,
		URL:    ratesURL,
	})

	mux := http.NewServeMux()
	mux.Handle("/rates", handler)

	addr := defaultListenAddr

	// option for overwritting the port by the configuration
	if envAddr := os.Getenv("LISTEN_ADDR"); envAddr != "" {
		addr = envAddr
	}

	log.Printf("middleware listening on %s", addr)
	if err := http.ListenAndServe(addr, mux); err != nil && err != http.ErrServerClosed {
		log.Fatalf("server error: %v", err)
	}
}
