package config

import (
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/joho/godotenv"
)

type Config struct {
	Server struct {
		Port         int           `json:"port"`
		ReadTimeout  time.Duration `json:"read_timeout"`
		WriteTimeout time.Duration `json:"write_timeout"`
	} `json:"server"`

	Stock struct {
		Symbol          string  `json:"symbol"`
		LookbackDays    int     `json:"lookback_days"`
		BuyThreshold    float64 `json:"buy_threshold"`
		SellThreshold   float64 `json:"sell_threshold"`
		MaxRetries      int     `json:"max_retries"`
		RequestsPerSec  int     `json:"requests_per_sec"`
	} `json:"stock"`

	API struct {
		Timeout     time.Duration `json:"timeout"`
		UserAgent   string        `json:"user_agent"`
		BaseURL     string        `json:"base_url"`
	} `json:"api"`

	ML struct {
		PythonScript    string        `json:"python_script"`
		ModelPath       string        `json:"model_path"`
		ScalerPath      string        `json:"scaler_path"`
		PredictionTTL   time.Duration `json:"prediction_ttl"`
		// New prediction model configuration
		Model           string `json:"model"`           // simple, enhanced, advanced
		UseOHLCVData    bool   `json:"use_ohlcv_data"`  // Use full OHLCV data instead of just close prices
		MaxDataPoints   int    `json:"max_data_points"` // Maximum historical data points to use
		MinDataPoints   int    `json:"min_data_points"` // Minimum historical data points required
		EnableEnsemble  bool   `json:"enable_ensemble"` // Enable ensemble prediction
		DebugMode       bool   `json:"debug_mode"`      // Enable debug output
	} `json:"ml"`

	Logging struct {
		Level  string `json:"level"`
		Format string `json:"format"`
	} `json:"logging"`
}

func Load() (*Config, error) {
	// Load .env file if it exists
	_ = godotenv.Load()

	config := &Config{}

	// Set defaults
	config.Server.Port = getEnvInt("SERVER_PORT", 8080)
	config.Server.ReadTimeout = getEnvDuration("SERVER_READ_TIMEOUT", 10*time.Second)
	config.Server.WriteTimeout = getEnvDuration("SERVER_WRITE_TIMEOUT", 10*time.Second)

	config.Stock.Symbol = getEnvString("STOCK_SYMBOL", "NVDA")
	config.Stock.LookbackDays = getEnvInt("STOCK_LOOKBACK_DAYS", 5)
	config.Stock.BuyThreshold = getEnvFloat("STOCK_BUY_THRESHOLD", 1.01)
	config.Stock.SellThreshold = getEnvFloat("STOCK_SELL_THRESHOLD", 0.99)
	config.Stock.MaxRetries = getEnvInt("STOCK_MAX_RETRIES", 3)
	config.Stock.RequestsPerSec = getEnvInt("STOCK_REQUESTS_PER_SEC", 10)

	config.API.Timeout = getEnvDuration("API_TIMEOUT", 30*time.Second)
	config.API.UserAgent = getEnvString("API_USER_AGENT", "StockPredictor/3.0")
	config.API.BaseURL = getEnvString("API_BASE_URL", "https://query1.finance.yahoo.com")

	config.ML.PythonScript = getEnvString("ML_PYTHON_SCRIPT", "scripts/ml/predict.py")
	config.ML.ModelPath = getEnvString("ML_MODEL_PATH", "models/nvda_lstm_model")
	config.ML.ScalerPath = getEnvString("ML_SCALER_PATH", "models/scaler.pkl")
	config.ML.PredictionTTL = getEnvDuration("ML_PREDICTION_TTL", 5*time.Minute)
	config.ML.Model = getEnvString("ML_MODEL", "simple")
	config.ML.UseOHLCVData = getEnvBool("ML_USE_OHLCV_DATA", false)
	config.ML.MaxDataPoints = getEnvInt("ML_MAX_DATA_POINTS", 30)
	config.ML.MinDataPoints = getEnvInt("ML_MIN_DATA_POINTS", 5)
	config.ML.EnableEnsemble = getEnvBool("ML_ENABLE_ENSEMBLE", false)
	config.ML.DebugMode = getEnvBool("ML_DEBUG_MODE", false)

	config.Logging.Level = getEnvString("LOG_LEVEL", "info")
	config.Logging.Format = getEnvString("LOG_FORMAT", "json")

	// Load from config file if specified
	if configFile := os.Getenv("CONFIG_FILE"); configFile != "" {
		if err := loadFromFile(config, configFile); err != nil {
			return nil, fmt.Errorf("failed to load config file: %w", err)
		}
	}

	return config, nil
}

func loadFromFile(config *Config, filename string) error {
	file, err := os.Open(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	decoder := json.NewDecoder(file)
	return decoder.Decode(config)
}

func getEnvString(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}

func getEnvFloat(key string, defaultValue float64) float64 {
	if value := os.Getenv(key); value != "" {
		if floatValue, err := strconv.ParseFloat(value, 64); err == nil {
			return floatValue
		}
	}
	return defaultValue
}

func getEnvBool(key string, defaultValue bool) bool {
	if value := os.Getenv(key); value != "" {
		if boolValue, err := strconv.ParseBool(value); err == nil {
			return boolValue
		}
	}
	return defaultValue
}

func getEnvDuration(key string, defaultValue time.Duration) time.Duration {
	if value := os.Getenv(key); value != "" {
		if duration, err := time.ParseDuration(value); err == nil {
			return duration
		}
	}
	return defaultValue
}
