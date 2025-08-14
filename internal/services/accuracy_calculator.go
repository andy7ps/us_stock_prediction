package services

import (
	"database/sql"
	"fmt"
	"time"

	"stock-prediction-us/internal/models"
)

type AccuracyCalculatorService struct {
	db *sql.DB
}

// NewAccuracyCalculatorService creates a new accuracy calculator service
func NewAccuracyCalculatorService(db *sql.DB) *AccuracyCalculatorService {
	return &AccuracyCalculatorService{
		db: db,
	}
}

// GetAccuracySummary returns accuracy summary for a specific symbol
func (s *AccuracyCalculatorService) GetAccuracySummary(symbol string) (*models.PredictionAccuracySummary, error) {
	query := `
		SELECT 
			COUNT(*) as total_predictions,
			COUNT(actual_close) as predictions_with_actual,
			AVG(CASE WHEN accuracy_mape IS NOT NULL THEN accuracy_mape END) as avg_accuracy_mape,
			AVG(CASE WHEN direction_correct IS NOT NULL THEN CAST(direction_correct AS FLOAT) END) as direction_accuracy,
			AVG(CASE WHEN confidence IS NOT NULL THEN confidence END) as avg_confidence,
			MIN(CASE WHEN accuracy_mape IS NOT NULL THEN accuracy_mape END) as best_accuracy,
			MAX(CASE WHEN accuracy_mape IS NOT NULL THEN accuracy_mape END) as worst_accuracy,
			MAX(prediction_date) as last_prediction_date
		FROM prediction_tracking
		WHERE symbol = ?
	`

	var summary models.PredictionAccuracySummary
	var lastPredictionDateStr sql.NullString
	var avgAccuracyMAPE, directionAccuracy, avgConfidence sql.NullFloat64
	var bestAccuracy, worstAccuracy sql.NullFloat64

	err := s.db.QueryRow(query, symbol).Scan(
		&summary.TotalPredictions,
		&summary.PredictionsWithActual,
		&avgAccuracyMAPE,
		&directionAccuracy,
		&avgConfidence,
		&bestAccuracy,
		&worstAccuracy,
		&lastPredictionDateStr,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to get accuracy summary: %v", err)
	}

	summary.Symbol = symbol

	if avgAccuracyMAPE.Valid {
		summary.AverageAccuracyMAPE = avgAccuracyMAPE.Float64
	}

	if directionAccuracy.Valid {
		summary.DirectionAccuracy = directionAccuracy.Float64 * 100 // Convert to percentage
	}

	if avgConfidence.Valid {
		summary.AverageConfidence = avgConfidence.Float64
	}

	if bestAccuracy.Valid {
		summary.BestAccuracy = bestAccuracy.Float64
	}

	if worstAccuracy.Valid {
		summary.WorstAccuracy = worstAccuracy.Float64
	}

	if lastPredictionDateStr.Valid {
		if date, err := time.Parse("2006-01-02", lastPredictionDateStr.String); err == nil {
			summary.LastPredictionDate = &date
		}
	}

	return &summary, nil
}

// GetOverallPerformanceMetrics returns overall performance metrics for all symbols
func (s *AccuracyCalculatorService) GetOverallPerformanceMetrics() (*models.PredictionPerformanceMetrics, error) {
	// Get overall statistics
	overallQuery := `
		SELECT 
			COUNT(DISTINCT symbol) as total_symbols,
			COUNT(*) as total_predictions,
			COUNT(actual_close) as predictions_with_actual,
			AVG(CASE WHEN accuracy_mape IS NOT NULL THEN accuracy_mape END) as overall_accuracy_mape,
			AVG(CASE WHEN direction_correct IS NOT NULL THEN CAST(direction_correct AS FLOAT) END) as overall_direction_accuracy
		FROM prediction_tracking
	`

	var metrics models.PredictionPerformanceMetrics
	var overallAccuracyMAPE, overallDirectionAccuracy sql.NullFloat64

	err := s.db.QueryRow(overallQuery).Scan(
		&metrics.TotalSymbols,
		&metrics.TotalPredictions,
		&metrics.PredictionsWithActual,
		&overallAccuracyMAPE,
		&overallDirectionAccuracy,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to get overall metrics: %v", err)
	}

	if overallAccuracyMAPE.Valid {
		metrics.OverallAccuracyMAPE = overallAccuracyMAPE.Float64
	}

	if overallDirectionAccuracy.Valid {
		metrics.OverallDirectionAccuracy = overallDirectionAccuracy.Float64 * 100 // Convert to percentage
	}

	// Get last execution information
	lastExecQuery := `
		SELECT execution_date, status
		FROM daily_execution_log
		ORDER BY execution_date DESC, created_at DESC
		LIMIT 1
	`

	var lastExecDateStr sql.NullString
	var lastExecStatus sql.NullString

	err = s.db.QueryRow(lastExecQuery).Scan(&lastExecDateStr, &lastExecStatus)
	if err == nil {
		if lastExecDateStr.Valid {
			if date, err := time.Parse("2006-01-02", lastExecDateStr.String); err == nil {
				metrics.LastExecutionDate = &date
			}
		}
		if lastExecStatus.Valid {
			metrics.LastExecutionStatus = lastExecStatus.String
		}
	}

	// Get symbol summaries
	symbols, err := s.getDistinctSymbols()
	if err != nil {
		return nil, fmt.Errorf("failed to get symbols: %v", err)
	}

	for _, symbol := range symbols {
		summary, err := s.GetAccuracySummary(symbol)
		if err != nil {
			continue // Skip symbols with errors
		}
		metrics.SymbolSummaries = append(metrics.SymbolSummaries, *summary)
	}

	return &metrics, nil
}

// GetAccuracyInRange returns accuracy data for symbols in a date range
func (s *AccuracyCalculatorService) GetAccuracyInRange(query models.AccuracyRangeQuery) ([]models.PredictionTracking, error) {
	sqlQuery := `
		SELECT id, symbol, prediction_date, predicted_price, predicted_direction,
			   confidence, actual_close, accuracy_mape, direction_correct,
			   market_was_open, prediction_timestamp, actual_price_timestamp,
			   created_at, updated_at
		FROM prediction_tracking
		WHERE prediction_date >= ? AND prediction_date <= ?
		  AND actual_close IS NOT NULL
	`
	args := []interface{}{query.StartDate.Format("2006-01-02"), query.EndDate.Format("2006-01-02")}

	if len(query.Symbols) > 0 {
		placeholders := ""
		for i, symbol := range query.Symbols {
			if i > 0 {
				placeholders += ", "
			}
			placeholders += "?"
			args = append(args, symbol)
		}
		sqlQuery += " AND symbol IN (" + placeholders + ")"
	}

	sqlQuery += " ORDER BY prediction_date DESC, symbol"

	rows, err := s.db.Query(sqlQuery, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query accuracy range: %v", err)
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

// GetDailyExecutionStatus returns the status of daily prediction executions
func (s *AccuracyCalculatorService) GetDailyExecutionStatus() (*models.DailyPredictionStatus, error) {
	query := `
		SELECT execution_date, status, total_symbols, successful_predictions, 
			   failed_predictions, execution_duration_ms, error_message
		FROM daily_execution_log
		ORDER BY execution_date DESC, created_at DESC
		LIMIT 1
	`

	var status models.DailyPredictionStatus
	var executionDateStr sql.NullString
	var executionStatus sql.NullString
	var totalSymbols, successfulSymbols, failedSymbols sql.NullInt64
	var executionDuration sql.NullInt64
	var errorMessage sql.NullString

	err := s.db.QueryRow(query).Scan(
		&executionDateStr, &executionStatus, &totalSymbols,
		&successfulSymbols, &failedSymbols, &executionDuration, &errorMessage,
	)

	if err == sql.ErrNoRows {
		// No executions yet
		status.IsEnabled = true // Assume enabled by default
		return &status, nil
	} else if err != nil {
		return nil, fmt.Errorf("failed to get execution status: %v", err)
	}

	if executionDateStr.Valid {
		if date, err := time.Parse("2006-01-02", executionDateStr.String); err == nil {
			status.LastExecutionDate = &date
		}
	}

	if executionStatus.Valid {
		status.LastExecutionStatus = executionStatus.String
	}

	if totalSymbols.Valid {
		status.TotalSymbols = int(totalSymbols.Int64)
	}

	if successfulSymbols.Valid {
		status.SuccessfulSymbols = int(successfulSymbols.Int64)
	}

	if failedSymbols.Valid {
		status.FailedSymbols = int(failedSymbols.Int64)
	}

	if executionDuration.Valid {
		duration := int(executionDuration.Int64)
		status.ExecutionDuration = &duration
	}

	if errorMessage.Valid {
		status.ErrorMessage = &errorMessage.String
	}

	status.IsEnabled = true // This would come from configuration

	// Calculate next scheduled run (9:00 AM Taipei time next day)
	if status.LastExecutionDate != nil {
		nextRun := status.LastExecutionDate.AddDate(0, 0, 1)
		// Set to 9:00 AM Taipei time (1:00 AM UTC)
		nextRun = time.Date(nextRun.Year(), nextRun.Month(), nextRun.Day(), 1, 0, 0, 0, time.UTC)
		status.NextScheduledRun = &nextRun
	}

	return &status, nil
}

// CalculateAccuracyTrends calculates accuracy trends over time
func (s *AccuracyCalculatorService) CalculateAccuracyTrends(symbol string, days int) (map[string]interface{}, error) {
	query := `
		SELECT 
			DATE(prediction_date) as date,
			AVG(CASE WHEN accuracy_mape IS NOT NULL THEN accuracy_mape END) as avg_accuracy,
			AVG(CASE WHEN direction_correct IS NOT NULL THEN CAST(direction_correct AS FLOAT) END) as direction_accuracy,
			COUNT(*) as total_predictions,
			COUNT(actual_close) as predictions_with_actual
		FROM prediction_tracking
		WHERE symbol = ? AND prediction_date >= date('now', '-' || ? || ' days')
		GROUP BY DATE(prediction_date)
		ORDER BY date DESC
	`

	rows, err := s.db.Query(query, symbol, days)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate accuracy trends: %v", err)
	}
	defer rows.Close()

	var trends []map[string]interface{}
	for rows.Next() {
		var date string
		var avgAccuracy, directionAccuracy sql.NullFloat64
		var totalPredictions, predictionsWithActual int

		err := rows.Scan(&date, &avgAccuracy, &directionAccuracy, &totalPredictions, &predictionsWithActual)
		if err != nil {
			return nil, fmt.Errorf("failed to scan trend row: %v", err)
		}

		trend := map[string]interface{}{
			"date":                     date,
			"total_predictions":        totalPredictions,
			"predictions_with_actual":  predictionsWithActual,
		}

		if avgAccuracy.Valid {
			trend["avg_accuracy_mape"] = avgAccuracy.Float64
		}

		if directionAccuracy.Valid {
			trend["direction_accuracy"] = directionAccuracy.Float64 * 100
		}

		trends = append(trends, trend)
	}

	result := map[string]interface{}{
		"symbol": symbol,
		"days":   days,
		"trends": trends,
	}

	return result, nil
}

// GetTopPerformingSymbols returns symbols with best accuracy
func (s *AccuracyCalculatorService) GetTopPerformingSymbols(limit int) ([]models.PredictionAccuracySummary, error) {
	query := `
		SELECT 
			symbol,
			COUNT(*) as total_predictions,
			COUNT(actual_close) as predictions_with_actual,
			AVG(CASE WHEN accuracy_mape IS NOT NULL THEN accuracy_mape END) as avg_accuracy_mape,
			AVG(CASE WHEN direction_correct IS NOT NULL THEN CAST(direction_correct AS FLOAT) END) as direction_accuracy,
			AVG(CASE WHEN confidence IS NOT NULL THEN confidence END) as avg_confidence,
			MIN(CASE WHEN accuracy_mape IS NOT NULL THEN accuracy_mape END) as best_accuracy,
			MAX(CASE WHEN accuracy_mape IS NOT NULL THEN accuracy_mape END) as worst_accuracy,
			MAX(prediction_date) as last_prediction_date
		FROM prediction_tracking
		WHERE actual_close IS NOT NULL
		GROUP BY symbol
		HAVING COUNT(actual_close) >= 5  -- At least 5 predictions with actual data
		ORDER BY avg_accuracy_mape ASC, direction_accuracy DESC
		LIMIT ?
	`

	rows, err := s.db.Query(query, limit)
	if err != nil {
		return nil, fmt.Errorf("failed to get top performing symbols: %v", err)
	}
	defer rows.Close()

	var summaries []models.PredictionAccuracySummary
	for rows.Next() {
		var summary models.PredictionAccuracySummary
		var lastPredictionDateStr sql.NullString
		var avgAccuracyMAPE, directionAccuracy, avgConfidence sql.NullFloat64
		var bestAccuracy, worstAccuracy sql.NullFloat64

		err := rows.Scan(
			&summary.Symbol,
			&summary.TotalPredictions,
			&summary.PredictionsWithActual,
			&avgAccuracyMAPE,
			&directionAccuracy,
			&avgConfidence,
			&bestAccuracy,
			&worstAccuracy,
			&lastPredictionDateStr,
		)

		if err != nil {
			return nil, fmt.Errorf("failed to scan summary row: %v", err)
		}

		if avgAccuracyMAPE.Valid {
			summary.AverageAccuracyMAPE = avgAccuracyMAPE.Float64
		}

		if directionAccuracy.Valid {
			summary.DirectionAccuracy = directionAccuracy.Float64 * 100
		}

		if avgConfidence.Valid {
			summary.AverageConfidence = avgConfidence.Float64
		}

		if bestAccuracy.Valid {
			summary.BestAccuracy = bestAccuracy.Float64
		}

		if worstAccuracy.Valid {
			summary.WorstAccuracy = worstAccuracy.Float64
		}

		if lastPredictionDateStr.Valid {
			if date, err := time.Parse("2006-01-02", lastPredictionDateStr.String); err == nil {
				summary.LastPredictionDate = &date
			}
		}

		summaries = append(summaries, summary)
	}

	return summaries, nil
}

// Helper methods

func (s *AccuracyCalculatorService) getDistinctSymbols() ([]string, error) {
	query := `SELECT DISTINCT symbol FROM prediction_tracking ORDER BY symbol`
	
	rows, err := s.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var symbols []string
	for rows.Next() {
		var symbol string
		if err := rows.Scan(&symbol); err != nil {
			return nil, err
		}
		symbols = append(symbols, symbol)
	}

	return symbols, nil
}
