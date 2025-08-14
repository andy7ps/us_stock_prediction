#!/bin/bash

# Daily Prediction Script for Stock Prediction Service v3.4.0
# Executes daily predictions at 9:00 AM Taipei time (1:00 AM UTC)
# Author: Stock Prediction Service Development Team
# Created: 2024-08-14

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/daily_prediction_$(date +%Y%m%d).log"
API_BASE_URL="${API_BASE_URL:-http://localhost:8081}"
SYMBOLS="${DAILY_PREDICTION_SYMBOLS:-NVDA,TSLA,AAPL,MSFT,GOOGL,AMZN,AUR,PLTR,SMCI,TSM,MP,SMR,SPY,META,NOC,RTX,LMT}"
FORCE_EXECUTE="${FORCE_EXECUTE:-false}"
MAX_RETRIES=3
RETRY_DELAY=30

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
        log_error "Service health check failed (attempt $retries/$MAX_RETRIES)"
        
        if [ $retries -lt $MAX_RETRIES ]; then
            log_info "Waiting $RETRY_DELAY seconds before retry..."
            sleep $RETRY_DELAY
        fi
    done
    
    log_error "Service is not healthy after $MAX_RETRIES attempts"
    return 1
}

# Function to execute daily predictions
execute_daily_predictions() {
    log_info "Starting daily prediction execution"
    
    # Convert comma-separated symbols to JSON array
    local symbols_json="["
    IFS=',' read -ra SYMBOL_ARRAY <<< "$SYMBOLS"
    for i in "${!SYMBOL_ARRAY[@]}"; do
        if [ $i -gt 0 ]; then
            symbols_json+=","
        fi
        symbols_json+="\"${SYMBOL_ARRAY[i]}\""
    done
    symbols_json+="]"
    
    # Prepare request payload
    local request_payload=$(cat <<EOF
{
    "symbols": $symbols_json,
    "execution_type": "auto",
    "force_execute": $FORCE_EXECUTE
}
EOF
)
    
    log_info "Request payload: $request_payload"
    
    # Execute predictions with retries
    local retries=0
    while [ $retries -lt $MAX_RETRIES ]; do
        log_info "Executing daily predictions (attempt $((retries + 1))/$MAX_RETRIES)"
        
        local response
        local http_code
        
        response=$(curl -s -w "\n%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -d "$request_payload" \
            "$API_BASE_URL/api/v1/predictions/daily-run" 2>&1)
        
        http_code=$(echo "$response" | tail -n1)
        response_body=$(echo "$response" | head -n -1)
        
        if [ "$http_code" = "200" ]; then
            log_success "Daily predictions executed successfully"
            log_info "Response: $response_body"
            
            # Parse and log execution summary
            parse_execution_summary "$response_body"
            return 0
        else
            retries=$((retries + 1))
            log_error "Daily prediction execution failed with HTTP code: $http_code"
            log_error "Response: $response_body"
            
            if [ $retries -lt $MAX_RETRIES ]; then
                log_info "Waiting $RETRY_DELAY seconds before retry..."
                sleep $RETRY_DELAY
            fi
        fi
    done
    
    log_error "Daily prediction execution failed after $MAX_RETRIES attempts"
    return 1
}

# Function to parse and log execution summary
parse_execution_summary() {
    local response="$1"
    
    # Extract key information using basic text processing
    # In a production environment, you might want to use jq for JSON parsing
    
    if echo "$response" | grep -q '"status":"completed"'; then
        log_success "Execution completed successfully"
    elif echo "$response" | grep -q '"status":"failed"'; then
        log_error "Execution failed"
    fi
    
    # Try to extract symbol counts
    local total_symbols=$(echo "$response" | grep -o '"total_symbols":[0-9]*' | cut -d':' -f2 || echo "unknown")
    local successful=$(echo "$response" | grep -o '"successful_predictions":[0-9]*' | cut -d':' -f2 || echo "unknown")
    local failed=$(echo "$response" | grep -o '"failed_predictions":[0-9]*' | cut -d':' -f2 || echo "unknown")
    
    log_info "Execution Summary:"
    log_info "  Total symbols: $total_symbols"
    log_info "  Successful predictions: $successful"
    log_info "  Failed predictions: $failed"
    
    # Extract execution duration if available
    local duration=$(echo "$response" | grep -o '"execution_duration_ms":[0-9]*' | cut -d':' -f2 || echo "unknown")
    if [ "$duration" != "unknown" ]; then
        log_info "  Execution duration: ${duration}ms"
    fi
}

# Function to update actual closing prices for previous predictions
update_actual_prices() {
    log_info "Checking for actual closing prices to update"
    
    # Get yesterday's date
    local yesterday=$(date -d "yesterday" +%Y-%m-%d)
    
    # For each symbol, try to get the actual closing price and update
    IFS=',' read -ra SYMBOL_ARRAY <<< "$SYMBOLS"
    for symbol in "${SYMBOL_ARRAY[@]}"; do
        update_actual_price_for_symbol "$symbol" "$yesterday"
    done
}

# Function to update actual price for a specific symbol
update_actual_price_for_symbol() {
    local symbol="$1"
    local date="$2"
    
    log_info "Attempting to update actual price for $symbol on $date"
    
    # Get historical data to find the closing price
    local historical_response
    historical_response=$(curl -s "$API_BASE_URL/api/v1/historical/$symbol?days=2" 2>/dev/null || echo "")
    
    if [ -z "$historical_response" ]; then
        log_error "Failed to get historical data for $symbol"
        return 1
    fi
    
    # This is a simplified approach - in production, you'd want more robust JSON parsing
    # For now, we'll skip the actual price update and just log the attempt
    log_info "Historical data retrieved for $symbol (actual price update logic would go here)"
}

# Function to send notification (placeholder)
send_notification() {
    local status="$1"
    local message="$2"
    
    # Placeholder for notification logic (email, Slack, etc.)
    log_info "Notification: [$status] $message"
    
    # If email notifications are configured, send them here
    if [ -n "${NOTIFICATION_EMAIL:-}" ]; then
        echo "$message" | mail -s "Daily Prediction $status" "$NOTIFICATION_EMAIL" 2>/dev/null || true
    fi
}

# Function to cleanup old log files
cleanup_old_logs() {
    log_info "Cleaning up old log files"
    
    # Keep logs for 30 days
    find "$LOG_DIR" -name "daily_prediction_*.log" -mtime +30 -delete 2>/dev/null || true
    
    log_info "Log cleanup completed"
}

# Main execution function
main() {
    log_info "=== Daily Prediction Script Started ==="
    log_info "Timestamp: $(date)"
    log_info "Timezone: $(date +%Z)"
    log_info "API Base URL: $API_BASE_URL"
    log_info "Symbols: $SYMBOLS"
    log_info "Force Execute: $FORCE_EXECUTE"
    
    # Check if running in Docker container
    if [ -f /.dockerenv ]; then
        log_info "Running inside Docker container"
    else
        log_info "Running on host system"
    fi
    
    # Cleanup old logs first
    cleanup_old_logs
    
    # Check service health
    if ! check_service_health; then
        send_notification "FAILED" "Daily prediction failed: Service is not healthy"
        exit 1
    fi
    
    # Update actual prices from previous predictions
    update_actual_prices
    
    # Execute daily predictions
    if execute_daily_predictions; then
        log_success "Daily prediction execution completed successfully"
        send_notification "SUCCESS" "Daily predictions executed successfully"
    else
        log_error "Daily prediction execution failed"
        send_notification "FAILED" "Daily prediction execution failed"
        exit 1
    fi
    
    log_info "=== Daily Prediction Script Completed ==="
}

# Handle script interruption
trap 'log_error "Script interrupted"; exit 1' INT TERM

# Execute main function
main "$@"
