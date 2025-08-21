#!/bin/bash

# Update Actual Prices Script for Stock Prediction Service v3.4.0 - FIXED VERSION
# Fetches actual closing prices and updates accuracy tracking
# Author: Stock Prediction Service Development Team
# Created: 2025-08-18
# Fixed: 2025-08-18

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/update_actual_prices_$(date +%Y%m%d_%H%M%S).log"
API_BASE_URL="${API_BASE_URL:-http://localhost:8081}"
SYMBOLS="${SYMBOLS:-NVDA,TSLA,AAPL,MSFT,GOOGL,AMZN,AUR,PLTR,SMCI,TSM,MP,SMR,SPY,META,NOC,RTX,LMT}"
MAX_RETRIES=3
RETRY_DELAY=5

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

# Function to check if the service is healthy
check_service_health() {
    local retries=0
    while [ $retries -lt $MAX_RETRIES ]; do
        if curl -s -f "$API_BASE_URL/api/v1/health" > /dev/null 2>&1; then
            log_info "Service health check passed"
            return 0
        fi
        
        retries=$((retries + 1))
        if [ $retries -lt $MAX_RETRIES ]; then
            log_info "Health check failed, retrying in $RETRY_DELAY seconds... (attempt $retries/$MAX_RETRIES)"
            sleep $RETRY_DELAY
        fi
    done
    
    log_error "Service health check failed after $MAX_RETRIES attempts"
    return 1
}

# Function to get actual closing price from historical data
get_actual_closing_price() {
    local symbol="$1"
    local date="$2"
    
    log_info "Fetching actual closing price for $symbol on $date"
    
    # Get historical data for the specific date (get 10 days to ensure we have the data)
    local historical_response
    historical_response=$(curl -s "$API_BASE_URL/api/v1/historical/$symbol?days=10" 2>/dev/null || echo "")
    
    if [ -z "$historical_response" ]; then
        log_error "Failed to get historical data for $symbol"
        return 1
    fi
    
    # Parse JSON to extract closing price for the specific date
    local closing_price=""
    
    if command -v jq &> /dev/null; then
        # Use jq for robust JSON parsing - match date from timestamp
        closing_price=$(echo "$historical_response" | jq -r --arg date "$date" '
            .data[]? | select(.timestamp | startswith($date)) | .close // empty
        ' 2>/dev/null | head -1)
    else
        # Fallback: simple text parsing - look for timestamp starting with the date
        closing_price=$(echo "$historical_response" | grep -o "\"timestamp\":\"$date[^\"]*\"[^}]*\"close\":[0-9.]*" | grep -o "\"close\":[0-9.]*" | cut -d: -f2 | tr -d '"' | head -1 || echo "")
    fi
    
    if [ -z "$closing_price" ] || [ "$closing_price" = "null" ]; then
        log_error "Could not extract closing price for $symbol on $date"
        return 1
    fi
    
    # Validate that closing_price is a valid number
    if ! [[ "$closing_price" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        log_error "Invalid closing price format for $symbol on $date: $closing_price"
        return 1
    fi
    
    log_info "Found closing price for $symbol on $date: \$${closing_price}"
    echo "$closing_price"
    return 0
}

# Function to update actual price via API
update_actual_price_api() {
    local symbol="$1"
    local date="$2"
    local actual_close="$3"
    
    log_info "Updating actual price for $symbol on $date: \$${actual_close}"
    
    # Prepare JSON payload - use printf to ensure proper number formatting
    local payload
    payload=$(printf '{"symbol":"%s","date":"%sT00:00:00Z","actual_close":%s}' "$symbol" "$date" "$actual_close")
    
    # Debug: log the payload being sent
    log_info "JSON payload: $payload"
    
    # Make API call to update actual price
    local response
    local http_code
    
    response=$(curl -s -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$API_BASE_URL/api/v1/predictions/update-actual" 2>/dev/null || echo "000")
    
    http_code="${response: -3}"
    response_body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        log_success "Successfully updated actual price for $symbol on $date"
        return 0
    else
        log_error "Failed to update actual price for $symbol on $date (HTTP $http_code): $response_body"
        return 1
    fi
}

# Function to get dates that have predictions but no actual prices
get_dates_needing_updates() {
    log_info "Checking for predictions that need actual price updates"
    
    # Get recent predictions that don't have actual prices
    local response
    response=$(curl -s "$API_BASE_URL/api/v1/predictions/history?limit=200&order_by=date&order_dir=desc" 2>/dev/null || echo "")
    
    if [ -z "$response" ]; then
        log_error "Failed to get prediction history"
        return 1
    fi
    
    # Extract unique dates that have predictions but no actual prices
    local dates_needing_updates=""
    
    if command -v jq &> /dev/null; then
        dates_needing_updates=$(echo "$response" | jq -r '.[] | select(.actual_close == null) | .prediction_date' | cut -d'T' -f1 | sort -u | head -5)
    else
        # Fallback parsing
        dates_needing_updates=$(echo "$response" | grep -o '"prediction_date":"[^"]*"' | grep -o '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' | sort -u | head -5)
    fi
    
    if [ -z "$dates_needing_updates" ]; then
        log_info "No predictions found that need actual price updates"
        return 1
    fi
    
    log_info "Found dates needing updates: $(echo "$dates_needing_updates" | tr '\n' ' ')"
    echo "$dates_needing_updates"
    return 0
}

# Function to update actual prices for a specific date
update_actual_prices_for_date() {
    local target_date="$1"
    local symbols_array
    IFS=',' read -ra symbols_array <<< "$SYMBOLS"
    
    local successful_updates=0
    local failed_updates=0
    
    log_info "Updating actual prices for date: $target_date"
    log_info "Symbols to process: ${#symbols_array[@]}"
    
    # First, check if this date has any predictions
    local predictions_exist
    predictions_exist=$(curl -s "$API_BASE_URL/api/v1/predictions/history?limit=100" | jq -r --arg date "$target_date" '[.[] | select(.prediction_date | startswith($date))] | length' 2>/dev/null || echo "0")
    
    if [ "$predictions_exist" = "0" ]; then
        log_info "No predictions found for $target_date, skipping"
        return 0
    fi
    
    log_info "Found $predictions_exist predictions for $target_date"
    
    for symbol in "${symbols_array[@]}"; do
        symbol=$(echo "$symbol" | xargs) # Trim whitespace
        
        log_info "Processing $symbol..."
        
        # Check if this symbol has a prediction for this date
        local has_prediction
        has_prediction=$(curl -s "$API_BASE_URL/api/v1/predictions/history/$symbol?limit=10" | jq -r --arg date "$target_date" '[.[] | select(.prediction_date | startswith($date))] | length' 2>/dev/null || echo "0")
        
        if [ "$has_prediction" = "0" ]; then
            log_info "No prediction found for $symbol on $target_date, skipping"
            continue
        fi
        
        # Get actual closing price
        local actual_close
        if actual_close=$(get_actual_closing_price "$symbol" "$target_date"); then
            # Update via API
            if update_actual_price_api "$symbol" "$target_date" "$actual_close"; then
                successful_updates=$((successful_updates + 1))
            else
                failed_updates=$((failed_updates + 1))
            fi
        else
            log_error "Skipping $symbol due to data retrieval failure"
            failed_updates=$((failed_updates + 1))
        fi
        
        # Small delay to avoid overwhelming the API
        sleep 1
    done
    
    log_info "Update summary for $target_date:"
    log_info "  Successful updates: $successful_updates"
    log_info "  Failed updates: $failed_updates"
    log_info "  Total symbols processed: ${#symbols_array[@]}"
    
    return 0
}

# Main execution function
main() {
    log_info "=== Update Actual Prices Script Started (FIXED VERSION) ==="
    log_info "Timestamp: $(date)"
    log_info "API Base URL: $API_BASE_URL"
    log_info "Symbols: $SYMBOLS"
    log_info "Log File: $LOG_FILE"
    
    # Check service health
    if ! check_service_health; then
        log_error "Service is not healthy, aborting"
        exit 1
    fi
    
    # Determine which dates need updates
    local target_date="${1:-}"
    
    if [ -z "$target_date" ]; then
        # Auto-detect dates that need updates
        local dates_needing_updates
        if dates_needing_updates=$(get_dates_needing_updates); then
            log_info "Auto-detected dates needing updates"
            
            # Process each date
            local total_successful=0
            local total_failed=0
            
            while IFS= read -r date; do
                if [ -n "$date" ]; then
                    log_info "Processing date: $date"
                    update_actual_prices_for_date "$date"
                fi
            done <<< "$dates_needing_updates"
            
        else
            log_info "No dates found that need actual price updates"
            exit 0
        fi
    else
        # Validate provided date format
        if ! date -d "$target_date" +%Y-%m-%d > /dev/null 2>&1; then
            log_error "Invalid date format: $target_date (use YYYY-MM-DD)"
            exit 1
        fi
        target_date=$(date -d "$target_date" +%Y-%m-%d)
        log_info "Using provided target date: $target_date"
        
        # Update actual prices for the specified date
        update_actual_prices_for_date "$target_date"
    fi
    
    log_success "Actual price updates completed successfully"
    log_info "=== Update Actual Prices Script Completed ==="
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [DATE]"
        echo ""
        echo "Update actual closing prices for stock predictions"
        echo ""
        echo "Arguments:"
        echo "  DATE    Target date in YYYY-MM-DD format (optional, auto-detects if not provided)"
        echo ""
        echo "Environment Variables:"
        echo "  API_BASE_URL    Base URL for the API (default: http://localhost:8081)"
        echo "  SYMBOLS         Comma-separated list of symbols to process"
        echo ""
        echo "Examples:"
        echo "  $0                    # Update prices for all dates needing updates"
        echo "  $0 2025-08-18         # Update prices for specific date"
        echo "  SYMBOLS=NVDA,TSLA $0  # Update prices for specific symbols only"
        exit 0
        ;;
    --test)
        # Test mode - just check one symbol
        SYMBOLS="NVDA"
        log_info "Running in test mode with symbol: $SYMBOLS"
        main "${2:-}"
        ;;
    *)
        main "$@"
        ;;
esac
