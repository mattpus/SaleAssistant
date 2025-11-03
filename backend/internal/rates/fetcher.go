package rates

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
)

// Fetcher retrieves conversion rates; think protocol in Swift.
type Fetcher interface {
	FetchRates(ctx context.Context) ([]Rate, error)
}

// HTTPFetcher retrieves rates from an HTTP endpoint.
type HTTPFetcher struct {
	Client *http.Client
	URL    string
}

// FetchRates fetches the conversion rates using the configured HTTP client.
// Analogue: URLSession.dataTask with JSONDecoder on the client side.
func (fetcher *HTTPFetcher) FetchRates(ctx context.Context) ([]Rate, error) {
	if fetcher == nil {
		return nil, fmt.Errorf("fetcher is not configured")
	}

	client := fetcher.Client
	if client == nil {
		client = http.DefaultClient
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, fetcher.URL, nil)
	if err != nil {
		return nil, err
	}

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var rates []Rate
	if err := json.NewDecoder(resp.Body).Decode(&rates); err != nil {
		return nil, err
	}

	return rates, nil
}
