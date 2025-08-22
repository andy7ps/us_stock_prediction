package handlers

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"stock-prediction-us/internal/models"
)

type SearchHistoryHandler struct {
	db *sql.DB
}

func NewSearchHistoryHandler(db *sql.DB) *SearchHistoryHandler {
	return &SearchHistoryHandler{
		db: db,
	}
}

// GetSearchHistory handles GET /api/v1/search-history
func (h *SearchHistoryHandler) GetSearchHistory(w http.ResponseWriter, r *http.Request) {
	// Get all search history
	history, err := h.getAllSearchHistory()
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to get search history: %v", err), http.StatusInternalServerError)
		return
	}

	// Get popular stocks (top 10 by search count)
	popular, err := h.getPopularStocks(10)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to get popular stocks: %v", err), http.StatusInternalServerError)
		return
	}

	// Get recent searches (last 5)
	recent, err := h.getRecentSearches(5)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to get recent searches: %v", err), http.StatusInternalServerError)
		return
	}

	response := models.SearchHistoryResponse{
		History: history,
		Popular: popular,
		Recent:  recent,
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if err := json.NewEncoder(w).Encode(response); err != nil {
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}
}

// RecordSearch handles POST /api/v1/search-history
func (h *SearchHistoryHandler) RecordSearch(w http.ResponseWriter, r *http.Request) {
	var request struct {
		Symbol string `json:"symbol"`
	}

	if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	symbol := strings.ToUpper(strings.TrimSpace(request.Symbol))
	if symbol == "" {
		http.Error(w, "Symbol is required", http.StatusBadRequest)
		return
	}

	// Record the search
	if err := h.recordSearch(symbol); err != nil {
		http.Error(w, fmt.Sprintf("Failed to record search: %v", err), http.StatusInternalServerError)
		return
	}

	response := map[string]interface{}{
		"success": true,
		"symbol":  symbol,
		"message": "Search recorded successfully",
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if err := json.NewEncoder(w).Encode(response); err != nil {
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}
}

// GetPopularStocks handles GET /api/v1/search-history/popular
func (h *SearchHistoryHandler) GetPopularStocks(w http.ResponseWriter, r *http.Request) {
	limitStr := r.URL.Query().Get("limit")
	limit := 10 // Default limit
	
	if limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 {
			limit = parsedLimit
		}
	}

	popular, err := h.getPopularStocks(limit)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to get popular stocks: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if err := json.NewEncoder(w).Encode(popular); err != nil {
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}
}

// GetRecentSearches handles GET /api/v1/search-history/recent
func (h *SearchHistoryHandler) GetRecentSearches(w http.ResponseWriter, r *http.Request) {
	limitStr := r.URL.Query().Get("limit")
	limit := 5 // Default limit
	
	if limitStr != "" {
		if parsedLimit, err := strconv.Atoi(limitStr); err == nil && parsedLimit > 0 {
			limit = parsedLimit
		}
	}

	recent, err := h.getRecentSearches(limit)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to get recent searches: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if err := json.NewEncoder(w).Encode(recent); err != nil {
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}
}

// ClearSearchHistory handles DELETE /api/v1/search-history
func (h *SearchHistoryHandler) ClearSearchHistory(w http.ResponseWriter, r *http.Request) {
	query := `DELETE FROM search_history WHERE search_count < 50` // Keep popular ones
	
	result, err := h.db.Exec(query)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to clear search history: %v", err), http.StatusInternalServerError)
		return
	}

	rowsAffected, _ := result.RowsAffected()

	response := map[string]interface{}{
		"success":       true,
		"message":       "Search history cleared successfully",
		"rows_affected": rowsAffected,
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	if err := json.NewEncoder(w).Encode(response); err != nil {
		http.Error(w, "Failed to encode response", http.StatusInternalServerError)
		return
	}
}

// Database helper methods

func (h *SearchHistoryHandler) getAllSearchHistory() ([]models.SearchHistory, error) {
	query := `
		SELECT id, symbol, search_count, last_searched_at, created_at, updated_at 
		FROM search_history 
		ORDER BY search_count DESC, last_searched_at DESC
		LIMIT 50
	`
	
	rows, err := h.db.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var history []models.SearchHistory
	for rows.Next() {
		var item models.SearchHistory
		err := rows.Scan(
			&item.ID,
			&item.Symbol,
			&item.SearchCount,
			&item.LastSearchedAt,
			&item.CreatedAt,
			&item.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		history = append(history, item)
	}

	return history, nil
}

func (h *SearchHistoryHandler) getPopularStocks(limit int) ([]models.SearchHistory, error) {
	query := `
		SELECT id, symbol, search_count, last_searched_at, created_at, updated_at 
		FROM search_history 
		ORDER BY search_count DESC 
		LIMIT ?
	`
	
	rows, err := h.db.Query(query, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var popular []models.SearchHistory
	for rows.Next() {
		var item models.SearchHistory
		err := rows.Scan(
			&item.ID,
			&item.Symbol,
			&item.SearchCount,
			&item.LastSearchedAt,
			&item.CreatedAt,
			&item.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		popular = append(popular, item)
	}

	return popular, nil
}

func (h *SearchHistoryHandler) getRecentSearches(limit int) ([]models.SearchHistory, error) {
	query := `
		SELECT id, symbol, search_count, last_searched_at, created_at, updated_at 
		FROM search_history 
		ORDER BY last_searched_at DESC 
		LIMIT ?
	`
	
	rows, err := h.db.Query(query, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var recent []models.SearchHistory
	for rows.Next() {
		var item models.SearchHistory
		err := rows.Scan(
			&item.ID,
			&item.Symbol,
			&item.SearchCount,
			&item.LastSearchedAt,
			&item.CreatedAt,
			&item.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		recent = append(recent, item)
	}

	return recent, nil
}

func (h *SearchHistoryHandler) recordSearch(symbol string) error {
	// Use INSERT OR REPLACE to update existing or create new
	query := `
		INSERT INTO search_history (symbol, search_count, last_searched_at, created_at, updated_at)
		VALUES (?, 1, ?, ?, ?)
		ON CONFLICT(symbol) DO UPDATE SET
			search_count = search_count + 1,
			last_searched_at = ?,
			updated_at = ?
	`
	
	now := time.Now()
	_, err := h.db.Exec(query, symbol, now, now, now, now, now)
	return err
}

// HandleOptions handles CORS preflight requests
func (h *SearchHistoryHandler) HandleOptions(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
	w.WriteHeader(http.StatusOK)
}
