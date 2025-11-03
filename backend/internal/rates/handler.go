package rates

import (
	"context"
	"encoding/json"
	"net/http"
)

// Handler exposes the USD conversion endpoint (similar to a lightweight Vapor controller).
type Handler struct {
	fetcher Fetcher
}

// NewHandler creates a new Handler instance.
func NewHandler(fetcher Fetcher) *Handler {
	return &Handler{fetcher: fetcher}
}

// ServeHTTP handles GET /rates requests.
func (handler *Handler) ServeHTTP(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodGet {
		http.Error(writer, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	if handler.fetcher == nil {
		http.Error(writer, "rates fetcher not configured", http.StatusInternalServerError)
		return
	}

	ctx := request.Context()
	allRates, err := handler.fetcher.FetchRates(ctx)
	if err != nil {
		writeError(ctx, writer, http.StatusBadGateway, "failed to fetch rates")
		return
	}

	conversions, err := BuildUSDConversionRates(allRates)
	if err != nil {
		writeError(ctx, writer, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(ctx, writer, http.StatusOK, conversions)
}

func writeJSON(_ context.Context, writer http.ResponseWriter, status int, payload interface{}) {
	writer.Header().Set("Content-Type", "application/json")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(payload)
}

func writeError(ctx context.Context, w http.ResponseWriter, status int, message string) {
	type errorResponse struct {
		Error string `json:"error"`
	}
	writeJSON(ctx, w, status, errorResponse{Error: message})
}
