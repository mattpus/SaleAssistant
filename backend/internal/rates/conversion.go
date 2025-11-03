package rates

import (
	"errors"
	"fmt"
)

// Rate represents a currency conversion rate (like a struct in Swift).
type Rate struct {
	From string  `json:"from"`
	To   string  `json:"to"`
	Rate float64 `json:"rate"`
}

// needed for building the graph structure for rates algorithm.
type edge struct {
	to   string
	rate float64
}

// BuildUSDConversionRates returns an array of rates where each entry represents
// the effective conversion from a foreign currency into USD, even if multiple
// steps are needed.
func BuildUSDConversionRates(allRates []Rate) ([]Rate, error) {
	rates, err := computeUSDConversionMap(allRates)
	if err != nil {
		return nil, err
	}

	delete(rates, "USD")

	if len(rates) == 0 {
		return nil, errors.New("no conversions to USD could be computed")
	}

	currencies := make([]string, 0, len(rates))
	for currency := range rates {
		currencies = append(currencies, currency)
	}

	for i := 1; i < len(currencies); i++ {
		key := currencies[i]
		j := i - 1
		for j >= 0 && currencies[j] > key {
			currencies[j+1] = currencies[j]
			j--
		}
		currencies[j+1] = key
	}

	result := make([]Rate, 0, len(rates))
	for _, currency := range currencies {
		result = append(result, Rate{
			From: currency,
			To:   "USD",
			Rate: rates[currency],
		})
	}

	return result, nil
}

func computeUSDConversionMap(allRates []Rate) (map[string]float64, error) {
	graph, err := buildGraph(allRates)
	if err != nil {
		return nil, err
	}

	if _, ok := graph["USD"]; !ok {
		return nil, errors.New("currency USD not present in rates graph")
	}

	type queueItem struct {
		currency string
	}

	queue := []queueItem{{currency: "USD"}}
	result := map[string]float64{"USD": 1}

	for len(queue) > 0 {
		item := queue[0]
		queue = queue[1:]

		currentRate := result[item.currency]
		for _, edge := range graph[item.currency] {
			if _, visited := result[edge.to]; visited {
				continue
			}

			if edge.rate == 0 {
				return nil, fmt.Errorf("invalid rate detected on edge %s -> %s", item.currency, edge.to)
			}

			neighborRate := currentRate / edge.rate
			result[edge.to] = neighborRate
			queue = append(queue, queueItem{currency: edge.to})
		}
	}

	return result, nil
}

func buildGraph(allRates []Rate) (map[string][]edge, error) {
	graph := make(map[string][]edge)

	for _, r := range allRates {
		if r.From == "" || r.To == "" {
			return nil, errors.New("rate must have from and to currencies")
		}

		if r.Rate <= 0 {
			return nil, fmt.Errorf("rate from %s to %s must be positive", r.From, r.To)
		}

		graph[r.From] = append(graph[r.From], edge{to: r.To, rate: r.Rate})
		graph[r.To] = append(graph[r.To], edge{to: r.From, rate: 1 / r.Rate})
	}

	return graph, nil
}
