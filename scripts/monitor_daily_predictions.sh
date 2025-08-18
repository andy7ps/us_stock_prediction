#!/bin/bash

# Daily Prediction Monitoring Script
# Ensures no missing daily prediction data and generates missing predictions
# Author: Stock Prediction Service Development Team
# Created: 2025-08-18

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/monitor_daily_predictions_$(date +%Y%m%d_%H%M%S).log"
API_BASE_URL="${API_BASE_URL:-http://localhost:8081}"
SYMBOLS="${DAILY_PREDICTION_SYMBOLS:-NVDA,TSLA,AAPL,MSFT,GOOGL,AMZN,AUR,PLTR,SMCI,TSM,MP,SMR,SPY,META,NOC,RTX,LMT}"
LOOKBACK_DAYS=14

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

# Function to get trading days in the last N days
get_recent_trading_days() {
    local days_back="$1"
    local trading_days=()
    
    for ((i=0; i<days_back; i++)); do
        local check_date
        check_date=$(date -d "$i days ago" +%Y-%m-%d)
        
        if is_trading_day "$check_date"; then
            trading_days+=("$check_date")
        fi
    done
    
    printf '%s\n' "${trading_days[@]}"
}

# Function to check predictions for a specific date
check_predictions_for_date() {
    local date="$1"
    
    if [ -f "$PROJECT_ROOT/database_data/predictions.db" ]; then
        local count
        count=$(sqlite3 "$PROJECT_ROOT/database_data/predictions.db" "SELECT COUNT(*) FROM prediction_tracking WHERE prediction_date='$date';" 2>/dev/null || echo "0")
        echo "$count"
    else
        echo "0"
    fi
}

# Function to generate missing predictions for a date
generate_missing_predictions() {
    local target_date="$1"
    
    log_info "Generating missing predictions for $target_date"
    
    if [ -f "$SCRIPT_DIR/generate_today_predictions.sh" ]; then
        if "$SCRIPT_DIR/generate_today_predictions.sh" "$target_date" >> "$LOG_FILE" 2>&1; then
            log_success "Successfully generated predictions for $target_date"
            return 0
        else
            log_error "Failed to generate predictions for $target_date"
            return 1
        fi
    else
        log_error "Prediction generation script not found: $SCRIPT_DIR/generate_today_predictions.sh"
        return 1
    fi
}

# Function to check service health
check_service_health() {
    if curl -s -f "$API_BASE_URL/api/v1/health" > /dev/null 2>&1; then
        log_info "Service health check passed"
        return 0
    else
        log_error "Service health check failed"
        return 1
    fi
}

# Function to show prediction status
show_prediction_status() {
    local trading_days=("$@")
    
    log_info "📊 Current Prediction Status:"
    
    local total_expected_symbols
    total_expected_symbols=$(echo "$SYMBOLS" | tr ',' '\n' | wc -l)
    
    local complete_days=0
    local incomplete_days=0
    local missing_days=0
    
    for date in "${trading_days[@]}"; do
        local count
        count=$(check_predictions_for_date "$date")
        
        if [ "$count" -eq 0 ]; then
            log_warning "  $date: $count predictions (MISSING)"
            missing_days=$((missing_days + 1))
        elif [ "$count" -lt "$total_expected_symbols" ]; then
            log_warning "  $date: $count/$total_expected_symbols predictions (INCOMPLETE)"
            incomplete_days=$((incomplete_days + 1))
        else
            log_info "  $date: $count predictions (COMPLETE)"
            complete_days=$((complete_days + 1))
        fi
    done
    
    log_info ""
    log_info "📈 Summary:"
    log_info "  Complete days: $complete_days"
    log_info "  Incomplete days: $incomplete_days"
    log_info "  Missing days: $missing_days"
    log_info "  Total trading days checked: ${#trading_days[@]}"
}

# Function to fix missing predictions
fix_missing_predictions() {
    local trading_days=("$@")
    
    local total_expected_symbols
    total_expected_symbols=$(echo "$SYMBOLS" | tr ',' '\n' | wc -l)
    
    local fixed_days=0
    local failed_days=0
    
    for date in "${trading_days[@]}"; do
        local count
        count=$(check_predictions_for_date "$date")
        
        if [ "$count" -lt "$total_expected_symbols" ]; then
            log_info "Fixing predictions for $date (currently has $count/$total_expected_symbols)"
            
            if generate_missing_predictions "$date"; then
                local new_count
                new_count=$(check_predictions_for_date "$date")
                log_success "Fixed $date: now has $new_count predictions"
                fixed_days=$((fixed_days + 1))
            else
                log_error "Failed to fix predictions for $date"
                failed_days=$((failed_days + 1))
            fi
        fi
    done
    
    log_info ""
    log_info "🔧 Fix Summary:"
    log_info "  Days fixed: $fixed_days"
    log_info "  Days failed: $failed_days"
}

# Main execution function
main() {
    local action="${1:-monitor}"
    
    log_info "=== Daily Prediction Monitoring Started ==="
    log_info "Action: $action"
    log_info "Timestamp: $(date)"
    log_info "API Base URL: $API_BASE_URL"
    log_info "Symbols: $SYMBOLS"
    log_info "Lookback Days: $LOOKBACK_DAYS"
    log_info "Log File: $LOG_FILE"
    
    # Check service health
    if ! check_service_health; then
        log_error "Service is not healthy, aborting"
        exit 1
    fi
    
    # Get recent trading days
    local trading_days
    readarray -t trading_days < <(get_recent_trading_days "$LOOKBACK_DAYS")
    
    log_info "Found ${#trading_days[@]} trading days in the last $LOOKBACK_DAYS days"
    
    case "$action" in
        "monitor"|"status")
            show_prediction_status "${trading_days[@]}"
            ;;
        "fix"|"repair")
            log_info "=== Fixing Missing Predictions ==="
            fix_missing_predictions "${trading_days[@]}"
            echo ""
            log_info "=== Updated Status ==="
            show_prediction_status "${trading_days[@]}"
            ;;
        "today")
            local today
            today=$(date +%Y-%m-%d)
            
            if is_trading_day "$today"; then
                local today_count
                today_count=$(check_predictions_for_date "$today")
                
                if [ "$today_count" -eq 0 ]; then
                    log_info "Generating predictions for today ($today)"
                    generate_missing_predictions "$today"
                else
                    log_info "Today ($today) already has $today_count predictions"
                fi
            else
                log_info "Today ($today) is not a trading day"
            fi
            ;;
        *)
            echo "Usage: $0 [monitor|fix|today]"
            echo ""
            echo "Commands:"
            echo "  monitor  - Show prediction status (default)"
            echo "  fix      - Fix missing predictions for recent trading days"
            echo "  today    - Generate predictions for today if missing"
            echo ""
            echo "Examples:"
            echo "  $0                # Show status"
            echo "  $0 fix            # Fix all missing predictions"
            echo "  $0 today          # Generate today's predictions"
            exit 1
            ;;
    esac
    
    log_success "=== Daily Prediction Monitoring Completed ==="
    
    # Show next steps
    log_info ""
    log_info "🎯 Next steps:"
    log_info "   Check system status: ./system_status.sh"
    log_info "   View recent predictions: ./scripts/analyze_accuracy_range.sh $(date -d '7 days ago' +%Y-%m-%d) $(date +%Y-%m-%d)"
    log_info "   Update accuracy data: ./scripts/calculate_accuracy.sh backfill $(date -d '7 days ago' +%Y-%m-%d) $(date +%Y-%m-%d)"
    
    log_info "Log file: $LOG_FILE"
}

# Execute main function
main "$@"
