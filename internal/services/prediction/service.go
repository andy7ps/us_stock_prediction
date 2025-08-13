package prediction

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"github.com/sirupsen/logrus"

	"stock-prediction-v3/internal/config"
	"stock-prediction-v3/internal/metrics"
	"stock-prediction-v3/internal/models"
	"stock-prediction-v3/internal/services/cache"
)

// Service handles stock price predictions
type Service struct {
	config  *config.Config
	logger  *logrus.Logger
	metrics *metrics.Metrics
	cache   *cache.PredictionCache
}

// NewService creates a new prediction service
func NewService(cfg *config.Config, logger *logrus.Logger, metrics *metrics.Metrics, cache *cache.PredictionCache) *Service {
	return &Service{
		config:  cfg,
		logger:  logger,
		metrics: metrics,
		cache:   cache,
	}
}

// PredictStock predicts stock price using ML model
func (s *Service) PredictStock(ctx context.Context, req *models.PredictionRequest) (*models.PredictionResponse, error) {
	start := time.Now()
	
	// Validate request
	if err := req.Validate(); err != nil {
		s.metrics.RecordPrediction(time.Since(start).Seconds(), false)
		return nil, fmt.Errorf("invalid request: %w", err)
	}
	
	s.logger.WithFields(logrus.Fields{
		"symbol":      req.Symbol,
		"data_points": len(req.HistoricalData),
	}).Info("Processing prediction request")
	
	// Check cache first
	if cached, found := s.cache.Get(req.Symbol, req.HistoricalData); found {
		s.logger.WithField("symbol", req.Symbol).Debug("Returning cached prediction")
		s.metrics.RecordPrediction(time.Since(start).Seconds(), true)
		return cached, nil
	}
	
	// Make prediction
	predictedPrice, err := s.callPythonModel(ctx, req.HistoricalData)
	if err != nil {
		s.metrics.RecordPrediction(time.Since(start).Seconds(), false)
		return nil, fmt.Errorf("prediction failed: %w", err)
	}
	
	// Get current price (last data point)
	currentPrice := req.HistoricalData[len(req.HistoricalData)-1]
	
	// Generate trading signal
	signal := models.GenerateTradingSignal(
		currentPrice, 
		predictedPrice, 
		s.config.Stock.BuyThreshold, 
		s.config.Stock.SellThreshold,
	)
	
	// Use historical data directly for advanced confidence calculation
	// req.HistoricalData is already []float64
	confidence := models.CalculateAdvancedConfidence(currentPrice, predictedPrice, req.HistoricalData)
	
	// Create response
	response := &models.PredictionResponse{
		Symbol:         req.Symbol,
		CurrentPrice:   currentPrice,
		PredictedPrice: predictedPrice,
		TradingSignal:  string(signal),
		Confidence:     confidence,
		PredictionTime: time.Now(),
		ModelVersion:   "v3.3.0", // This could be dynamic based on actual model version
	}
	
	// Cache the result
	s.cache.Set(req.Symbol, req.HistoricalData, response)
	
	s.logger.WithFields(logrus.Fields{
		"symbol":          req.Symbol,
		"current_price":   currentPrice,
		"predicted_price": predictedPrice,
		"signal":          signal,
		"confidence":      confidence,
		"duration":        time.Since(start),
	}).Info("Prediction completed")
	
	s.metrics.RecordPrediction(time.Since(start).Seconds(), true)
	return response, nil
}

// callPythonModel executes the Python ML model
func (s *Service) callPythonModel(ctx context.Context, prices []float64) (float64, error) {
	// Convert prices to comma-separated string
	priceStrs := make([]string, len(prices))
	for i, price := range prices {
		priceStrs[i] = fmt.Sprintf("%.2f", price)
	}
	inputString := strings.Join(priceStrs, ",")
	
	s.logger.WithFields(logrus.Fields{
		"script": s.config.ML.PythonScript,
		"input":  inputString,
	}).Debug("Calling Python model")
	
	// Create command with context for timeout
	// Use virtual environment Python interpreter
	venvPython := "venv/bin/python3"
	if _, err := os.Stat(venvPython); os.IsNotExist(err) {
		// Fallback to system python if venv doesn't exist
		venvPython = "python3"
	}
	cmd := exec.CommandContext(ctx, venvPython, s.config.ML.PythonScript, inputString)
	
	// Set working directory to project root to ensure model files are found
	// Note: ModelPath is a file path, not a directory path
	// cmd.Dir should be set to the project root, not the model file path
	
	// Capture both stdout and stderr
	output, err := cmd.CombinedOutput()
	if err != nil {
		s.logger.WithFields(logrus.Fields{
			"error":  err,
			"output": string(output),
		}).Error("Python model execution failed")
		return 0, fmt.Errorf("model execution failed: %w, output: %s", err, string(output))
	}
	
	// Parse output
	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	if len(lines) == 0 {
		return 0, fmt.Errorf("no output from Python model")
	}
	
	// Get the last non-empty line (predicted price)
	var predictedPriceStr string
	for i := len(lines) - 1; i >= 0; i-- {
		if strings.TrimSpace(lines[i]) != "" {
			predictedPriceStr = strings.TrimSpace(lines[i])
			break
		}
	}
	
	if predictedPriceStr == "" {
		return 0, fmt.Errorf("empty prediction output")
	}
	
	// Parse predicted price
	predictedPrice, err := strconv.ParseFloat(predictedPriceStr, 64)
	if err != nil {
		return 0, fmt.Errorf("failed to parse prediction output '%s': %w", predictedPriceStr, err)
	}
	
	// Validate predicted price
	if predictedPrice <= 0 {
		return 0, fmt.Errorf("invalid predicted price: %f", predictedPrice)
	}
	
	s.logger.WithField("predicted_price", predictedPrice).Debug("Python model prediction successful")
	return predictedPrice, nil
}

// HealthCheck checks if the prediction service is healthy
func (s *Service) HealthCheck() error {
	// Check if Python script exists
	if _, err := os.Stat(s.config.ML.PythonScript); os.IsNotExist(err) {
		return fmt.Errorf("Python script not found: %s", s.config.ML.PythonScript)
	}
	
	// Check if model files exist
	if _, err := os.Stat(s.config.ML.ModelPath); os.IsNotExist(err) {
		return fmt.Errorf("model path not found: %s", s.config.ML.ModelPath)
	}
	
	if _, err := os.Stat(s.config.ML.ScalerPath); os.IsNotExist(err) {
		return fmt.Errorf("scaler file not found: %s", s.config.ML.ScalerPath)
	}
	
	// Test with dummy data
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	
	testData := []float64{100.0, 101.0, 102.0, 103.0, 104.0}
	_, err := s.callPythonModel(ctx, testData)
	if err != nil {
		return fmt.Errorf("model health check failed: %w", err)
	}
	
	return nil
}

// GetModelInfo returns information about the current model
func (s *Service) GetModelInfo() map[string]interface{} {
	info := map[string]interface{}{
		"model_path":    s.config.ML.ModelPath,
		"scaler_path":   s.config.ML.ScalerPath,
		"python_script": s.config.ML.PythonScript,
		"version":       "v3.3.0",
	}
	
	// Check if files exist
	if _, err := os.Stat(s.config.ML.ModelPath); err == nil {
		if stat, err := os.Stat(s.config.ML.ModelPath); err == nil {
			info["model_modified"] = stat.ModTime()
		}
	}
	
	if _, err := os.Stat(s.config.ML.ScalerPath); err == nil {
		if stat, err := os.Stat(s.config.ML.ScalerPath); err == nil {
			info["scaler_modified"] = stat.ModTime()
		}
	}
	
	return info
}

// ClearCache clears the prediction cache
func (s *Service) ClearCache() {
	s.cache.Clear()
	s.logger.Info("Prediction cache cleared")
}

// GetCacheStats returns cache statistics
func (s *Service) GetCacheStats() map[string]interface{} {
	return s.cache.GetStats()
}
