#!/bin/bash

# Date Range Accuracy Update Script for Stock Prediction Service v3.4.0
# Updates actual closing prices and accuracy data for a specified date range
# Author: Stock Prediction Service Development Team
# Created: 2025-08-18

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/update_accuracy_range_$(date +%Y%m%d_%H%M%S).log"
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

log_warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" | tee -a "$LOG_FILE"
}

# Function to validate date format
validate_date() {
    local date_str="$1"
    if ! date -d "$date_str" +%Y-%m-%d > /dev/null 2>&1; then
        log_error "Invalid date format: $date_str (use YYYY-MM-DD)"
        return 1
    fi
    return 0
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
    # The API returns timestamp in format "2025-08-15T13:30:00Z", we need to match the date part
    local closing_price=""
    
    if command -v jq &> /dev/null; then
        # Use jq for robust JSON parsing - match date from timestamp
        closing_price=$(echo "$historical_response" | jq -r --arg date "$date" '
            .data[] | select(.timestamp | startswith($date)) | .close // empty
        ' 2>/dev/null || echo "")
    else
        # Fallback: simple text parsing - look for timestamp starting with the date
        closing_price=$(echo "$historical_response" | grep -o "\"timestamp\":\"$date[^\"]*\"[^}]*\"close\":[0-9.]*" | grep -o "\"close\":[0-9.]*" | cut -d: -f2 | tr -d '"' || echo "")
    fi
    
    if [ -z "$closing_price" ] || [ "$closing_price" = "null" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: No closing price found for $symbol on $date (market may have been closed)" >> "$LOG_FILE"
        return 1
    fi
    
    # Validate that closing_price is a valid number
    if ! [[ "$closing_price" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Invalid closing price format for $symbol on $date: $closing_price" >> "$LOG_FILE"
        return 1
    fi
    
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

# Function to check if predictions exist for a date
check_predictions_exist() {
    local date="$1"
    
    # Query the database to see if there are predictions for this date
    if [ -f "$PROJECT_ROOT/database_data/predictions.db" ]; then
        local count
        count=$(sqlite3 "$PROJECT_ROOT/database_data/predictions.db" "SELECT COUNT(*) FROM prediction_tracking WHERE prediction_date='$date';" 2>/dev/null || echo "0")
        
        if [ "$count" -gt 0 ]; then
            log_info "Found $count predictions for $date"
            return 0
        else
            log_warning "No predictions found for $date"
            return 1
        fi
    else
        log_error "Database file not found: $PROJECT_ROOT/database_data/predictions.db"
        return 1
    fi
}

# Function to get list of symbols that have predictions for a date
get_symbols_with_predictions() {
    local date="$1"
    
    if [ -f "$PROJECT_ROOT/database_data/predictions.db" ]; then
        sqlite3 "$PROJECT_ROOT/database_data/predictions.db" "SELECT symbol FROM prediction_tracking WHERE prediction_date='$date';" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Function to generate date range
generate_date_range() {
    local start_date="$1"
    local end_date="$2"
    
    local current_date="$start_date"
    local dates=()
    
    # Convert dates to seconds for comparison
    local start_seconds end_seconds current_seconds
    start_seconds=$(date -d "$start_date" +%s)
    end_seconds=$(date -d "$end_date" +%s)
    current_seconds=$start_seconds
    
    while [ "$current_seconds" -le "$end_seconds" ]; do
        current_date=$(date -d "@$current_seconds" +%Y-%m-%d)
        dates+=("$current_date")
        current_seconds=$((current_seconds + 86400)) # Add one day in seconds
    done
    
    printf '%s\n' "${dates[@]}"
}

# Function to update accuracy for a specific date
update_accuracy_for_date() {
    local target_date="$1"
    local symbols_filter="$2"
    local force_update="$3"
    
    log_info "Processing date: $target_date"
    
    # Check if predictions exist for this date
    if ! check_predictions_exist "$target_date"; then
        if [ "$force_update" = "false" ]; then
            log_warning "Skipping $target_date - no predictions found"
            return 0
        fi
    fi
    
    # Get symbols to process
    local symbols_to_process
    if [ -n "$symbols_filter" ]; then
        # Use provided symbols
        IFS=',' read -ra symbols_to_process <<< "$symbols_filter"
    else
        # Get symbols that have predictions for this date
        local db_symbols
        db_symbols=$(get_symbols_with_predictions "$target_date")
        if [ -n "$db_symbols" ]; then
            readarray -t symbols_to_process <<< "$db_symbols"
        else
            # Fallback to all symbols
            IFS=',' read -ra symbols_to_process <<< "$SYMBOLS"
        fi
    fi
    
    local successful_updates=0
    local failed_updates=0
    local skipped_updates=0
    
    log_info "Processing ${#symbols_to_process[@]} symbols for $target_date"
    
    for symbol in "${symbols_to_process[@]}"; do
        symbol=$(echo "$symbol" | xargs) # Trim whitespace
        
        if [ -z "$symbol" ]; then
            continue
        fi
        
        log_info "Processing $symbol for $target_date..."
        
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
            log_warning "Skipping $symbol for $target_date - no closing price data available"
            skipped_updates=$((skipped_updates + 1))
        fi
        
        # Small delay to avoid overwhelming the API
        sleep 0.5
    done
    
    log_info "Summary for $target_date:"
    log_info "  Successful updates: $successful_updates"
    log_info "  Failed updates: $failed_updates"
    log_info "  Skipped updates: $skipped_updates"
    log_info "  Total symbols processed: ${#symbols_to_process[@]}"
    
    return 0
}

# Function to display usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] START_DATE END_DATE

Update actual closing prices and accuracy data for a date range

Arguments:
  START_DATE    Start date in YYYY-MM-DD format
  END_DATE      End date in YYYY-MM-DD format

Options:
  --symbols SYMBOLS     Comma-separated list of symbols to process (default: all)
  --force              Force update even if no predictions exist for the date
  --dry-run            Show what would be processed without making changes
  --help, -h           Show this help message

Environment Variables:
  API_BASE_URL         Base URL for the API (default: http://localhost:8081)
  SYMBOLS              Default symbols to process

Examples:
  $0 2025-08-10 2025-08-15                    # Update all symbols for date range
  $0 --symbols NVDA,TSLA 2025-08-10 2025-08-15  # Update specific symbols
  $0 --force 2025-08-01 2025-08-31             # Force update entire month
  $0 --dry-run 2025-08-10 2025-08-15           # Preview what would be updated

Notes:
  - Only processes dates where predictions exist (unless --force is used)
  - Automatically skips weekends and holidays where market was closed
  - Creates detailed logs in logs/update_accuracy_range_*.log
  - Safe to run multiple times (idempotent operation)
EOF
}

# Main execution function
main() {
    local start_date=""
    local end_date=""
    local symbols_filter=""
    local force_update="false"
    local dry_run="false"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --symbols)
                symbols_filter="$2"
                shift 2
                ;;
            --force)
                force_update="true"
                shift
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$start_date" ]; then
                    start_date="$1"
                elif [ -z "$end_date" ]; then
                    end_date="$1"
                else
                    log_error "Too many arguments"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate required arguments
    if [ -z "$start_date" ] || [ -z "$end_date" ]; then
        log_error "Both START_DATE and END_DATE are required"
        show_usage
        exit 1
    fi
    
    # Validate date formats
    if ! validate_date "$start_date" || ! validate_date "$end_date"; then
        exit 1
    fi
    
    # Normalize dates
    start_date=$(date -d "$start_date" +%Y-%m-%d)
    end_date=$(date -d "$end_date" +%Y-%m-%d)
    
    # Validate date range
    local start_seconds end_seconds
    start_seconds=$(date -d "$start_date" +%s)
    end_seconds=$(date -d "$end_date" +%s)
    
    if [ "$start_seconds" -gt "$end_seconds" ]; then
        log_error "Start date ($start_date) must be before or equal to end date ($end_date)"
        exit 1
    fi
    
    log_info "=== Date Range Accuracy Update Started ==="
    log_info "Start Date: $start_date"
    log_info "End Date: $end_date"
    log_info "Symbols Filter: ${symbols_filter:-all symbols}"
    log_info "Force Update: $force_update"
    log_info "Dry Run: $dry_run"
    log_info "API Base URL: $API_BASE_URL"
    log_info "Log File: $LOG_FILE"
    
    # Check service health
    if ! check_service_health; then
        log_error "Service is not healthy, aborting"
        exit 1
    fi
    
    # Generate date range
    local dates
    readarray -t dates < <(generate_date_range "$start_date" "$end_date")
    
    log_info "Processing ${#dates[@]} dates from $start_date to $end_date"
    
    if [ "$dry_run" = "true" ]; then
        log_info "=== DRY RUN MODE - No changes will be made ==="
        for date in "${dates[@]}"; do
            log_info "Would process: $date"
            if check_predictions_exist "$date"; then
                local symbols_count
                symbols_count=$(get_symbols_with_predictions "$date" | wc -l)
                log_info "  Found predictions for $symbols_count symbols"
            else
                log_info "  No predictions found"
            fi
        done
        log_info "=== DRY RUN COMPLETED ==="
        return 0
    fi
    
    # Process each date
    local total_successful=0
    local total_failed=0
    local total_skipped=0
    local dates_processed=0
    
    for date in "${dates[@]}"; do
        update_accuracy_for_date "$date" "$symbols_filter" "$force_update"
        dates_processed=$((dates_processed + 1))
        
        # Progress indicator
        if [ $((dates_processed % 5)) -eq 0 ]; then
            log_info "Progress: $dates_processed/${#dates[@]} dates processed"
        fi
    done
    
    log_success "=== Date Range Accuracy Update Completed ==="
    log_info "Dates processed: $dates_processed"
    log_info "Total period: $start_date to $end_date"
    log_info "Log file: $LOG_FILE"
    
    # Show final summary
    log_info ""
    log_info "🎯 To view updated accuracy metrics, run:"
    log_info "   ./scripts/calculate_accuracy.sh summary"
    log_info ""
    log_info "📊 To see accuracy for specific symbols, run:"
    log_info "   ./scripts/calculate_accuracy.sh symbol NVDA"
    log_info ""
    log_info "📈 To see comprehensive analysis, run:"
    log_info "   ./scripts/calculate_accuracy.sh all"
}

# Execute main function with all arguments
main "$@"
