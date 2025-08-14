package services

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"stock-prediction-us/internal/models"
	"stock-prediction-us/internal/services/prediction"
)

type PredictionTrackerService struct {
	db                    *sql.DB
	marketCalendarService *MarketCalendarService
	predictionService     *prediction.Service
}

// NewPredictionTrackerService creates a new prediction tracker service
func NewPredictionTrackerService(db *sql.DB, marketCalendarService *MarketCalendarService, predictionService *prediction.Service) *PredictionTrackerService {
	return &PredictionTrackerService{
		db:                    db,
		marketCalendarService: marketCalendarService,
		predictionService:     predictionService,
	}
}

// CreatePrediction creates a new prediction tracking record
func (s *PredictionTrackerService) CreatePrediction(req models.CreatePredictionRequest) (*models.PredictionTracking, error) {
	query := `
		INSERT INTO prediction_tracking (
			symbol, prediction_date, predicted_price, predicted_direction, 
			confidence, market_was_open, prediction_timestamp
		) VALUES (?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(symbol, prediction_date) DO UPDATE SET
			predicted_price = excluded.predicted_price,
			predicted_direction = excluded.predicted_direction,
			confidence = excluded.confidence,
			market_was_open = excluded.market_was_open,
			prediction_timestamp = excluded.prediction_timestamp,
			updated_at = CURRENT_TIMESTAMP
	`

	now := time.Now()
	_, err := s.db.Exec(query,
		req.Symbol,
		req.PredictionDate.Format("2006-01-02"),
		req.PredictedPrice,
		req.PredictedDirection,
		req.Confidence,
		req.MarketWasOpen,
		now,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to create prediction: %v", err)
	}

	// Retrieve the created/updated record
	return s.GetPrediction(req.Symbol, req.PredictionDate)
}

// GetPrediction retrieves a specific prediction record
func (s *PredictionTrackerService) GetPrediction(symbol string, date time.Time) (*models.PredictionTracking, error) {
	query := `
		SELECT id, symbol, prediction_date, predicted_price, predicted_direction,
			   confidence, actual_close, accuracy_mape, direction_correct,
			   market_was_open, prediction_timestamp, actual_price_timestamp,
			   created_at, updated_at
		FROM prediction_tracking
		WHERE symbol = ? AND prediction_date = ?
	`

	var p models.PredictionTracking
	var predictionDateStr string
	var actualPriceTimestamp sql.NullTime

	err := s.db.QueryRow(query, symbol, date.Format("2006-01-02")).Scan(
		&p.ID, &p.Symbol, &predictionDateStr, &p.PredictedPrice, &p.PredictedDirection,
		&p.Confidence, &p.ActualClose, &p.AccuracyMAPE, &p.DirectionCorrect,
		&p.MarketWasOpen, &p.PredictionTimestamp, &actualPriceTimestamp,
		&p.CreatedAt, &p.UpdatedAt,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to get prediction: %v", err)
	}

	p.PredictionDate, err = time.Parse("2006-01-02", predictionDateStr)
	if err != nil {
		return nil, fmt.Errorf("failed to parse prediction date: %v", err)
	}

	if actualPriceTimestamp.Valid {
		p.ActualPriceTimestamp = &actualPriceTimestamp.Time
	}

	return &p, nil
}

// UpdateActualPrice updates the actual closing price and calculates accuracy
func (s *PredictionTrackerService) UpdateActualPrice(req models.UpdateActualPriceRequest) error {
	// First, get the existing prediction
	prediction, err := s.GetPrediction(req.Symbol, req.Date)
	if err != nil {
		return fmt.Errorf("prediction not found: %v", err)
	}

	// Calculate accuracy metrics
	var accuracyMAPE *float64
	var directionCorrect *bool

	if prediction.PredictedPrice != nil {
		mape := models.CalculateMAPE(*prediction.PredictedPrice, req.ActualClose)
		accuracyMAPE = &mape
	}

	if prediction.PredictedDirection != nil && prediction.PredictedPrice != nil {
		// Get previous day's closing price to determine actual direction
		previousClose, err := s.getPreviousClosingPrice(req.Symbol, req.Date)
		if err == nil && previousClose > 0 {
			actualDirection := models.CalculateDirection(req.ActualClose, previousClose, 0.01)
			correct := *prediction.PredictedDirection == actualDirection
			directionCorrect = &correct
		}
	}

	// Update the record
	query := `
		UPDATE prediction_tracking
		SET actual_close = ?, accuracy_mape = ?, direction_correct = ?,
			actual_price_timestamp = ?, updated_at = CURRENT_TIMESTAMP
		WHERE symbol = ? AND prediction_date = ?
	`

	now := time.Now()
	_, err = s.db.Exec(query,
		req.ActualClose, accuracyMAPE, directionCorrect, now,
		req.Symbol, req.Date.Format("2006-01-02"),
	)

	if err != nil {
		return fmt.Errorf("failed to update actual price: %v", err)
	}

	log.Printf("Updated actual price for %s on %s: $%.2f", req.Symbol, req.Date.Format("2006-01-02"), req.ActualClose)
	return nil
}

// ExecuteDailyPredictions runs predictions for specified symbols
func (s *PredictionTrackerService) ExecuteDailyPredictions(req models.DailyPredictionRequest) (*models.DailyExecutionLog, error) {
	startTime := time.Now()

	// Create execution log
	logEntry := &models.DailyExecutionLog{
		ExecutionDate: startTime,
		ExecutionType: req.ExecutionType,
		Status:        models.StatusRunning,
		CreatedAt:     startTime,
	}

	// Determine symbols to process
	symbols := req.Symbols
	if len(symbols) == 0 {
		symbols = s.getDefaultSymbols()
	}

	logEntry.TotalSymbols = len(symbols)

	// Insert initial log entry
	logID, err := s.createExecutionLog(logEntry)
	if err != nil {
		return nil, fmt.Errorf("failed to create execution log: %v", err)
	}
	logEntry.ID = logID

	// Determine prediction date
	predictionDate := startTime
	if req.Date != nil {
		predictionDate = *req.Date
	}

	// Check if market should be open (unless forced)
	if !req.ForceExecute {
		isOpen, err := s.marketCalendarService.IsMarketOpen(predictionDate.AddDate(0, 0, -1))
		if err != nil {
			return s.updateExecutionLogError(logEntry, fmt.Sprintf("Failed to check market status: %v", err))
		}
		if !isOpen {
			return s.updateExecutionLogError(logEntry, "Market was closed yesterday, skipping execution")
		}
	}

	// Execute predictions for each symbol
	var successfulSymbols []string
	var failedSymbols []string

	for _, symbol := range symbols {
		err := s.executePredictionForSymbol(symbol, predictionDate)
		if err != nil {
			log.Printf("Failed to execute prediction for %s: %v", symbol, err)
			failedSymbols = append(failedSymbols, symbol)
		} else {
			successfulSymbols = append(successfulSymbols, symbol)
		}
	}

	// Update execution log
	endTime := time.Now()
	duration := int(endTime.Sub(startTime).Milliseconds())

	logEntry.SuccessfulPredictions = len(successfulSymbols)
	logEntry.FailedPredictions = len(failedSymbols)
	logEntry.ExecutionDurationMs = &duration
	logEntry.CompletedAt = &endTime

	if len(failedSymbols) == 0 {
		logEntry.Status = models.StatusCompleted
	} else if len(successfulSymbols) == 0 {
		logEntry.Status = models.StatusFailed
		errorMsg := fmt.Sprintf("All predictions failed. Failed symbols: %v", failedSymbols)
		logEntry.ErrorMessage = &errorMsg
	} else {
		logEntry.Status = models.StatusCompleted
		errorMsg := fmt.Sprintf("Partial success. Failed symbols: %v", failedSymbols)
		logEntry.ErrorMessage = &errorMsg
	}

	// Convert symbol arrays to JSON
	successfulJSON, _ := json.Marshal(successfulSymbols)
	failedJSON, _ := json.Marshal(failedSymbols)
	processedJSON, _ := json.Marshal(symbols)

	successfulStr := string(successfulJSON)
	failedStr := string(failedJSON)
	processedStr := string(processedJSON)

	logEntry.SymbolsSucceeded = &successfulStr
	logEntry.SymbolsFailed = &failedStr
	logEntry.SymbolsProcessed = &processedStr

	err = s.updateExecutionLog(logEntry)
	if err != nil {
		log.Printf("Failed to update execution log: %v", err)
	}

	return logEntry, nil
}

// executePredictionForSymbol executes prediction for a single symbol
func (s *PredictionTrackerService) executePredictionForSymbol(symbol string, date time.Time) error {
	// Check if market was open
	wasOpen, err := s.marketCalendarService.IsMarketOpen(date.AddDate(0, 0, -1))
	if err != nil {
		return fmt.Errorf("failed to check market status: %v", err)
	}

	// Get prediction from the existing prediction service
	// We need to create a prediction request with historical data
	// For now, we'll create a simple request - in production you'd get actual historical data
	predictionReq := &models.PredictionRequest{
		Symbol: symbol,
		HistoricalData: []float64{100.0, 101.0, 102.0, 103.0, 104.0}, // Placeholder data
	}
	
	prediction, err := s.predictionService.PredictStock(context.Background(), predictionReq)
	if err != nil {
		return fmt.Errorf("failed to get prediction: %v", err)
	}

	// Create prediction tracking record
	req := models.CreatePredictionRequest{
		Symbol:         symbol,
		PredictionDate: date,
		MarketWasOpen:  wasOpen,
	}

	if prediction.PredictedPrice > 0 {
		req.PredictedPrice = &prediction.PredictedPrice
	}

	if prediction.Confidence > 0 {
		req.Confidence = &prediction.Confidence
	}

	// Determine direction based on trading signal
	if prediction.TradingSignal != "" {
		var direction string
		switch prediction.TradingSignal {
		case "BUY":
			direction = models.DirectionUp
		case "SELL":
			direction = models.DirectionDown
		default:
			direction = models.DirectionHold
		}
		req.PredictedDirection = &direction
	}

	_, err = s.CreatePrediction(req)
	return err
}

// GetPredictionHistory retrieves prediction history with optional filtering
func (s *PredictionTrackerService) GetPredictionHistory(query models.PredictionHistoryQuery) ([]models.PredictionTracking, error) {
	sqlQuery := `
		SELECT id, symbol, prediction_date, predicted_price, predicted_direction,
			   confidence, actual_close, accuracy_mape, direction_correct,
			   market_was_open, prediction_timestamp, actual_price_timestamp,
			   created_at, updated_at
		FROM prediction_tracking
		WHERE 1=1
	`
	var args []interface{}

	if query.Symbol != nil {
		sqlQuery += " AND symbol = ?"
		args = append(args, *query.Symbol)
	}

	if query.StartDate != nil {
		sqlQuery += " AND prediction_date >= ?"
		args = append(args, query.StartDate.Format("2006-01-02"))
	}

	if query.EndDate != nil {
		sqlQuery += " AND prediction_date <= ?"
		args = append(args, query.EndDate.Format("2006-01-02"))
	}

	// Add ordering
	orderBy := "prediction_date"
	if query.OrderBy != "" {
		switch query.OrderBy {
		case "date", "accuracy", "confidence":
			orderBy = query.OrderBy
		}
	}

	orderDir := "DESC"
	if query.OrderDir == "asc" {
		orderDir = "ASC"
	}

	sqlQuery += fmt.Sprintf(" ORDER BY %s %s", orderBy, orderDir)

	// Add limit and offset
	if query.Limit > 0 {
		sqlQuery += " LIMIT ?"
		args = append(args, query.Limit)
	}

	if query.Offset > 0 {
		sqlQuery += " OFFSET ?"
		args = append(args, query.Offset)
	}

	rows, err := s.db.Query(sqlQuery, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query prediction history: %v", err)
	}
	defer rows.Close()

	var predictions []models.PredictionTracking
	for rows.Next() {
		var p models.PredictionTracking
		var predictionDateStr string
		var actualPriceTimestamp sql.NullTime

		err := rows.Scan(
			&p.ID, &p.Symbol, &predictionDateStr, &p.PredictedPrice, &p.PredictedDirection,
			&p.Confidence, &p.ActualClose, &p.AccuracyMAPE, &p.DirectionCorrect,
			&p.MarketWasOpen, &p.PredictionTimestamp, &actualPriceTimestamp,
			&p.CreatedAt, &p.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan prediction row: %v", err)
		}

		p.PredictionDate, err = time.Parse("2006-01-02", predictionDateStr)
		if err != nil {
			return nil, fmt.Errorf("failed to parse prediction date: %v", err)
		}

		if actualPriceTimestamp.Valid {
			p.ActualPriceTimestamp = &actualPriceTimestamp.Time
		}

		predictions = append(predictions, p)
	}

	return predictions, nil
}

// Helper methods

func (s *PredictionTrackerService) getDefaultSymbols() []string {
	return []string{"NVDA", "TSLA", "AAPL", "MSFT", "GOOGL", "AMZN", "AUR", "PLTR", "SMCI", "TSM", "MP", "SMR", "SPY"}
}

func (s *PredictionTrackerService) createExecutionLog(log *models.DailyExecutionLog) (int, error) {
	query := `
		INSERT INTO daily_execution_log (
			execution_date, execution_type, total_symbols, status, created_at
		) VALUES (?, ?, ?, ?, ?)
	`

	result, err := s.db.Exec(query,
		log.ExecutionDate.Format("2006-01-02"),
		log.ExecutionType,
		log.TotalSymbols,
		log.Status,
		log.CreatedAt,
	)

	if err != nil {
		return 0, err
	}

	id, err := result.LastInsertId()
	return int(id), err
}

func (s *PredictionTrackerService) updateExecutionLog(log *models.DailyExecutionLog) error {
	query := `
		UPDATE daily_execution_log
		SET symbols_processed = ?, symbols_succeeded = ?, symbols_failed = ?,
			successful_predictions = ?, failed_predictions = ?, execution_duration_ms = ?,
			error_message = ?, status = ?, completed_at = ?
		WHERE id = ?
	`

	_, err := s.db.Exec(query,
		log.SymbolsProcessed, log.SymbolsSucceeded, log.SymbolsFailed,
		log.SuccessfulPredictions, log.FailedPredictions, log.ExecutionDurationMs,
		log.ErrorMessage, log.Status, log.CompletedAt, log.ID,
	)

	return err
}

func (s *PredictionTrackerService) updateExecutionLogError(log *models.DailyExecutionLog, errorMsg string) (*models.DailyExecutionLog, error) {
	log.Status = models.StatusFailed
	log.ErrorMessage = &errorMsg
	now := time.Now()
	log.CompletedAt = &now

	err := s.updateExecutionLog(log)
	return log, err
}

func (s *PredictionTrackerService) getPreviousClosingPrice(symbol string, date time.Time) (float64, error) {
	// This would typically call the Yahoo Finance API or use cached data
	// For now, we'll return an error to indicate it's not implemented
	return 0, fmt.Errorf("previous closing price lookup not implemented")
}
