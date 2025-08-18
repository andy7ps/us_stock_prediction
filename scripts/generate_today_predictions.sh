#!/bin/bash

# Simple Daily Prediction Generator
# Generates predictions for today and stores them in the database
# Author: Stock Prediction Service Development Team
# Created: 2025-08-18

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/generate_today_predictions_$(date +%Y%m%d_%H%M%S).log"
API_BASE_URL="${API_BASE_URL:-http://localhost:8081}"
SYMBOLS="${DAILY_PREDICTION_SYMBOLS:-NVDA,TSLA,AAPL,MSFT,GOOGL,AMZN,AUR,PLTR,SMCI,TSM,MP,SMR,SPY,META,NOC,RTX,LMT}"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Logging functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" | tee -a "$LOG_FILE"
}

# Function to check if it's a trading day (Monday-Friday)
is_trading_day() {
    local date="$1"
    local day_of_week
    day_of_week=$(date -d "$date" +%u) # 1=Monday, 7=Sunday
    
    if [ "$day_of_week" -gt 5 ]; then
        return 1 # Weekend
    fi
    
    return 0 # Trading day
}

# Function to generate and store prediction for a symbol
generate_and_store_prediction() {
    local symbol="$1"
    local target_date="$2"
    
    log_info "Generating prediction for $symbol..."
    
    # Make prediction API call
    local response http_code
    response=$(curl -s -w "%{http_code}" "$API_BASE_URL/api/v1/predict/$symbol" 2>/dev/null || echo "000")
    http_code="${response: -3}"
    response_body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        # Parse the prediction response
        local predicted_price confidence direction
        
        if command -v jq &> /dev/null; then
            predicted_price=$(echo "$response_body" | jq -r '.predicted_price // empty' 2>/dev/null || echo "")
            confidence=$(echo "$response_body" | jq -r '.confidence // empty' 2>/dev/null || echo "")
            direction=$(echo "$response_body" | jq -r '.trading_signal // empty' 2>/dev/null || echo "")
        else
            # Fallback parsing without jq
            predicted_price=$(echo "$response_body" | grep -o '"predicted_price":[0-9.]*' | cut -d: -f2 || echo "")
            confidence=$(echo "$response_body" | grep -o '"confidence":[0-9.]*' | cut -d: -f2 || echo "")
            direction=$(echo "$response_body" | grep -o '"trading_signal":"[^"]*"' | cut -d: -f2 | tr -d '"' || echo "")
        fi
        
        # Convert trading signal to direction
        case "${direction,,}" in
            "buy") direction="up" ;;
            "sell") direction="down" ;;
            "hold") direction="hold" ;;
            *) direction="up" ;; # Default
        esac
        
        if [ -n "$predicted_price" ] && [ -n "$confidence" ]; then
            # Store in database
            if [ -f "$PROJECT_ROOT/database_data/predictions.db" ]; then
                sqlite3 "$PROJECT_ROOT/database_data/predictions.db" "
                    INSERT OR REPLACE INTO prediction_tracking 
                    (symbol, prediction_date, predicted_price, predicted_direction, confidence, market_was_open, created_at, updated_at)
                    VALUES 
                    ('$symbol', '$target_date', $predicted_price, '$direction', $confidence, 1, datetime('now'), datetime('now'));
                " 2>/dev/null && {
                    log_success "Stored prediction for $symbol: Price=\$${predicted_price}, Direction=${direction}, Confidence=${confidence}"
                    return 0
                } || {
                    log_error "Failed to store prediction for $symbol in database"
                    return 1
                }
            else
                log_error "Database not found"
                return 1
            fi
        else
            log_error "Invalid prediction response for $symbol: missing price or confidence"
            return 1
        fi
    else
        log_error "Failed to generate prediction for $symbol (HTTP $http_code): $response_body"
        return 1
    fi
}

# Main function
main() {
    local target_date="${1:-$(date +%Y-%m-%d)}"
    
    log_info "=== Simple Daily Prediction Generator Started ==="
    log_info "Target Date: $target_date"
    log_info "API Base URL: $API_BASE_URL"
    log_info "Symbols: $SYMBOLS"
    log_info "Log File: $LOG_FILE"
    
    # Check if it's a trading day
    if ! is_trading_day "$target_date"; then
        log_info "$target_date is not a trading day (weekend), skipping"
        exit 0
    fi
    
    # Check service health
    if ! curl -s -f "$API_BASE_URL/api/v1/health" > /dev/null 2>&1; then
        log_error "Service health check failed"
        exit 1
    fi
    
    log_info "Service health check passed"
    
    # Convert symbols string to array
    IFS=',' read -ra SYMBOL_ARRAY <<< "$SYMBOLS"
    
    local successful_predictions=0
    local failed_predictions=0
    
    # Generate predictions for each symbol
    for symbol in "${SYMBOL_ARRAY[@]}"; do
        symbol=$(echo "$symbol" | xargs) # Trim whitespace
        
        if [ -z "$symbol" ]; then
            continue
        fi
        
        if generate_and_store_prediction "$symbol" "$target_date"; then
            successful_predictions=$((successful_predictions + 1))
        else
            failed_predictions=$((failed_predictions + 1))
        fi
        
        # Small delay to avoid overwhelming the API
        sleep 0.3
    done
    
    # Summary
    log_info "=== Prediction Generation Summary ==="
    log_info "Target Date: $target_date"
    log_info "Successful predictions: $successful_predictions"
    log_info "Failed predictions: $failed_predictions"
    log_info "Total symbols processed: ${#SYMBOL_ARRAY[@]}"
    
    if [ "$successful_predictions" -gt 0 ]; then
        log_success "Successfully generated $successful_predictions predictions for $target_date"
        
        # Show what was stored
        if [ -f "$PROJECT_ROOT/database_data/predictions.db" ]; then
            local stored_count
            stored_count=$(sqlite3 "$PROJECT_ROOT/database_data/predictions.db" "SELECT COUNT(*) FROM prediction_tracking WHERE prediction_date='$target_date';" 2>/dev/null || echo "0")
            log_info "Total predictions now stored for $target_date: $stored_count"
        fi
    else
        log_error "No predictions were successfully generated"
        exit 1
    fi
    
    log_success "=== Simple Daily Prediction Generator Completed ==="
    log_info "Log file: $LOG_FILE"
}

# Execute main function
main "$@"
