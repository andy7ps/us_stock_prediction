package models

import (
	"fmt"
	"strings"
)

// PredictionModel represents different prediction algorithms
type PredictionModel string

const (
	ModelSimple   PredictionModel = "simple"
	ModelEnhanced PredictionModel = "enhanced"
	ModelAdvanced PredictionModel = "advanced"
)

// PredictionConfig holds configuration for prediction models
type PredictionConfig struct {
	Model           PredictionModel `json:"model" yaml:"model"`
	ScriptPath      string          `json:"script_path" yaml:"script_path"`
	UseOHLCVData    bool            `json:"use_ohlcv_data" yaml:"use_ohlcv_data"`
	MaxDataPoints   int             `json:"max_data_points" yaml:"max_data_points"`
	MinDataPoints   int             `json:"min_data_points" yaml:"min_data_points"`
	EnableEnsemble  bool            `json:"enable_ensemble" yaml:"enable_ensemble"`
	DebugMode       bool            `json:"debug_mode" yaml:"debug_mode"`
}

// DefaultPredictionConfig returns default configuration
func DefaultPredictionConfig() *PredictionConfig {
	return &PredictionConfig{
		Model:         ModelSimple,
		ScriptPath:    "scripts/ml/predict.py",
		UseOHLCVData:  false,
		MaxDataPoints: 30,
		MinDataPoints: 5,
		EnableEnsemble: false,
		DebugMode:     false,
	}
}

// GetScriptPath returns the appropriate script path for the model
func (pc *PredictionConfig) GetScriptPath() string {
	if pc.ScriptPath != "" {
		return pc.ScriptPath
	}
	
	switch pc.Model {
	case ModelEnhanced:
		return "scripts/ml/enhanced_predict.py"
	case ModelAdvanced:
		return "scripts/ml/advanced_predict.py"
	default:
		return "scripts/ml/predict.py"
	}
}

// Validate validates the prediction configuration
func (pc *PredictionConfig) Validate() error {
	if pc.Model == "" {
		return fmt.Errorf("prediction model cannot be empty")
	}
	
	validModels := []PredictionModel{ModelSimple, ModelEnhanced, ModelAdvanced}
	isValid := false
	for _, model := range validModels {
		if pc.Model == model {
			isValid = true
			break
		}
	}
	
	if !isValid {
		return fmt.Errorf("invalid prediction model: %s, valid options: %v", pc.Model, validModels)
	}
	
	if pc.MaxDataPoints < pc.MinDataPoints {
		return fmt.Errorf("max_data_points (%d) cannot be less than min_data_points (%d)", 
			pc.MaxDataPoints, pc.MinDataPoints)
	}
	
	if pc.MinDataPoints < 1 {
		return fmt.Errorf("min_data_points must be at least 1")
	}
	
	return nil
}

// String returns string representation of the model
func (pm PredictionModel) String() string {
	return string(pm)
}

// ParsePredictionModel parses string to PredictionModel
func ParsePredictionModel(s string) (PredictionModel, error) {
	switch strings.ToLower(s) {
	case "simple":
		return ModelSimple, nil
	case "enhanced":
		return ModelEnhanced, nil
	case "advanced":
		return ModelAdvanced, nil
	default:
		return "", fmt.Errorf("unknown prediction model: %s", s)
	}
}

// GetModelDescription returns description of the prediction model
func (pm PredictionModel) GetModelDescription() string {
	switch pm {
	case ModelSimple:
		return "Simple linear regression with basic trend analysis"
	case ModelEnhanced:
		return "Enhanced prediction with technical indicators (RSI, MACD, Bollinger Bands)"
	case ModelAdvanced:
		return "Advanced prediction using full OHLCV data with support/resistance analysis"
	default:
		return "Unknown model"
	}
}

// GetModelFeatures returns list of features for the prediction model
func (pm PredictionModel) GetModelFeatures() []string {
	switch pm {
	case ModelSimple:
		return []string{
			"Linear regression",
			"Basic trend analysis",
			"Price change limits",
			"Deterministic noise",
		}
	case ModelEnhanced:
		return []string{
			"Multiple prediction algorithms",
			"Technical indicators (SMA, EMA, RSI, MACD, Bollinger Bands)",
			"Ensemble prediction",
			"Volatility-based bounds",
			"Trend strength analysis",
		}
	case ModelAdvanced:
		return []string{
			"Full OHLCV data utilization",
			"Support/resistance analysis",
			"Volume-price analysis",
			"Volatility breakout detection",
			"Multi-timeframe analysis",
			"Advanced technical indicators (ATR, Stochastic, OBV)",
			"Dynamic bounds based on ATR",
		}
	default:
		return []string{}
	}
}

// RequiresOHLCVData returns true if the model requires full OHLCV data
func (pm PredictionModel) RequiresOHLCVData() bool {
	return pm == ModelAdvanced
}

// GetRecommendedDataPoints returns recommended number of data points for the model
func (pm PredictionModel) GetRecommendedDataPoints() (min, max int) {
	switch pm {
	case ModelSimple:
		return 5, 15
	case ModelEnhanced:
		return 10, 25
	case ModelAdvanced:
		return 15, 40
	default:
		return 5, 20
	}
}
