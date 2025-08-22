package models

import (
	"time"
)

// SearchHistory represents a user's search history entry
type SearchHistory struct {
	ID             int       `json:"id" db:"id"`
	Symbol         string    `json:"symbol" db:"symbol"`
	SearchCount    int       `json:"search_count" db:"search_count"`
	LastSearchedAt time.Time `json:"last_searched_at" db:"last_searched_at"`
	CreatedAt      time.Time `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time `json:"updated_at" db:"updated_at"`
}

// CandlestickData represents OHLCV data for charting
type CandlestickData struct {
	Symbol    string    `json:"symbol"`
	Timestamp time.Time `json:"timestamp"`
	Open      float64   `json:"open"`
	High      float64   `json:"high"`
	Low       float64   `json:"low"`
	Close     float64   `json:"close"`
	Volume    int64     `json:"volume"`
}

// ChartDataResponse represents the response for chart data
type ChartDataResponse struct {
	Symbol      string            `json:"symbol"`
	Data        []CandlestickData `json:"data"`
	Count       int               `json:"count"`
	TimeRange   string            `json:"time_range"`
	CurrentPrice float64          `json:"current_price,omitempty"`
	Change      float64           `json:"change,omitempty"`
	ChangePercent float64         `json:"change_percent,omitempty"`
}

// SearchHistoryResponse represents the response for search history
type SearchHistoryResponse struct {
	History []SearchHistory `json:"history"`
	Popular []SearchHistory `json:"popular"`
	Recent  []SearchHistory `json:"recent"`
}
