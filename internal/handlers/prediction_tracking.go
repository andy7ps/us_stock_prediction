package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gorilla/mux"
	"stock-prediction-us/internal/models"
	"stock-prediction-us/internal/services"
)

type PredictionTrackingHandler struct {
	predictionTracker *services.PredictionTrackerService
	accuracyCalculator *services.AccuracyCalculatorService
}

// NewPredictionTrackingHandler creates a new prediction tracking handler
func NewPredictionTrackingHandler(predictionTracker *services.PredictionTrackerService, accuracyCalculator *services.AccuracyCalculatorService) *PredictionTrackingHandler {
	return &PredictionTrackingHandler{
		predictionTracker:  predictionTracker,
		accuracyCalculator: accuracyCalculator,
	}
}

// RegisterRoutes registers all prediction tracking routes
func (h *PredictionTrackingHandler) RegisterRoutes(router *mux.Router) {
	// Daily prediction endpoints
	router.HandleFunc("/api/v1/predictions/daily-run", h.ExecuteDailyPredictions).Methods("POST", "OPTIONS")
	router.HandleFunc("/api/v1/predictions/daily-status", h.GetDailyStatus).Methods("GET", "OPTIONS")

	// Accuracy tracking endpoints
	router.HandleFunc("/api/v1/predictions/accuracy/{symbol}", h.GetAccuracySummary).Methods("GET", "OPTIONS")
	router.HandleFunc("/api/v1/predictions/accuracy/summary", h.GetOverallPerformance).Methods("GET", "OPTIONS")
	router.HandleFunc("/api/v1/predictions/accuracy/range", h.GetAccuracyRange).Methods("GET", "OPTIONS")

	// Historical data endpoints
	router.HandleFunc("/api/v1/predictions/history/{symbol}", h.GetPredictionHistory).Methods("GET", "OPTIONS")
	router.HandleFunc("/api/v1/predictions/history", h.GetAllPredictionHistory).Methods("GET", "OPTIONS")
	router.HandleFunc("/api/v1/predictions/update-actual", h.UpdateActualPrice).Methods("POST", "OPTIONS")
	router.HandleFunc("/api/v1/predictions/performance", h.GetPerformanceMetrics).Methods("GET", "OPTIONS")

	// Trends and analytics
	router.HandleFunc("/api/v1/predictions/trends/{symbol}", h.GetAccuracyTrends).Methods("GET", "OPTIONS")
	router.HandleFunc("/api/v1/predictions/top-performers", h.GetTopPerformers).Methods("GET", "OPTIONS")
}

// ExecuteDailyPredictions handles manual execution of daily predictions
func (h *PredictionTrackingHandler) ExecuteDailyPredictions(w http.ResponseWriter, r *http.Request) {
	var req models.DailyPredictionRequest
	
	// Handle empty request body (default to all symbols, current date, manual execution)
	if r.ContentLength > 0 {
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, fmt.Sprintf("Invalid request body: %v", err), http.StatusBadRequest)
			return
		}
	}
	
	// Set default values if not provided
	if len(req.Symbols) == 0 {
		// Use all supported symbols
		req.Symbols = []string{"NVDA", "TSLA", "AAPL", "MSFT", "GOOGL", "AMZN", "AUR", "PLTR", "SMCI", "TSM", "MP", "SMR", "SPY"}
	}
	
	if req.Date == nil {
		now := time.Now()
		req.Date = &now
	}
	
	// Set execution type to manual
	req.ExecutionType = models.ExecutionTypeManual

	// Execute predictions
	result, err := h.predictionTracker.ExecuteDailyPredictions(req)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to execute predictions: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

// GetDailyStatus returns the status of daily prediction executions
func (h *PredictionTrackingHandler) GetDailyStatus(w http.ResponseWriter, r *http.Request) {
	status, err := h.accuracyCalculator.GetDailyExecutionStatus()
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to get daily status: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(status)
}

// GetAccuracySummary returns accuracy summary for a specific symbol
func (h *PredictionTrackingHandler) GetAccuracySummary(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	symbol := vars["symbol"]

	if symbol == "" {
		http.Error(w, "Symbol is required", http.StatusBadRequest)
		return
	}

	summary, err := h.accuracyCalculator.GetAccuracySummary(symbol)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to get accuracy summary: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(summary)
}

// GetOverallPerformance returns overall performance metrics
func (h *PredictionTrackingHandler) GetOverallPerformance(w http.ResponseWriter, r *http.Request) {
	metrics, err := h.accuracyCalculator.GetOverallPerformanceMetrics()
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to get performance metrics: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(metrics)
}

// GetAccuracyRange returns accuracy data for a date range
func (h *PredictionTrackingHandler) GetAccuracyRange(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query()

	// Parse start and end dates
	startDateStr := query.Get("start_date")
	endDateStr := query.Get("end_date")

	if startDateStr == "" || endDateStr == "" {
		http.Error(w, "start_date and end_date are required", http.StatusBadRequest)
		return
	}

	startDate, err := time.Parse("2006-01-02", startDateStr)
	if err != nil {
		http.Error(w, "Invalid start_date format (use YYYY-MM-DD)", http.StatusBadRequest)
		return
	}

	endDate, err := time.Parse("2006-01-02", endDateStr)
	if err != nil {
		http.Error(w, "Invalid end_date format (use YYYY-MM-DD)", http.StatusBadRequest)
		return
	}

	// Parse symbols
	var symbols []string
	if symbolsStr := query.Get("symbols"); symbolsStr != "" {
		if err := json.Unmarshal([]byte(symbolsStr), &symbols); err != nil {
			// Try comma-separated format
			symbols = []string{symbolsStr}
		}
	}

	rangeQuery := models.AccuracyRangeQuery{
		StartDate: startDate,
		EndDate:   endDate,
		Symbols:   symbols,
		GroupBy:   query.Get("group_by"),
	}

	predictions, err := h.accuracyCalculator.GetAccuracyInRange(rangeQuery)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to get accuracy range: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(predictions)
}

// GetPredictionHistory returns prediction history for a specific symbol
func (h *PredictionTrackingHandler) GetPredictionHistory(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	symbol := vars["symbol"]

	if symbol == "" {
		http.Error(w, "Symbol is required", http.StatusBadRequest)
		return
	}

	query := h.parsePredictionHistoryQuery(r, &symbol)
	predictions, err := h.predictionTracker.GetPredictionHistory(query)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to get prediction history: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(predictions)
}

// GetAllPredictionHistory returns prediction history for all symbols
func (h *PredictionTrackingHandler) GetAllPredictionHistory(w http.ResponseWriter, r *http.Request) {
	query := h.parsePredictionHistoryQuery(r, nil)
	predictions, err := h.predictionTracker.GetPredictionHistory(query)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to get prediction history: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(predictions)
}

// UpdateActualPrice updates the actual closing price for a prediction
func (h *PredictionTrackingHandler) UpdateActualPrice(w http.ResponseWriter, r *http.Request) {
	var req models.UpdateActualPriceRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, fmt.Sprintf("Invalid request body: %v", err), http.StatusBadRequest)
		return
	}

	if req.Symbol == "" {
		http.Error(w, "Symbol is required", http.StatusBadRequest)
		return
	}

	if req.ActualClose <= 0 {
		http.Error(w, "Actual close price must be positive", http.StatusBadRequest)
		return
	}

	err := h.predictionTracker.UpdateActualPrice(req)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to update actual price: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "success"})
}

// GetPerformanceMetrics returns overall performance metrics
func (h *PredictionTrackingHandler) GetPerformanceMetrics(w http.ResponseWriter, r *http.Request) {
	metrics, err := h.accuracyCalculator.GetOverallPerformanceMetrics()
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to get performance metrics: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(metrics)
}

// GetAccuracyTrends returns accuracy trends for a symbol
func (h *PredictionTrackingHandler) GetAccuracyTrends(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	symbol := vars["symbol"]

	if symbol == "" {
		http.Error(w, "Symbol is required", http.StatusBadRequest)
		return
	}

	// Parse days parameter
	days := 30 // Default to 30 days
	if daysStr := r.URL.Query().Get("days"); daysStr != "" {
		if parsedDays, err := strconv.Atoi(daysStr); err == nil && parsedDays > 0 {
			days = parsedDays
		}
	}

	trends, err := h.accuracyCalculator.CalculateAccuracyTrends(symbol, days)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to get accuracy trends: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(trends)
}

// GetTopPerformers returns top performing symbols
func (h *PredictionTrackingHandler) GetTopPerformers(w http.ResponseWriter, r *http.Request) {
	// Parse limit parameter
	limit := 10 // Default to top 10
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 {
			limit = parsedLimit
		}
	}

	performers, err := h.accuracyCalculator.GetTopPerformingSymbols(limit)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to get top performers: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(performers)
}

// Helper methods

func (h *PredictionTrackingHandler) parsePredictionHistoryQuery(r *http.Request, symbol *string) models.PredictionHistoryQuery {
	query := models.PredictionHistoryQuery{
		Symbol: symbol,
	}

	urlQuery := r.URL.Query()

	// Parse start date
	if startDateStr := urlQuery.Get("start_date"); startDateStr != "" {
		if startDate, err := time.Parse("2006-01-02", startDateStr); err == nil {
			query.StartDate = &startDate
		}
	}

	// Parse end date
	if endDateStr := urlQuery.Get("end_date"); endDateStr != "" {
		if endDate, err := time.Parse("2006-01-02", endDateStr); err == nil {
			query.EndDate = &endDate
		}
	}

	// Parse limit
	if limitStr := urlQuery.Get("limit"); limitStr != "" {
		if limit, err := strconv.Atoi(limitStr); err == nil && limit > 0 {
			query.Limit = limit
		}
	} else {
		query.Limit = 100 // Default limit
	}

	// Parse offset
	if offsetStr := urlQuery.Get("offset"); offsetStr != "" {
		if offset, err := strconv.Atoi(offsetStr); err == nil && offset >= 0 {
			query.Offset = offset
		}
	}

	// Parse order by
	if orderBy := urlQuery.Get("order_by"); orderBy != "" {
		switch orderBy {
		case "date", "accuracy", "confidence":
			query.OrderBy = orderBy
		}
	}

	// Parse order direction
	if orderDir := urlQuery.Get("order_dir"); orderDir == "asc" {
		query.OrderDir = "asc"
	} else {
		query.OrderDir = "desc"
	}

	return query
}
