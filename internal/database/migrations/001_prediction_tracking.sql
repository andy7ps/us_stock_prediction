-- Migration: 001_prediction_tracking.sql
-- Description: Create tables for daily prediction tracking and accuracy analysis
-- Version: v3.4.0
-- Created: 2024-08-14

-- Prediction tracking table
CREATE TABLE IF NOT EXISTS prediction_tracking (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol VARCHAR(10) NOT NULL,
    prediction_date DATE NOT NULL,
    predicted_price DECIMAL(10,2),
    predicted_direction VARCHAR(10), -- 'up', 'down', 'hold'
    confidence DECIMAL(5,4),
    actual_close DECIMAL(10,2),
    accuracy_mape DECIMAL(5,4), -- Mean Absolute Percentage Error
    direction_correct BOOLEAN,
    market_was_open BOOLEAN DEFAULT TRUE,
    prediction_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    actual_price_timestamp TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(symbol, prediction_date)
);

-- Market calendar table for holiday tracking
CREATE TABLE IF NOT EXISTS market_calendar (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date DATE NOT NULL UNIQUE,
    is_market_open BOOLEAN NOT NULL,
    holiday_name VARCHAR(100),
    market_type VARCHAR(20) DEFAULT 'US', -- Support for different markets
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Daily execution log table
CREATE TABLE IF NOT EXISTS daily_execution_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    execution_date DATE NOT NULL,
    execution_type VARCHAR(20) NOT NULL, -- 'auto', 'manual'
    symbols_processed TEXT, -- JSON array of symbols
    symbols_succeeded TEXT, -- JSON array of successful symbols
    symbols_failed TEXT, -- JSON array of failed symbols
    total_symbols INTEGER DEFAULT 0,
    successful_predictions INTEGER DEFAULT 0,
    failed_predictions INTEGER DEFAULT 0,
    execution_duration_ms INTEGER,
    error_message TEXT,
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'running', 'completed', 'failed'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_prediction_tracking_symbol_date ON prediction_tracking(symbol, prediction_date);
CREATE INDEX IF NOT EXISTS idx_prediction_tracking_date ON prediction_tracking(prediction_date);
CREATE INDEX IF NOT EXISTS idx_prediction_tracking_symbol ON prediction_tracking(symbol);
CREATE INDEX IF NOT EXISTS idx_market_calendar_date ON market_calendar(date);
CREATE INDEX IF NOT EXISTS idx_daily_execution_log_date ON daily_execution_log(execution_date);

-- Insert some initial US market holidays for 2024
INSERT OR IGNORE INTO market_calendar (date, is_market_open, holiday_name) VALUES
('2024-01-01', FALSE, 'New Year''s Day'),
('2024-01-15', FALSE, 'Martin Luther King Jr. Day'),
('2024-02-19', FALSE, 'Presidents'' Day'),
('2024-03-29', FALSE, 'Good Friday'),
('2024-05-27', FALSE, 'Memorial Day'),
('2024-06-19', FALSE, 'Juneteenth'),
('2024-07-04', FALSE, 'Independence Day'),
('2024-09-02', FALSE, 'Labor Day'),
('2024-11-28', FALSE, 'Thanksgiving Day'),
('2024-12-25', FALSE, 'Christmas Day');

-- Insert some initial US market holidays for 2025
INSERT OR IGNORE INTO market_calendar (date, is_market_open, holiday_name) VALUES
('2025-01-01', FALSE, 'New Year''s Day'),
('2025-01-20', FALSE, 'Martin Luther King Jr. Day'),
('2025-02-17', FALSE, 'Presidents'' Day'),
('2025-04-18', FALSE, 'Good Friday'),
('2025-05-26', FALSE, 'Memorial Day'),
('2025-06-19', FALSE, 'Juneteenth'),
('2025-07-04', FALSE, 'Independence Day'),
('2025-09-01', FALSE, 'Labor Day'),
('2025-11-27', FALSE, 'Thanksgiving Day'),
('2025-12-25', FALSE, 'Christmas Day');
