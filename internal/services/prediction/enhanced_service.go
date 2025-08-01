package prediction

import (
	"context"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"stock-prediction-v3/internal/config"
	"stock-prediction-v3/internal/metrics"
	"stock-prediction-v3/internal/models"
	"stock-prediction-v3/internal/services/cache"

	"github.com/sirupsen/logrus"
)

// EnhancedPredictionService provides enhanced prediction capabilities
type EnhancedPredictionService struct {
	*Service // Embed the original service
	predictionConfig *models.PredictionConfig
}

// NewEnhancedPredictionService creates a new enhanced prediction service
func NewEnhancedPredictionService(
	config *config.Config,
	logger *logrus.Logger,
	metrics *metrics.Metrics,
	cache *cache.PredictionCache,
) *EnhancedPredictionService {
	
	// Create base service
	baseService := NewService(config, logger, metrics, cache)
	
	// Create prediction configuration from config
	predictionConfig := &models.PredictionConfig{
		Model:         models.PredictionModel(config.ML.Model),
		UseOHLCVData:  config.ML.UseOHLCVData,
		MaxDataPoints: config.ML.MaxDataPoints,
		MinDataPoints: config.ML.MinDataPoints,
		EnableEnsemble: config.ML.EnableEnsemble,
		DebugMode:     config.ML.DebugMode,
	}
	
	// Validate configuration
	if err := predictionConfig.Validate(); err != nil {
		logger.WithError(err).Warn("Invalid prediction configuration, using defaults")
		predictionConfig = models.DefaultPredictionConfig()
	}
	
	return &EnhancedPredictionService{
		Service:          baseService,
		predictionConfig: predictionConfig,
	}
}

// Predict makes an enhanced prediction using the configured model
func (s *EnhancedPredictionService) Predict(ctx context.Context, req *models.PredictionRequest) (*models.PredictionResponse, error) {
	start := time.Now()
	
	// Validate request
	if err := req.Validate(); err != nil {
		s.metrics.RecordPrediction(time.Since(start).Seconds(), false)
		return nil, fmt.Errorf("invalid request: %w", err)
	}
	
	s.logger.WithFields(logrus.Fields{
		"symbol":      req.Symbol,
		"data_points": len(req.HistoricalData),
		"model":       s.predictionConfig.Model,
	}).Info("Processing enhanced prediction request")
	
	// Prepare historical data based on model requirements
	processedData := s.prepareHistoricalData(req.HistoricalData)
	
	// Check cache first (with model-specific key)
	cacheKey := fmt.Sprintf("%s_%s", req.Symbol, s.predictionConfig.Model)
	if cached, found := s.cache.Get(cacheKey, processedData); found {
		s.logger.WithFields(logrus.Fields{
			"symbol": req.Symbol,
			"model":  s.predictionConfig.Model,
		}).Debug("Returning cached enhanced prediction")
		s.metrics.RecordPrediction(time.Since(start).Seconds(), true)
		return cached, nil
	}
	
	// Make prediction using the configured model
	predictedPrice, err := s.callEnhancedModel(ctx, processedData)
	if err != nil {
		s.metrics.RecordPrediction(time.Since(start).Seconds(), false)
		return nil, fmt.Errorf("enhanced prediction failed: %w", err)
	}
	
	// Get current price (last data point)
	currentPrice := processedData[len(processedData)-1]
	
	// Generate trading signal
	signal := models.GenerateTradingSignal(
		currentPrice, 
		predictedPrice, 
		s.config.Stock.BuyThreshold, 
		s.config.Stock.SellThreshold,
	)
	
	// Calculate advanced confidence using historical data
	confidence := models.CalculateAdvancedConfidence(currentPrice, predictedPrice, processedData)
	
	// Create response
	response := &models.PredictionResponse{
		Symbol:         req.Symbol,
		CurrentPrice:   currentPrice,
		PredictedPrice: predictedPrice,
		TradingSignal:  string(signal),
		Confidence:     confidence,
		PredictionTime: time.Now(),
		ModelVersion:   fmt.Sprintf("v3.1.0-%s", s.predictionConfig.Model),
	}
	
	// Cache the result
	s.cache.Set(cacheKey, processedData, response)
	
	// Log prediction details
	s.logger.WithFields(logrus.Fields{
		"symbol":          req.Symbol,
		"model":           s.predictionConfig.Model,
		"current_price":   currentPrice,
		"predicted_price": predictedPrice,
		"signal":          signal,
		"confidence":      confidence,
		"duration":        time.Since(start),
	}).Info("Enhanced prediction completed")
	
	s.metrics.RecordPrediction(time.Since(start).Seconds(), true)
	return response, nil
}

// prepareHistoricalData prepares historical data based on model requirements
func (s *EnhancedPredictionService) prepareHistoricalData(data []float64) []float64 {
	// Apply data point limits
	maxPoints := s.predictionConfig.MaxDataPoints
	if len(data) > maxPoints {
		data = data[len(data)-maxPoints:]
	}
	
	// Ensure minimum data points
	if len(data) < s.predictionConfig.MinDataPoints {
		s.logger.WithFields(logrus.Fields{
			"available": len(data),
			"required":  s.predictionConfig.MinDataPoints,
		}).Warn("Insufficient historical data for optimal prediction")
	}
	
	return data
}

// callEnhancedModel calls the appropriate prediction model
func (s *EnhancedPredictionService) callEnhancedModel(ctx context.Context, data []float64) (float64, error) {
	scriptPath := s.predictionConfig.GetScriptPath()
	
	// Prepare input data
	priceStrings := make([]string, len(data))
	for i, price := range data {
		priceStrings[i] = fmt.Sprintf("%.2f", price)
	}
	inputData := strings.Join(priceStrings, ",")
	
	// Create command
	cmd := exec.CommandContext(ctx, "python3", scriptPath, inputData)
	
	// Set environment variables for debugging if enabled
	if s.predictionConfig.DebugMode {
		cmd.Env = append(cmd.Env, "DEBUG=1")
	}
	
	s.logger.WithFields(logrus.Fields{
		"script":      scriptPath,
		"model":       s.predictionConfig.Model,
		"data_points": len(data),
	}).Debug("Calling enhanced prediction model")
	
	// Execute command
	output, err := cmd.Output()
	if err != nil {
		if exitError, ok := err.(*exec.ExitError); ok {
			return 0, fmt.Errorf("model execution failed: %s", string(exitError.Stderr))
		}
		return 0, fmt.Errorf("failed to execute model: %w", err)
	}
	
	// Parse output
	outputStr := strings.TrimSpace(string(output))
	predictedPrice, err := strconv.ParseFloat(outputStr, 64)
	if err != nil {
		return 0, fmt.Errorf("failed to parse prediction output '%s': %w", outputStr, err)
	}
	
	if predictedPrice <= 0 {
		return 0, fmt.Errorf("invalid prediction: %f", predictedPrice)
	}
	
	return predictedPrice, nil
}

// GetModelInfo returns information about the current prediction model
func (s *EnhancedPredictionService) GetModelInfo() *models.ModelInfo {
	return &models.ModelInfo{
		Name:        string(s.predictionConfig.Model),
		Version:     fmt.Sprintf("v3.1.0-%s", s.predictionConfig.Model),
		Description: s.predictionConfig.Model.GetModelDescription(),
		Features:    s.predictionConfig.Model.GetModelFeatures(),
		Config: map[string]interface{}{
			"use_ohlcv_data":   s.predictionConfig.UseOHLCVData,
			"max_data_points":  s.predictionConfig.MaxDataPoints,
			"min_data_points":  s.predictionConfig.MinDataPoints,
			"enable_ensemble":  s.predictionConfig.EnableEnsemble,
			"debug_mode":       s.predictionConfig.DebugMode,
		},
	}
}

// SwitchModel dynamically switches the prediction model
func (s *EnhancedPredictionService) SwitchModel(model models.PredictionModel) error {
	// Validate the new model
	newConfig := &models.PredictionConfig{
		Model:         model,
		UseOHLCVData:  s.predictionConfig.UseOHLCVData,
		MaxDataPoints: s.predictionConfig.MaxDataPoints,
		MinDataPoints: s.predictionConfig.MinDataPoints,
		EnableEnsemble: s.predictionConfig.EnableEnsemble,
		DebugMode:     s.predictionConfig.DebugMode,
	}
	
	if err := newConfig.Validate(); err != nil {
		return fmt.Errorf("invalid model configuration: %w", err)
	}
	
	// Update configuration
	s.predictionConfig = newConfig
	
	s.logger.WithField("model", model).Info("Switched prediction model")
	return nil
}
