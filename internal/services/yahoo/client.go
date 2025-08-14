package yahoo

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"time"

	"github.com/sirupsen/logrus"
	"golang.org/x/time/rate"

	"stock-prediction-us/internal/config"
	"stock-prediction-us/internal/metrics"
	"stock-prediction-us/internal/models"
)

// Client represents Yahoo Finance API client
type Client struct {
	httpClient  *http.Client
	rateLimiter *rate.Limiter
	config      *config.Config
	logger      *logrus.Logger
	metrics     *metrics.Metrics
}

// NewClient creates a new Yahoo Finance client
func NewClient(cfg *config.Config, logger *logrus.Logger, metrics *metrics.Metrics) *Client {
	// Create rate limiter
	limiter := rate.NewLimiter(rate.Limit(cfg.Stock.RequestsPerSec), 1)
	
	// Create HTTP client with timeout
	httpClient := &http.Client{
		Timeout: cfg.API.Timeout,
	}
	
	return &Client{
		httpClient:  httpClient,
		rateLimiter: limiter,
		config:      cfg,
		logger:      logger,
		metrics:     metrics,
	}
}

// FetchStockData fetches stock data with retry logic
func (c *Client) FetchStockData(symbol string, period string) ([]float64, error) {
	start := time.Now()
	var lastErr error
	
	// Validate symbol
	if err := models.ValidateSymbol(symbol); err != nil {
		c.metrics.RecordStockDataFetch(time.Since(start).Seconds(), false)
		return nil, fmt.Errorf("invalid symbol: %w", err)
	}
	
	// Retry logic with exponential backoff
	for attempt := 0; attempt < c.config.Stock.MaxRetries; attempt++ {
		if attempt > 0 {
			// Exponential backoff
			backoff := time.Duration(math.Pow(2, float64(attempt))) * time.Second
			c.logger.WithFields(logrus.Fields{
				"symbol":  symbol,
				"attempt": attempt + 1,
				"backoff": backoff,
			}).Warn("Retrying stock data fetch")
			time.Sleep(backoff)
		}
		
		data, err := c.fetchStockDataOnce(symbol, period)
		if err == nil {
			c.metrics.RecordStockDataFetch(time.Since(start).Seconds(), true)
			return data, nil
		}
		
		lastErr = err
		c.logger.WithFields(logrus.Fields{
			"symbol":  symbol,
			"attempt": attempt + 1,
			"error":   err,
		}).Error("Stock data fetch attempt failed")
	}
	
	c.metrics.RecordStockDataFetch(time.Since(start).Seconds(), false)
	return nil, fmt.Errorf("failed after %d attempts: %w", c.config.Stock.MaxRetries, lastErr)
}

// fetchStockDataOnce performs a single stock data fetch
func (c *Client) fetchStockDataOnce(symbol string, period string) ([]float64, error) {
	// Rate limiting
	if err := c.rateLimiter.Wait(context.Background()); err != nil {
		return nil, fmt.Errorf("rate limiter error: %w", err)
	}
	
	// Build URL
	url := fmt.Sprintf("%s/v8/finance/chart/%s?interval=1d&range=%s", 
		c.config.API.BaseURL, symbol, period)
	
	c.logger.WithFields(logrus.Fields{
		"symbol": symbol,
		"url":    url,
	}).Debug("Fetching stock data")
	
	// Create request
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	
	// Set headers
	req.Header.Set("User-Agent", c.config.API.UserAgent)
	req.Header.Set("Accept", "application/json")
	
	// Execute request
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("HTTP request failed: %w", err)
	}
	defer resp.Body.Close()
	
	// Check status code
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("HTTP %d: %s", resp.StatusCode, string(body))
	}
	
	// Read response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %w", err)
	}
	
	// Parse JSON response
	var response models.YahooFinanceResponse
	if err := json.Unmarshal(body, &response); err != nil {
		return nil, fmt.Errorf("failed to parse JSON response: %w", err)
	}
	
	// Check for API errors
	if response.Chart.Error != nil {
		return nil, fmt.Errorf("API error: %s - %s", 
			response.Chart.Error.Code, response.Chart.Error.Description)
	}
	
	// Validate response structure
	if len(response.Chart.Result) == 0 {
		return nil, fmt.Errorf("no data in response")
	}
	
	result := response.Chart.Result[0]
	if len(result.Indicators.Quote) == 0 {
		return nil, fmt.Errorf("no quote data in response")
	}
	
	closePrices := result.Indicators.Quote[0].Close
	if len(closePrices) == 0 {
		return nil, fmt.Errorf("no close prices in response")
	}
	
	// Validate data quality
	if err := models.ValidateStockData(closePrices, 1); err != nil {
		return nil, fmt.Errorf("invalid stock data: %w", err)
	}
	
	c.logger.WithFields(logrus.Fields{
		"symbol":     symbol,
		"data_points": len(closePrices),
		"latest_price": closePrices[len(closePrices)-1],
	}).Info("Successfully fetched stock data")
	
	return closePrices, nil
}

// FetchLatestPrice fetches the latest stock price
func (c *Client) FetchLatestPrice(symbol string) (float64, error) {
	data, err := c.FetchStockData(symbol, "1d")
	if err != nil {
		return 0, err
	}
	
	if len(data) == 0 {
		return 0, fmt.Errorf("no price data available")
	}
	
	return data[len(data)-1], nil
}

// FetchHistoricalData fetches historical data for the specified number of days
func (c *Client) FetchHistoricalData(symbol string, days int) ([]models.StockData, error) {
	var period string
	switch {
	case days <= 7:
		period = "7d"
	case days <= 30:
		period = "1mo"
	case days <= 90:
		period = "3mo"
	case days <= 180:
		period = "6mo"
	case days <= 365:
		period = "1y"
	default:
		period = "2y"
	}
	
	// Build URL for detailed data
	url := fmt.Sprintf("%s/v8/finance/chart/%s?interval=1d&range=%s", 
		c.config.API.BaseURL, symbol, period)
	
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	
	req.Header.Set("User-Agent", c.config.API.UserAgent)
	req.Header.Set("Accept", "application/json")
	
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("HTTP request failed: %w", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %w", err)
	}
	
	var response models.YahooFinanceResponse
	if err := json.Unmarshal(body, &response); err != nil {
		return nil, fmt.Errorf("failed to parse JSON response: %w", err)
	}
	
	if len(response.Chart.Result) == 0 {
		return nil, fmt.Errorf("no data in response")
	}
	
	result := response.Chart.Result[0]
	timestamps := result.Timestamp
	quotes := result.Indicators.Quote[0]
	
	stockData := make([]models.StockData, len(timestamps))
	for i, timestamp := range timestamps {
		stockData[i] = models.StockData{
			Symbol:    symbol,
			Timestamp: time.Unix(timestamp, 0),
			Open:      quotes.Open[i],
			High:      quotes.High[i],
			Low:       quotes.Low[i],
			Close:     quotes.Close[i],
			Volume:    quotes.Volume[i],
		}
	}
	
	// Limit to requested number of days
	if len(stockData) > days {
		stockData = stockData[len(stockData)-days:]
	}
	
	return stockData, nil
}

// HealthCheck checks if the Yahoo Finance API is accessible
func (c *Client) HealthCheck() error {
	// Try to fetch a simple quote for a well-known symbol
	_, err := c.FetchLatestPrice("AAPL")
	return err
}
