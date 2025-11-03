package rates

import (
	"math"
	"testing"
)

func TestBuildUSDConversionRates_MultiStep(t *testing.T) {
	// Fake rates recieved from /rates endpoint
	input := []Rate{
		{From: "EUR", To: "USD", Rate: 1.18},
		{From: "GBP", To: "EUR", Rate: 1.12},
		{From: "CAD", To: "JPY", Rate: 80},
		{From: "BRL", To: "CAD", Rate: 0.19},
		{From: "JPY", To: "GBP", Rate: 0.007},
		{From: "AUD", To: "ZAR", Rate: 10},
		{From: "ZAR", To: "INR", Rate: 5},
		{From: "USD", To: "INR", Rate: 83.96},
	}

	conversions, err := BuildUSDConversionRates(input)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	assertHasRate(t, conversions, "AUD", 0.5955216769890423)
	assertHasRate(t, conversions, "BRL", 0.14061824)
	assertHasRate(t, conversions, "CAD", 0.740096)
	assertHasRate(t, conversions, "EUR", 1.18)
	assertHasRate(t, conversions, "GBP", 1.3216)
	assertHasRate(t, conversions, "INR", 0.011910433539780848)
	assertHasRate(t, conversions, "JPY", 0.009251200000000001)
	assertHasRate(t, conversions, "ZAR", 0.059552167698904236)
}

func TestBuildUSDConversionRates_ZeroRateFails(t *testing.T) {
	// Ensure we fail fast when encountering an impossible (zero) exchange rate.
	input := []Rate{
		{From: "EUR", To: "USD", Rate: 0},
	}

	_, err := BuildUSDConversionRates(input)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
}

func TestBuildUSDConversionRates_UnreachableUSD(t *testing.T) {
	// No possibility to convert to USD should cause an error
	input := []Rate{
		{From: "EUR", To: "GBP", Rate: 2},
	}

	_, err := BuildUSDConversionRates(input)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
}

// Helper function to help compare the correct rates.
func assertHasRate(t *testing.T, conversions []Rate, currency string, expected float64) {
	t.Helper()

	// Search for the desired currency and compare rates with a tolerance accuracy.
	for _, rate := range conversions {
		if rate.From == currency {
			if rate.To != "USD" {
				t.Fatalf("expected conversion %s -> USD, got %s -> %s", currency, rate.From, rate.To)
			}
			if !nearlyEqual(rate.Rate, expected) {
				t.Fatalf("expected rate %.12f, got %.12f for %s", expected, rate.Rate, currency)
			}
			return
		}
	}

	t.Fatalf("rate for currency %s not found", currency)
}

func nearlyEqual(a, b float64) bool {
	const tolerance = 1e-9
	return math.Abs(a-b) <= tolerance
}
