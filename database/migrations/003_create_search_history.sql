-- Migration: Create search history table
-- Created: 2025-08-21
-- Purpose: Store user search history for symbol lookup

CREATE TABLE IF NOT EXISTS search_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol VARCHAR(10) NOT NULL,
    search_count INTEGER DEFAULT 1,
    last_searched_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes for performance
    UNIQUE(symbol)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_search_history_symbol ON search_history(symbol);
CREATE INDEX IF NOT EXISTS idx_search_history_last_searched ON search_history(last_searched_at DESC);
CREATE INDEX IF NOT EXISTS idx_search_history_count ON search_history(search_count DESC);

-- Insert popular stocks as initial data
INSERT OR IGNORE INTO search_history (symbol, search_count, last_searched_at) VALUES
('NVDA', 100, datetime('now')),
('TSLA', 95, datetime('now')),
('AAPL', 90, datetime('now')),
('MSFT', 85, datetime('now')),
('GOOGL', 80, datetime('now')),
('AMZN', 75, datetime('now')),
('SPY', 70, datetime('now')),
('QQQ', 65, datetime('now')),
('META', 60, datetime('now')),
('NFLX', 55, datetime('now'));
