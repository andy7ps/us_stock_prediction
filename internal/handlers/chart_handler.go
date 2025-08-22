package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/gorilla/mux"
	"stock-prediction-us/internal/models"
	"stock-prediction-us/internal/services/yahoo"
)

type ChartHandler struct {
	yahooClient *yahoo.Client
}

func NewChartHandler(yahooClient *yahoo.Client) *ChartHandler {
	return &ChartHandler{
		yahooClient: yahooClient,
	}
}

// GetChartData handles GET /api/v1/chart/{symbol}
func (h *ChartHandler) GetChartData(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	symbol := strings.ToUpper(vars["symbol"])
	
	if symbol == "" {
		http.Error(w, "Symbol is required", http.StatusBadRequest)
		return
	}

	// Get query parameters
	timeRange := r.URL.Query().Get("range")
	if timeRange == "" {
		timeRange = "1M" // Default to 1 month
	}

	format := r.URL.Query().Get("format")
	if format == "" {
		format = "candlestick"
	}

	// Convert time range to days
	days := convertTimeRangeToDays(timeRange)
	
	// Get historical data from Yahoo client
	historicalData, err := h.yahooClient.FetchHistoricalData(symbol, days)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to fetch data for %s: %v", symbol, err), http.StatusInternalServerError)
		return
	}

	if len(historicalData) == 0 {
		http.Error(w, fmt.Sprintf("No data available for symbol %s", symbol), http.StatusNotFound)
		return
	}

	// Convert to candlestick format
	candlestickData := make([]models.CandlestickData, len(historicalData))
	for i, data := range historicalData {
		candlestickData[i] = models.CandlestickData{
			Symbol:    data.Symbol,
			Timestamp: data.Timestamp,
			Open:      data.Open,
			High:      data.High,
			Low:       data.Low,
			Close:     data.Close,
			Volume:    data.Volume,
		}
	}

	// Calculate current price and change
	var currentPrice, change, changePercent float64
	if len(candlestickData) >= 2 {
		currentPrice = candlestickData[0].Close // Most recent (first in slice)
		previousPrice := candlestickData[1].Close
		change = currentPrice - previousPrice
		if previousPrice != 0 {
			changePercent = (change / previousPrice) * 100
		}
	} else if len(candlestickData) == 1 {
		currentPrice = candlestickData[0].Close
	}

	// Create response
	response := models.ChartDataResponse{
		Symbol:        symbol,
		Data:          candlestickData,
		Count:         len(candlestickData),
		TimeRange:     timeRange,
		CurrentPrice:  currentPrice,
		Change:        change,
		ChangePercent: changePercent,
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if err := json.NewEncoder(w).Encode(response); err != nil {
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}
}

// GetIntradayData handles GET /api/v1/chart/{symbol}/intraday
func (h *ChartHandler) GetIntradayData(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	symbol := strings.ToUpper(vars["symbol"])
	
	if symbol == "" {
		http.Error(w, "Symbol is required", http.StatusBadRequest)
		return
	}

	interval := r.URL.Query().Get("interval")
	if interval == "" {
		interval = "5min"
	}

	// For now, return 1-day data as intraday
	// In a real implementation, you'd fetch actual intraday data
	historicalData, err := h.yahooClient.FetchHistoricalData(symbol, 1)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to fetch intraday data for %s: %v", symbol, err), http.StatusInternalServerError)
		return
	}

	if len(historicalData) == 0 {
		http.Error(w, fmt.Sprintf("No intraday data available for symbol %s", symbol), http.StatusNotFound)
		return
	}

	// Convert to candlestick format
	candlestickData := make([]models.CandlestickData, len(historicalData))
	for i, data := range historicalData {
		candlestickData[i] = models.CandlestickData{
			Symbol:    data.Symbol,
			Timestamp: data.Timestamp,
			Open:      data.Open,
			High:      data.High,
			Low:       data.Low,
			Close:     data.Close,
			Volume:    data.Volume,
		}
	}

	response := models.ChartDataResponse{
		Symbol:    symbol,
		Data:      candlestickData,
		Count:     len(candlestickData),
		TimeRange: "1D",
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if err := json.NewEncoder(w).Encode(response); err != nil {
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}
}

// GetCurrentQuote handles GET /api/v1/quote/{symbol}
func (h *ChartHandler) GetCurrentQuote(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	symbol := strings.ToUpper(vars["symbol"])
	
	if symbol == "" {
		http.Error(w, "Symbol is required", http.StatusBadRequest)
		return
	}

	// Get latest data (1 day)
	historicalData, err := h.yahooClient.FetchHistoricalData(symbol, 1)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to fetch quote for %s: %v", symbol, err), http.StatusInternalServerError)
		return
	}

	if len(historicalData) == 0 {
		http.Error(w, fmt.Sprintf("No quote data available for symbol %s", symbol), http.StatusNotFound)
		return
	}

	latestData := historicalData[0]
	
	// Create quote response
	quote := map[string]interface{}{
		"symbol":     latestData.Symbol,
		"price":      latestData.Close,
		"open":       latestData.Open,
		"high":       latestData.High,
		"low":        latestData.Low,
		"volume":     latestData.Volume,
		"timestamp":  latestData.Timestamp,
		"market_cap": "N/A", // Would need additional API call
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if err := json.NewEncoder(w).Encode(quote); err != nil {
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}
}

// Helper function to convert time range to days
func convertTimeRangeToDays(timeRange string) int {
	switch strings.ToUpper(timeRange) {
	case "1D":
		return 1
	case "5D":
		return 5
	case "1M":
		return 30
	case "3M":
		return 90
	case "6M":
		return 180
	case "1Y":
		return 365
	case "5Y":
		return 1825
	case "MAX":
		return 3650 // 10 years max
	default:
		return 30 // Default to 1 month
	}
}

// HandleOptions handles CORS preflight requests
func (h *ChartHandler) HandleOptions(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
	w.WriteHeader(http.StatusOK)
}
