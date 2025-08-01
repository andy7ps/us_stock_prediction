package models

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestValidateSymbol(t *testing.T) {
	tests := []struct {
		name    string
		symbol  string
		wantErr bool
	}{
		{"Valid symbol", "AAPL", false},
		{"Valid symbol 2", "NVDA", false},
		{"Valid symbol 3", "GOOGL", false},
		{"Empty symbol", "", true},
		{"Lowercase symbol", "aapl", true},
		{"Too long symbol", "TOOLONG", true},
		{"Invalid characters", "AA-PL", true},
		{"Numbers in symbol", "AA1PL", true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateSymbol(tt.symbol)
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

func TestValidateStockData(t *testing.T) {
	tests := []struct {
		name      string
		data      []float64
		minLength int
		wantErr   bool
	}{
		{"Valid data", []float64{100.0, 101.0, 102.0}, 3, false},
		{"Insufficient data", []float64{100.0}, 3, true},
		{"Zero price", []float64{100.0, 0.0, 102.0}, 3, true},
		{"Negative price", []float64{100.0, -1.0, 102.0}, 3, true},
		{"Empty data", []float64{}, 1, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateStockData(tt.data, tt.minLength)
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

func TestPredictionRequest_Validate(t *testing.T) {
	tests := []struct {
		name    string
		req     *PredictionRequest
		wantErr bool
	}{
		{
			"Valid request",
			&PredictionRequest{
				Symbol:         "AAPL",
				HistoricalData: []float64{100.0, 101.0, 102.0, 103.0, 104.0},
				RequestTime:    time.Now(),
			},
			false,
		},
		{
			"Invalid symbol",
			&PredictionRequest{
				Symbol:         "invalid",
				HistoricalData: []float64{100.0, 101.0, 102.0, 103.0, 104.0},
				RequestTime:    time.Now(),
			},
			true,
		},
		{
			"Insufficient data",
			&PredictionRequest{
				Symbol:         "AAPL",
				HistoricalData: []float64{100.0},
				RequestTime:    time.Now(),
			},
			true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.req.Validate()
			if tt.wantErr {
				assert.Error(t, err)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

func TestGenerateTradingSignal(t *testing.T) {
	tests := []struct {
		name           string
		currentPrice   float64
		predictedPrice float64
		buyThreshold   float64
		sellThreshold  float64
		expected       TradingSignal
	}{
		{"Buy signal", 100.0, 102.0, 1.01, 0.99, SignalBuy},
		{"Sell signal", 100.0, 98.0, 1.01, 0.99, SignalSell},
		{"Hold signal", 100.0, 100.5, 1.01, 0.99, SignalHold},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := GenerateTradingSignal(tt.currentPrice, tt.predictedPrice, tt.buyThreshold, tt.sellThreshold)
			assert.Equal(t, tt.expected, result)
		})
	}
}

func TestCalculateConfidence(t *testing.T) {
	tests := []struct {
		name           string
		currentPrice   float64
		predictedPrice float64
		expectHigh     bool // true if confidence should be > 0.5
	}{
		{"Small change", 100.0, 100.1, true},
		{"Large change", 100.0, 120.0, false},
		{"Same price", 100.0, 100.0, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			confidence := CalculateConfidence(tt.currentPrice, tt.predictedPrice)
			assert.True(t, confidence >= 0.0 && confidence <= 1.0, "Confidence should be between 0 and 1")
			
			if tt.expectHigh {
				assert.True(t, confidence > 0.5, "Expected high confidence")
			} else {
				assert.True(t, confidence <= 0.5, "Expected low confidence")
			}
		})
	}
}
