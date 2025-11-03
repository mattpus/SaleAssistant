package rates

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestHTTPFetcherSuccess(t *testing.T) {
	// Simulate a happy-path HTTP server, similar to using URLProtocol stubs in Swift tests.
	testRates := []Rate{
		{From: "EUR", To: "USD", Rate: 1.18},
	}

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = json.NewEncoder(w).Encode(testRates)
	}))
	defer server.Close()

	fetcher := &HTTPFetcher{
		Client: server.Client(),
		URL:    server.URL,
	}

	rates, err := fetcher.FetchRates(context.Background())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(rates) != len(testRates) {
		t.Fatalf("expected %d rates, got %d", len(testRates), len(rates))
	}

	if rates[0] != testRates[0] {
		t.Fatalf("expected rate %+v, got %+v", testRates[0], rates[0])
	}
}

func TestHTTPFetcherNon200Status(t *testing.T) {
	// If the upstream responds with a non-200 we surface an error to the caller.
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "bad gateway", http.StatusBadGateway)
	}))
	defer server.Close()

	fetcher := &HTTPFetcher{
		Client: server.Client(),
		URL:    server.URL,
	}

	if _, err := fetcher.FetchRates(context.Background()); err == nil {
		t.Fatal("expected error for non-200 status")
	}
}

func TestHTTPFetcherRequestError(t *testing.T) {
	// Custom RoundTripper lets us emulate transport failure like URLSession error.
	fetcher := &HTTPFetcher{
		Client: &http.Client{
			Transport: errorRoundTripper{},
			Timeout:   time.Second,
		},
		URL: "https://example.com/rates",
	}

	if _, err := fetcher.FetchRates(context.Background()); err == nil {
		t.Fatal("expected error for request failure")
	}
}

type errorRoundTripper struct{}

// RoundTrip returns an error to mimic a network transport failure.
func (errorRoundTripper) RoundTrip(*http.Request) (*http.Response, error) {
	return nil, errTest
}
