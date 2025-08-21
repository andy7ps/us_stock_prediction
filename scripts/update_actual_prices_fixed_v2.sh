#!/bin/bash

# Update Actual Prices Script for Stock Prediction Service v3.4.0 - FIXED VERSION v2
# Fetches actual closing prices and updates accuracy tracking
# Author: Stock Prediction Service Development Team
# Created: 2025-08-18
# Fixed: 2025-08-21

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/update_actual_prices_$(date +%Y%m%d_%H%M%S).log"
API_BASE_URL="${API_BASE_URL:-http://localhost:8081}"
SYMBOLS="${SYMBOLS:-NVDA,TSLA,AAPL,MSFT,GOOGL,AMZN,AUR,PLTR,SMCI,TSM,MP,SMR,SPY,META,NOC,RTX,LMT}"
MAX_RETRIES=3
RETRY_DELAY=2

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Logging functions
log_info() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] INFO: $message" | tee -a "$LOG_FILE"
}

log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ERROR: $message" | tee -a "$LOG_FILE" >&2
}

log_success() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] SUCCESS: $message" | tee -a "$LOG_FILE"
}

# Function to get actual closing price from historical data
get_actual_closing_price() {
    local symbol="$1"
    local date="$2"
    
    # Log to file only, not stdout (to avoid interfering with return value)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: Fetching actual closing price for $symbol on $date" >> "$LOG_FILE"
    
    # Get historical data for the specific date (get 10 days to ensure we have the data)
    local historical_response
    historical_response=$(curl -s "$API_BASE_URL/api/v1/historical/$symbol?days=10" 2>/dev/null || echo "")
    
    if [ -z "$historical_response" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to get historical data for $symbol" >> "$LOG_FILE"
        return 1
    fi
    
    # Parse JSON to extract closing price for the specific date
    local closing_price=""
    
    if command -v jq &> /dev/null; then
        # Use jq for robust JSON parsing - match date from timestamp
        closing_price=$(echo "$historical_response" | jq -r --arg date "$date" '
            .[] | select(.timestamp | startswith($date)) | .close
        ' | head -1)
    else
        # Fallback parsing without jq
        closing_price=$(echo "$historical_response" | grep -o "\"timestamp\":\"$date[^\"]*\"[^}]*\"close\":[0-9.]*" | grep -o '"close":[0-9.]*' | cut -d':' -f2 | head -1)
    fi
    
    if [ -z "$closing_price" ] || [ "$closing_price" = "null" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: No closing price found for $symbol on $date" >> "$LOG_FILE"
        return 1
    fi
    
    # Log success to file only
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: Found closing price for $symbol on $date: \$${closing_price}" >> "$LOG_FILE"
    
    # Return the price (stdout only, no logging mixed in)
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
    
    # Extract HTTP code (last 3 characters)
    http_code="${response: -3}"
    response="${response%???}"
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        log_success "Successfully updated actual price for $symbol on $date"
        return 0
    else
        log_error "Failed to update actual price for $symbol on $date (HTTP $http_code): $response"
        return 1
    fi
}

# Function to check if predictions exist for a date and symbol
check_prediction_exists() {
    local symbol="$1"
    local date="$2"
    
    # Get predictions for the specific date and symbol
    local response
    response=$(curl -s "$API_BASE_URL/api/v1/predictions/history?limit=100" 2>/dev/null || echo "")
    
    if [ -z "$response" ]; then
        return 1
    fi
    
    # Check if prediction exists for this symbol and date
    local exists=""
    if command -v jq &> /dev/null; then
        exists=$(echo "$response" | jq -r --arg symbol "$symbol" --arg date "$date" '
            .[] | select(.symbol == $symbol and (.prediction_date | startswith($date))) | .id
        ' | head -1)
    else
        # Fallback parsing
        exists=$(echo "$response" | grep -o "\"symbol\":\"$symbol\"[^}]*\"prediction_date\":\"$date[^}]*\"id\":[0-9]*" | head -1)
    fi
    
    [ -n "$exists" ] && [ "$exists" != "null" ]
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
    
    # Get predictions that exist for this date
    local predictions_response
    predictions_response=$(curl -s "$API_BASE_URL/api/v1/predictions/history?limit=200" 2>/dev/null || echo "")
    
    if [ -z "$predictions_response" ]; then
        log_error "Failed to get predictions data"
        return 1
    fi
    
    # Count predictions for this date
    local predictions_count=0
    if command -v jq &> /dev/null; then
        predictions_count=$(echo "$predictions_response" | jq -r --arg date "$target_date" '
            [.[] | select(.prediction_date | startswith($date))] | length
        ')
    fi
    
    log_info "Found $predictions_count predictions for $target_date"
    
    # Process each symbol
    for symbol in "${symbols_array[@]}"; do
        log_info "Processing $symbol..."
        
        # Check if prediction exists for this symbol and date
        if ! check_prediction_exists "$symbol" "$target_date"; then
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

# Function to check service health
check_service_health() {
    local retries=0
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if curl -s "$API_BASE_URL/api/v1/health" > /dev/null 2>&1; then
            log_info "Service health check passed"
            return 0
        fi
        
        retries=$((retries + 1))
        if [ $retries -lt $MAX_RETRIES ]; then
            log_info "Service health check failed, retrying in ${RETRY_DELAY}s... (attempt $retries/$MAX_RETRIES)"
            sleep $RETRY_DELAY
        fi
    done
    
    log_error "Service health check failed after $MAX_RETRIES attempts"
    return 1
}

# Main execution
main() {
    log_info "=== Update Actual Prices Script Started (FIXED VERSION v2) ==="
    log_info "Timestamp: $(date)"
    log_info "API Base URL: $API_BASE_URL"
    log_info "Symbols: $SYMBOLS"
    log_info "Log File: $LOG_FILE"
    
    # Check service health
    if ! check_service_health; then
        log_error "Cannot proceed without healthy service"
        exit 1
    fi
    
    # Determine which dates need updates
    local target_date="${1:-}"
    
    if [ -z "$target_date" ]; then
        log_error "Please provide a target date (YYYY-MM-DD)"
        log_info "Usage: $0 <date>"
        log_info "Example: $0 2025-08-20"
        exit 1
    fi
    
    # Validate provided date format
    if ! date -d "$target_date" +%Y-%m-%d > /dev/null 2>&1; then
        log_error "Invalid date format: $target_date (use YYYY-MM-DD)"
        exit 1
    fi
    target_date=$(date -d "$target_date" +%Y-%m-%d)
    log_info "Using provided target date: $target_date"
    
    # Update actual prices for the specified date
    if update_actual_prices_for_date "$target_date"; then
        log_success "Actual price updates completed successfully"
    else
        log_error "Actual price updates completed with errors"
        exit 1
    fi
    
    log_info "=== Update Actual Prices Script Completed ==="
}

# Run main function with all arguments
main "$@"
