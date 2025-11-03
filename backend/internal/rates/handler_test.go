package rates

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

type stubFetcher struct {
	rates []Rate
	err   error
}

// Implements the Fetcher interface much like a fake service in a Swift test.
func (s *stubFetcher) FetchRates(context.Context) ([]Rate, error) {
	return s.rates, s.err
}

func TestHandlerSuccess(t *testing.T) {
	// Stub the fetcher so the handler works like a Swift dependency injection test.
	fetcher := &stubFetcher{
		rates: []Rate{
			{From: "EUR", To: "USD", Rate: 1.18},
			{From: "GBP", To: "EUR", Rate: 1.12},
		},
	}

	handler := NewHandler(fetcher)
	req := httptest.NewRequest(http.MethodGet, "/rates", nil)
	rr := httptest.NewRecorder()

	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rr.Code)
	}

	var response []Rate
	if err := json.Unmarshal(rr.Body.Bytes(), &response); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}

	if len(response) != 2 {
		t.Fatalf("expected 2 rates, got %d", len(response))
	}

	assertHasRate(t, response, "EUR", 1.18)
	assertHasRate(t, response, "GBP", 1.3216)
}

func TestHandlerFetcherFailure(t *testing.T) {
	// If the data fetch fails we expect a 502, similar to propagating a client error in Swift.
	handler := NewHandler(&stubFetcher{err: errTest})

	req := httptest.NewRequest(http.MethodGet, "/rates", nil)
	rr := httptest.NewRecorder()

	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusBadGateway {
		t.Fatalf("expected status 502, got %d", rr.Code)
	}
}

func TestHandlerConversionFailure(t *testing.T) {
	// Invalid upstream payload should bubble up as a 500 for the client.
	handler := NewHandler(&stubFetcher{
		rates: []Rate{
			{From: "EUR", To: "USD", Rate: 0},
		},
	})

	req := httptest.NewRequest(http.MethodGet, "/rates", nil)
	rr := httptest.NewRecorder()

	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusInternalServerError {
		t.Fatalf("expected status 500, got %d", rr.Code)
	}
}

func TestHandlerMethodNotAllowed(t *testing.T) {
	// POST should be rejected (405) because we only support GET /rates.
	handler := NewHandler(&stubFetcher{})

	req := httptest.NewRequest(http.MethodPost, "/rates", nil)
	rr := httptest.NewRecorder()

	handler.ServeHTTP(rr, req)

	if rr.Code != http.StatusMethodNotAllowed {
		t.Fatalf("expected status 405, got %d", rr.Code)
	}
}

type errorString string

func (e errorString) Error() string { return string(e) }

var errTest = errorString("fetch failed")
