package models

import (
	"time"
)

// PredictionTracking represents a tracked prediction with accuracy data
type PredictionTracking struct {
	ID                    int       `json:"id" db:"id"`
	Symbol                string    `json:"symbol" db:"symbol"`
	PredictionDate        time.Time `json:"prediction_date" db:"prediction_date"`
	PredictedPrice        *float64  `json:"predicted_price" db:"predicted_price"`
	PredictedDirection    *string   `json:"predicted_direction" db:"predicted_direction"`
	Confidence            *float64  `json:"confidence" db:"confidence"`
	ActualClose           *float64  `json:"actual_close" db:"actual_close"`
	AccuracyMAPE          *float64  `json:"accuracy_mape" db:"accuracy_mape"`
	DirectionCorrect      *bool     `json:"direction_correct" db:"direction_correct"`
	MarketWasOpen         bool      `json:"market_was_open" db:"market_was_open"`
	PredictionTimestamp   time.Time `json:"prediction_timestamp" db:"prediction_timestamp"`
	ActualPriceTimestamp  *time.Time `json:"actual_price_timestamp" db:"actual_price_timestamp"`
	CreatedAt             time.Time `json:"created_at" db:"created_at"`
	UpdatedAt             time.Time `json:"updated_at" db:"updated_at"`
}

// MarketCalendar represents market open/close information
type MarketCalendar struct {
	ID           int       `json:"id" db:"id"`
	Date         time.Time `json:"date" db:"date"`
	IsMarketOpen bool      `json:"is_market_open" db:"is_market_open"`
	HolidayName  *string   `json:"holiday_name" db:"holiday_name"`
	MarketType   string    `json:"market_type" db:"market_type"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

// DailyExecutionLog represents a daily prediction execution log
type DailyExecutionLog struct {
	ID                    int       `json:"id" db:"id"`
	ExecutionDate         time.Time `json:"execution_date" db:"execution_date"`
	ExecutionType         string    `json:"execution_type" db:"execution_type"` // 'auto', 'manual'
	SymbolsProcessed      *string   `json:"symbols_processed" db:"symbols_processed"` // JSON array
	SymbolsSucceeded      *string   `json:"symbols_succeeded" db:"symbols_succeeded"` // JSON array
	SymbolsFailed         *string   `json:"symbols_failed" db:"symbols_failed"`       // JSON array
	TotalSymbols          int       `json:"total_symbols" db:"total_symbols"`
	SuccessfulPredictions int       `json:"successful_predictions" db:"successful_predictions"`
	FailedPredictions     int       `json:"failed_predictions" db:"failed_predictions"`
	ExecutionDurationMs   *int      `json:"execution_duration_ms" db:"execution_duration_ms"`
	ErrorMessage          *string   `json:"error_message" db:"error_message"`
	Status                string    `json:"status" db:"status"` // 'pending', 'running', 'completed', 'failed'
	CreatedAt             time.Time `json:"created_at" db:"created_at"`
	CompletedAt           *time.Time `json:"completed_at" db:"completed_at"`
}

// PredictionAccuracySummary represents accuracy statistics for a symbol
type PredictionAccuracySummary struct {
	Symbol                string  `json:"symbol"`
	TotalPredictions      int     `json:"total_predictions"`
	PredictionsWithActual int     `json:"predictions_with_actual"`
	AverageAccuracyMAPE   float64 `json:"average_accuracy_mape"`
	DirectionAccuracy     float64 `json:"direction_accuracy"`
	AverageConfidence     float64 `json:"average_confidence"`
	BestAccuracy          float64 `json:"best_accuracy"`
	WorstAccuracy         float64 `json:"worst_accuracy"`
	LastPredictionDate    *time.Time `json:"last_prediction_date"`
}

// PredictionPerformanceMetrics represents overall performance metrics
type PredictionPerformanceMetrics struct {
	TotalSymbols          int                         `json:"total_symbols"`
	TotalPredictions      int                         `json:"total_predictions"`
	PredictionsWithActual int                         `json:"predictions_with_actual"`
	OverallAccuracyMAPE   float64                     `json:"overall_accuracy_mape"`
	OverallDirectionAccuracy float64                  `json:"overall_direction_accuracy"`
	SymbolSummaries       []PredictionAccuracySummary `json:"symbol_summaries"`
	LastExecutionDate     *time.Time                  `json:"last_execution_date"`
	LastExecutionStatus   string                      `json:"last_execution_status"`
}

// CreatePredictionRequest represents a request to create a new prediction
type CreatePredictionRequest struct {
	Symbol             string    `json:"symbol" validate:"required"`
	PredictionDate     time.Time `json:"prediction_date" validate:"required"`
	PredictedPrice     *float64  `json:"predicted_price"`
	PredictedDirection *string   `json:"predicted_direction"`
	Confidence         *float64  `json:"confidence"`
	MarketWasOpen      bool      `json:"market_was_open"`
}

// UpdateActualPriceRequest represents a request to update actual closing price
type UpdateActualPriceRequest struct {
	Symbol      string   `json:"symbol" validate:"required"`
	Date        time.Time `json:"date" validate:"required"`
	ActualClose float64  `json:"actual_close" validate:"required"`
}

// DailyPredictionRequest represents a request for daily predictions
type DailyPredictionRequest struct {
	Symbols       []string  `json:"symbols"`       // If empty, use all supported symbols
	Date          *time.Time `json:"date"`          // If nil, use current date
	ForceExecute  bool      `json:"force_execute"` // Execute even if market was closed
	ExecutionType string    `json:"execution_type"` // 'manual' or 'auto'
}

// PredictionHistoryQuery represents query parameters for prediction history
type PredictionHistoryQuery struct {
	Symbol    *string    `json:"symbol"`
	StartDate *time.Time `json:"start_date"`
	EndDate   *time.Time `json:"end_date"`
	Limit     int        `json:"limit"`
	Offset    int        `json:"offset"`
	OrderBy   string     `json:"order_by"` // 'date', 'accuracy', 'confidence'
	OrderDir  string     `json:"order_dir"` // 'asc', 'desc'
}

// AccuracyRangeQuery represents query parameters for accuracy data in a date range
type AccuracyRangeQuery struct {
	Symbols   []string   `json:"symbols"`
	StartDate time.Time  `json:"start_date" validate:"required"`
	EndDate   time.Time  `json:"end_date" validate:"required"`
	GroupBy   string     `json:"group_by"` // 'day', 'week', 'month'
}

// DailyPredictionStatus represents the status of daily prediction execution
type DailyPredictionStatus struct {
	LastExecutionDate   *time.Time `json:"last_execution_date"`
	LastExecutionStatus string     `json:"last_execution_status"`
	NextScheduledRun    *time.Time `json:"next_scheduled_run"`
	IsEnabled           bool       `json:"is_enabled"`
	TotalSymbols        int        `json:"total_symbols"`
	SuccessfulSymbols   int        `json:"successful_symbols"`
	FailedSymbols       int        `json:"failed_symbols"`
	ExecutionDuration   *int       `json:"execution_duration_ms"`
	ErrorMessage        *string    `json:"error_message"`
}

// Constants for prediction directions
const (
	DirectionUp   = "up"
	DirectionDown = "down"
	DirectionHold = "hold"
)

// Constants for execution types
const (
	ExecutionTypeAuto   = "auto"
	ExecutionTypeManual = "manual"
)

// Constants for execution status
const (
	StatusPending   = "pending"
	StatusRunning   = "running"
	StatusCompleted = "completed"
	StatusFailed    = "failed"
)

// Helper methods

// CalculateDirection determines the direction based on price change percentage
func CalculateDirection(currentPrice, previousPrice float64, holdThreshold float64) string {
	if holdThreshold <= 0 {
		holdThreshold = 0.01 // Default 1% threshold
	}
	
	changePercent := (currentPrice - previousPrice) / previousPrice
	
	if changePercent > holdThreshold {
		return DirectionUp
	} else if changePercent < -holdThreshold {
		return DirectionDown
	}
	return DirectionHold
}

// CalculateMAPE calculates Mean Absolute Percentage Error
func CalculateMAPE(predicted, actual float64) float64 {
	if actual == 0 {
		return 0 // Avoid division by zero
	}
	return (abs(predicted - actual) / actual) * 100
}

// abs returns the absolute value of a float64
func abs(x float64) float64 {
	if x < 0 {
		return -x
	}
	return x
}
