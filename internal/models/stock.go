package models

import (
	"fmt"
	"math"
	"regexp"
	"time"
)

// StockData represents stock price information
type StockData struct {
	Symbol    string    `json:"symbol"`
	Timestamp time.Time `json:"timestamp"`
	Open      float64   `json:"open"`
	High      float64   `json:"high"`
	Low       float64   `json:"low"`
	Close     float64   `json:"close"`
	Volume    int64     `json:"volume"`
}

// PredictionRequest represents a prediction request
type PredictionRequest struct {
	Symbol       string    `json:"symbol"`
	HistoricalData []float64 `json:"historical_data"`
	RequestTime  time.Time `json:"request_time"`
}

// PredictionResponse represents a prediction response
type PredictionResponse struct {
	Symbol          string    `json:"symbol"`
	CurrentPrice    float64   `json:"current_price"`
	PredictedPrice  float64   `json:"predicted_price"`
	TradingSignal   string    `json:"trading_signal"`
	Confidence      float64   `json:"confidence"`
	PredictionTime  time.Time `json:"prediction_time"`
	ModelVersion    string    `json:"model_version"`
}

// TradingSignal represents trading recommendations
type TradingSignal string

const (
	SignalBuy  TradingSignal = "BUY"
	SignalSell TradingSignal = "SELL"
	SignalHold TradingSignal = "HOLD"
)

// YahooFinanceResponse represents Yahoo Finance API response
type YahooFinanceResponse struct {
	Chart struct {
		Result []struct {
			Meta struct {
				Symbol   string  `json:"symbol"`
				Currency string  `json:"currency"`
				RegularMarketPrice float64 `json:"regularMarketPrice"`
			} `json:"meta"`
			Timestamp  []int64 `json:"timestamp"`
			Indicators struct {
				Quote []struct {
					Open   []float64 `json:"open"`
					High   []float64 `json:"high"`
					Low    []float64 `json:"low"`
					Close  []float64 `json:"close"`
					Volume []int64   `json:"volume"`
				} `json:"quote"`
			} `json:"indicators"`
		} `json:"result"`
		Error *struct {
			Code        string `json:"code"`
			Description string `json:"description"`
		} `json:"error"`
	} `json:"chart"`
}

// HealthStatus represents system health
type HealthStatus struct {
	Status    string            `json:"status"`
	Timestamp time.Time         `json:"timestamp"`
	Version   string            `json:"version"`
	Services  map[string]string `json:"services"`
}

// Validation functions

// ValidateSymbol validates stock symbol format
func ValidateSymbol(symbol string) error {
	if symbol == "" {
		return fmt.Errorf("symbol cannot be empty")
	}
	
	matched, err := regexp.MatchString("^[A-Z]{1,5}$", symbol)
	if err != nil {
		return fmt.Errorf("regex error: %w", err)
	}
	
	if !matched {
		return fmt.Errorf("invalid symbol format: %s (must be 1-5 uppercase letters)", symbol)
	}
	
	return nil
}

// ValidateStockData validates stock price data
func ValidateStockData(data []float64, minLength int) error {
	if len(data) < minLength {
		return fmt.Errorf("insufficient data points: got %d, need at least %d", len(data), minLength)
	}
	
	for i, price := range data {
		if price <= 0 {
			return fmt.Errorf("invalid price at index %d: %f (must be positive)", i, price)
		}
		if math.IsNaN(price) {
			return fmt.Errorf("NaN price at index %d", i)
		}
		if math.IsInf(price, 0) {
			return fmt.Errorf("infinite price at index %d", i)
		}
	}
	
	return nil
}

// ValidatePredictionRequest validates prediction request
func (pr *PredictionRequest) Validate() error {
	if err := ValidateSymbol(pr.Symbol); err != nil {
		return fmt.Errorf("invalid symbol: %w", err)
	}
	
	if err := ValidateStockData(pr.HistoricalData, 5); err != nil {
		return fmt.Errorf("invalid historical data: %w", err)
	}
	
	return nil
}

// GenerateTradingSignal generates trading signal based on prediction
func GenerateTradingSignal(currentPrice, predictedPrice, buyThreshold, sellThreshold float64) TradingSignal {
	ratio := predictedPrice / currentPrice
	
	if ratio > buyThreshold {
		return SignalBuy
	} else if ratio < sellThreshold {
		return SignalSell
	}
	
	return SignalHold
}

// CalculateConfidence calculates prediction confidence (enhanced)
func CalculateConfidence(currentPrice, predictedPrice float64) float64 {
	// Enhanced confidence calculation with multiple factors
	priceChange := math.Abs(predictedPrice-currentPrice) / currentPrice
	
	// Use exponential decay instead of linear (more realistic)
	confidence := math.Exp(-priceChange * 7)
	
	// Penalize very small changes (might indicate model uncertainty)
	if priceChange < 0.003 { // Less than 0.3%
		confidence *= 0.85
	}
	
	// Boost confidence for moderate changes (1-3% range is often more reliable)
	if priceChange >= 0.01 && priceChange <= 0.03 {
		confidence *= 1.1
	}
	
	// Penalize extreme changes (>10% is often unreliable for daily predictions)
	if priceChange > 0.10 {
		confidence *= 0.6
	}
	
	// Ensure reasonable bounds (0.15 to 0.90)
	return math.Max(0.15, math.Min(0.90, confidence))
}

// ModelInfo represents information about the prediction model
type ModelInfo struct {
	Name        string                 `json:"name"`
	Version     string                 `json:"version"`
	Description string                 `json:"description"`
	Features    []string               `json:"features"`
	Config      map[string]interface{} `json:"config"`
}
