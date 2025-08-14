package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"runtime"
	"strconv"
	"time"

	"github.com/gorilla/mux"
	"github.com/sirupsen/logrus"

	"stock-prediction-us/internal/config"
	"stock-prediction-us/internal/metrics"
	"stock-prediction-us/internal/models"
	"stock-prediction-us/internal/services/prediction"
	"stock-prediction-us/internal/services/yahoo"
)

// Handler contains all HTTP handlers
type Handler struct {
	config           *config.Config
	logger           *logrus.Logger
	metrics          *metrics.Metrics
	yahooClient      *yahoo.Client
	predictionService *prediction.Service
}

// NewHandler creates a new handler instance
func NewHandler(
	cfg *config.Config,
	logger *logrus.Logger,
	metrics *metrics.Metrics,
	yahooClient *yahoo.Client,
	predictionService *prediction.Service,
) *Handler {
	return &Handler{
		config:           cfg,
		logger:           logger,
		metrics:          metrics,
		yahooClient:      yahooClient,
		predictionService: predictionService,
	}
}

// PredictHandler handles stock prediction requests
func (h *Handler) PredictHandler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	
	// Extract symbol from URL
	vars := mux.Vars(r)
	symbol := vars["symbol"]
	
	if symbol == "" {
		h.writeErrorResponse(w, http.StatusBadRequest, "symbol is required")
		h.metrics.RecordAPIRequest(time.Since(start).Seconds(), false)
		return
	}
	
	// Get lookback days from query parameter (default to config value)
	lookbackDays := h.config.Stock.LookbackDays
	if days := r.URL.Query().Get("days"); days != "" {
		if parsed, err := strconv.Atoi(days); err == nil && parsed > 0 && parsed <= 365 {
			lookbackDays = parsed
		}
	}
	
	h.logger.WithFields(logrus.Fields{
		"symbol":        symbol,
		"lookback_days": lookbackDays,
		"client_ip":     r.RemoteAddr,
	}).Info("Processing prediction request")
	
	// Fetch stock data
	stockData, err := h.yahooClient.FetchStockData(symbol, h.getPeriodFromDays(lookbackDays))
	if err != nil {
		h.logger.WithError(err).Error("Failed to fetch stock data")
		h.writeErrorResponse(w, http.StatusServiceUnavailable, "Failed to fetch stock data")
		h.metrics.RecordAPIRequest(time.Since(start).Seconds(), false)
		return
	}
	
	// Get last N data points
	if len(stockData) < lookbackDays {
		lookbackDays = len(stockData)
	}
	lastData := stockData[len(stockData)-lookbackDays:]
	
	// Create prediction request
	predReq := &models.PredictionRequest{
		Symbol:         symbol,
		HistoricalData: lastData,
		RequestTime:    time.Now(),
	}
	
	// Make prediction with timeout
	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
	defer cancel()
	
	prediction, err := h.predictionService.PredictStock(ctx, predReq)
	if err != nil {
		h.logger.WithError(err).Error("Prediction failed")
		h.writeErrorResponse(w, http.StatusInternalServerError, "Prediction failed")
		h.metrics.RecordAPIRequest(time.Since(start).Seconds(), false)
		return
	}
	
	// Write response
	h.writeJSONResponse(w, http.StatusOK, prediction)
	h.metrics.RecordAPIRequest(time.Since(start).Seconds(), true)
	
	h.logger.WithFields(logrus.Fields{
		"symbol":          symbol,
		"predicted_price": prediction.PredictedPrice,
		"signal":          prediction.TradingSignal,
		"duration":        time.Since(start),
	}).Info("Prediction request completed")
}

// HealthHandler handles health check requests
func (h *Handler) HealthHandler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	
	status := &models.HealthStatus{
		Status:    "healthy",
		Timestamp: time.Now(),
		Version:   "v3.3.0",
		Services:  make(map[string]string),
	}
	
	// Check Yahoo Finance API
	if err := h.yahooClient.HealthCheck(); err != nil {
		status.Services["yahoo_api"] = fmt.Sprintf("unhealthy: %v", err)
		status.Status = "degraded"
	} else {
		status.Services["yahoo_api"] = "healthy"
	}
	
	// Check prediction service
	if err := h.predictionService.HealthCheck(); err != nil {
		status.Services["prediction_service"] = fmt.Sprintf("unhealthy: %v", err)
		status.Status = "unhealthy"
	} else {
		status.Services["prediction_service"] = "healthy"
	}
	
	// Set HTTP status based on health
	httpStatus := http.StatusOK
	if status.Status == "unhealthy" {
		httpStatus = http.StatusServiceUnavailable
	} else if status.Status == "degraded" {
		httpStatus = http.StatusPartialContent
	}
	
	h.writeJSONResponse(w, httpStatus, status)
	h.metrics.RecordAPIRequest(time.Since(start).Seconds(), httpStatus == http.StatusOK)
}

// StatsHandler handles statistics requests
func (h *Handler) StatsHandler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	
	stats := map[string]interface{}{
		"cache":  h.predictionService.GetCacheStats(),
		"model":  h.predictionService.GetModelInfo(),
		"system": h.getSystemStats(),
	}
	
	h.writeJSONResponse(w, http.StatusOK, stats)
	h.metrics.RecordAPIRequest(time.Since(start).Seconds(), true)
}

// ClearCacheHandler handles cache clearing requests
func (h *Handler) ClearCacheHandler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	
	if r.Method != http.MethodPost {
		h.writeErrorResponse(w, http.StatusMethodNotAllowed, "Method not allowed")
		h.metrics.RecordAPIRequest(time.Since(start).Seconds(), false)
		return
	}
	
	h.predictionService.ClearCache()
	
	response := map[string]string{
		"message": "Cache cleared successfully",
		"time":    time.Now().Format(time.RFC3339),
	}
	
	h.writeJSONResponse(w, http.StatusOK, response)
	h.metrics.RecordAPIRequest(time.Since(start).Seconds(), true)
	
	h.logger.Info("Cache cleared via API request")
}

// HistoricalDataHandler handles historical data requests
func (h *Handler) HistoricalDataHandler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	
	vars := mux.Vars(r)
	symbol := vars["symbol"]
	
	if symbol == "" {
		h.writeErrorResponse(w, http.StatusBadRequest, "symbol is required")
		h.metrics.RecordAPIRequest(time.Since(start).Seconds(), false)
		return
	}
	
	// Get days from query parameter
	days := 30 // default
	if daysStr := r.URL.Query().Get("days"); daysStr != "" {
		if parsed, err := strconv.Atoi(daysStr); err == nil && parsed > 0 && parsed <= 730 {
			days = parsed
		}
	}
	
	// Fetch historical data
	data, err := h.yahooClient.FetchHistoricalData(symbol, days)
	if err != nil {
		h.logger.WithError(err).Error("Failed to fetch historical data")
		h.writeErrorResponse(w, http.StatusServiceUnavailable, "Failed to fetch historical data")
		h.metrics.RecordAPIRequest(time.Since(start).Seconds(), false)
		return
	}
	
	response := map[string]interface{}{
		"symbol": symbol,
		"days":   days,
		"data":   data,
		"count":  len(data),
	}
	
	h.writeJSONResponse(w, http.StatusOK, response)
	h.metrics.RecordAPIRequest(time.Since(start).Seconds(), true)
}

// Helper methods

func (h *Handler) writeJSONResponse(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	
	if err := json.NewEncoder(w).Encode(data); err != nil {
		h.logger.WithError(err).Error("Failed to encode JSON response")
	}
}

func (h *Handler) writeErrorResponse(w http.ResponseWriter, status int, message string) {
	errorResp := map[string]interface{}{
		"error":     message,
		"status":    status,
		"timestamp": time.Now().Format(time.RFC3339),
	}
	
	h.writeJSONResponse(w, status, errorResp)
}

func (h *Handler) getPeriodFromDays(days int) string {
	switch {
	case days <= 7:
		return "7d"
	case days <= 30:
		return "1mo"
	case days <= 90:
		return "3mo"
	case days <= 180:
		return "6mo"
	case days <= 365:
		return "1y"
	default:
		return "2y"
	}
}

func (h *Handler) getSystemStats() map[string]interface{} {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	
	return map[string]interface{}{
		"goroutines":     runtime.NumGoroutine(),
		"memory_alloc":   m.Alloc,
		"memory_total":   m.TotalAlloc,
		"memory_sys":     m.Sys,
		"gc_runs":        m.NumGC,
		"uptime_seconds": time.Since(time.Now()).Seconds(), // This would be set at startup
	}
}

// Middleware

// LoggingMiddleware logs HTTP requests
func (h *Handler) LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		
		// Create a response writer wrapper to capture status code
		wrapper := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}
		
		next.ServeHTTP(wrapper, r)
		
		h.logger.WithFields(logrus.Fields{
			"method":     r.Method,
			"path":       r.URL.Path,
			"status":     wrapper.statusCode,
			"duration":   time.Since(start),
			"client_ip":  r.RemoteAddr,
			"user_agent": r.Header.Get("User-Agent"),
		}).Info("HTTP request")
	})
}

// CORSMiddleware handles CORS headers with comprehensive support
func (h *Handler) CORSMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Allow all origins for development and dynamic hostname support
		origin := r.Header.Get("Origin")
		if origin != "" {
			w.Header().Set("Access-Control-Allow-Origin", origin)
		} else {
			w.Header().Set("Access-Control-Allow-Origin", "*")
		}
		
		// Allow credentials for authenticated requests
		w.Header().Set("Access-Control-Allow-Credentials", "true")
		
		// Allow common HTTP methods
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS, PATCH")
		
		// Allow common headers including those used by Angular HttpClient
		w.Header().Set("Access-Control-Allow-Headers", "Accept, Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, X-Requested-With, Origin")
		
		// Allow exposure of custom headers
		w.Header().Set("Access-Control-Expose-Headers", "Content-Length, Content-Type")
		
		// Set max age for preflight requests
		w.Header().Set("Access-Control-Max-Age", "86400") // 24 hours
		
		// Handle preflight OPTIONS requests for ALL paths
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		
		next.ServeHTTP(w, r)
	})
}

// OptionsHandler handles all OPTIONS requests globally
func (h *Handler) OptionsHandler(w http.ResponseWriter, r *http.Request) {
	// Set CORS headers
	origin := r.Header.Get("Origin")
	if origin != "" {
		w.Header().Set("Access-Control-Allow-Origin", origin)
	} else {
		w.Header().Set("Access-Control-Allow-Origin", "*")
	}
	
	w.Header().Set("Access-Control-Allow-Credentials", "true")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS, PATCH")
	w.Header().Set("Access-Control-Allow-Headers", "Accept, Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, X-Requested-With, Origin")
	w.Header().Set("Access-Control-Expose-Headers", "Content-Length, Content-Type")
	w.Header().Set("Access-Control-Max-Age", "86400")
	
	w.WriteHeader(http.StatusOK)
}

// responseWriter wraps http.ResponseWriter to capture status code
type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}
