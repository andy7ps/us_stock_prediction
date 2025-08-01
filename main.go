package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"syscall"
	"time"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/sirupsen/logrus"

	"stock-prediction-v3/internal/config"
	"stock-prediction-v3/internal/handlers"
	"stock-prediction-v3/internal/metrics"
	"stock-prediction-v3/internal/services/cache"
	"stock-prediction-v3/internal/services/prediction"
	"stock-prediction-v3/internal/services/yahoo"
)

func main() {
	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		fmt.Printf("Failed to load configuration: %v\n", err)
		os.Exit(1)
	}

	// Setup logger
	logger := setupLogger(cfg)
	logger.Info("Starting Stock Prediction Service v3.1.0")

	// Initialize metrics
	metricsCollector := metrics.NewMetrics()

	// Initialize services
	yahooClient := yahoo.NewClient(cfg, logger, metricsCollector)
	predictionCache := cache.NewPredictionCache(cfg.ML.PredictionTTL, metricsCollector)
	predictionService := prediction.NewService(cfg, logger, metricsCollector, predictionCache)

	// Initialize handlers
	handler := handlers.NewHandler(cfg, logger, metricsCollector, yahooClient, predictionService)

	// Setup router
	router := setupRouter(handler)

	// Create HTTP server
	server := &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.Server.Port),
		Handler:      router,
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
	}

	// Start system monitoring
	go startSystemMonitoring(metricsCollector, logger)

	// Start server in a goroutine
	go func() {
		logger.WithField("port", cfg.Server.Port).Info("Starting HTTP server")
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.WithError(err).Fatal("Failed to start server")
		}
	}()

	// Wait for interrupt signal to gracefully shutdown the server
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("Shutting down server...")

	// Create a deadline for shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Attempt graceful shutdown
	if err := server.Shutdown(ctx); err != nil {
		logger.WithError(err).Error("Server forced to shutdown")
	} else {
		logger.Info("Server shutdown complete")
	}
}

func setupLogger(cfg *config.Config) *logrus.Logger {
	logger := logrus.New()

	// Set log level
	level, err := logrus.ParseLevel(cfg.Logging.Level)
	if err != nil {
		level = logrus.InfoLevel
	}
	logger.SetLevel(level)

	// Set log format
	if cfg.Logging.Format == "json" {
		logger.SetFormatter(&logrus.JSONFormatter{
			TimestampFormat: time.RFC3339,
		})
	} else {
		logger.SetFormatter(&logrus.TextFormatter{
			FullTimestamp:   true,
			TimestampFormat: time.RFC3339,
		})
	}

	return logger
}

func setupRouter(handler *handlers.Handler) *mux.Router {
	router := mux.NewRouter()

	// Add middleware
	router.Use(handler.LoggingMiddleware)
	router.Use(handler.CORSMiddleware)

	// API routes
	api := router.PathPrefix("/api/v1").Subrouter()
	
	// Prediction endpoints
	api.HandleFunc("/predict/{symbol}", handler.PredictHandler).Methods("GET")
	api.HandleFunc("/historical/{symbol}", handler.HistoricalDataHandler).Methods("GET")
	
	// Management endpoints
	api.HandleFunc("/health", handler.HealthHandler).Methods("GET")
	api.HandleFunc("/stats", handler.StatsHandler).Methods("GET")
	api.HandleFunc("/cache/clear", handler.ClearCacheHandler).Methods("POST")

	// Metrics endpoint for Prometheus
	router.Handle("/metrics", promhttp.Handler())

	// Root endpoint
	router.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		response := map[string]interface{}{
			"service": "Stock Prediction API",
			"version": "v3.1.0",
			"status":  "running",
			"time":    time.Now().Format(time.RFC3339),
			"endpoints": map[string]string{
				"predict":     "/api/v1/predict/{symbol}",
				"historical":  "/api/v1/historical/{symbol}",
				"health":      "/api/v1/health",
				"stats":       "/api/v1/stats",
				"clear_cache": "/api/v1/cache/clear",
				"metrics":     "/metrics",
			},
		}
		
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		
		if err := json.NewEncoder(w).Encode(response); err != nil {
			http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		}
	}).Methods("GET")

	return router
}

func startSystemMonitoring(metrics *metrics.Metrics, logger *logrus.Logger) {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		updateSystemMetrics(metrics, logger)
	}
}

func updateSystemMetrics(metrics *metrics.Metrics, logger *logrus.Logger) {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	// Update memory metrics
	metrics.UpdateSystemMetrics(int64(m.Alloc), 0) // CPU usage would need additional implementation

	// Log system stats periodically (every 5 minutes)
	if time.Now().Minute()%5 == 0 && time.Now().Second() < 30 {
		logger.WithFields(logrus.Fields{
			"memory_alloc": m.Alloc,
			"memory_sys":   m.Sys,
			"goroutines":   runtime.NumGoroutine(),
			"gc_runs":      m.NumGC,
		}).Debug("System metrics")
	}
}
