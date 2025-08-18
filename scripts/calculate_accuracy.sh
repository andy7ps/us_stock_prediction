#!/bin/bash

# Calculate Accuracy Script for Stock Prediction Service v3.4.0
# Calculates and displays accuracy metrics for predictions
# Author: Stock Prediction Service Development Team
# Created: 2025-08-18

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/calculate_accuracy_$(date +%Y%m%d).log"
API_BASE_URL="${API_BASE_URL:-http://localhost:8081}"

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
    if curl -s -f "$API_BASE_URL/api/v1/health" > /dev/null 2>&1; then
        log_info "Service health check passed"
        return 0
    else
        log_error "Service health check failed"
        return 1
    fi
}

# Function to get overall performance metrics
get_overall_performance() {
    # Log to file only, not stdout (to avoid interfering with return value)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: Fetching overall performance metrics" >> "$LOG_FILE"
    
    local response
    response=$(curl -s "$API_BASE_URL/api/v1/predictions/performance" 2>/dev/null || echo "")
    
    if [ -z "$response" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to get overall performance metrics" >> "$LOG_FILE"
        return 1
    fi
    
    echo "$response"
    return 0
}

# Function to get accuracy summary for a specific symbol
get_symbol_accuracy() {
    local symbol="$1"
    
    # Log to file only, not stdout
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: Fetching accuracy summary for $symbol" >> "$LOG_FILE"
    
    local response
    response=$(curl -s "$API_BASE_URL/api/v1/predictions/accuracy/$symbol" 2>/dev/null || echo "")
    
    if [ -z "$response" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to get accuracy summary for $symbol" >> "$LOG_FILE"
        return 1
    fi
    
    echo "$response"
    return 0
}

# Function to display performance metrics in a readable format
display_performance_metrics() {
    local metrics="$1"
    
    if command -v jq &> /dev/null; then
        echo "=== OVERALL PERFORMANCE METRICS ==="
        echo "Total Symbols: $(echo "$metrics" | jq -r '.total_symbols // "N/A"')"
        echo "Total Predictions: $(echo "$metrics" | jq -r '.total_predictions // "N/A"')"
        echo "Predictions with Actual Data: $(echo "$metrics" | jq -r '.predictions_with_actual // "N/A"')"
        echo "Overall Accuracy (MAPE): $(echo "$metrics" | jq -r '.overall_accuracy_mape // "N/A"')%"
        echo "Overall Direction Accuracy: $(echo "$metrics" | jq -r '.overall_direction_accuracy // "N/A"')%"
        echo "Last Execution Date: $(echo "$metrics" | jq -r '.last_execution_date // "N/A"')"
        echo "Last Execution Status: $(echo "$metrics" | jq -r '.last_execution_status // "N/A"')"
        echo ""
        
        echo "=== SYMBOL SUMMARIES ==="
        echo "$metrics" | jq -r '.symbol_summaries[]? | 
            "Symbol: \(.symbol)
            Total Predictions: \(.total_predictions)
            Predictions with Actual: \(.predictions_with_actual)
            Average MAPE: \(.average_accuracy_mape)%
            Direction Accuracy: \(.direction_accuracy)%
            Average Confidence: \(.average_confidence)
            Best Accuracy: \(.best_accuracy)%
            Worst Accuracy: \(.worst_accuracy)%
            Last Prediction: \(.last_prediction_date // "N/A")
            "'
    else
        echo "=== PERFORMANCE METRICS (Raw JSON) ==="
        echo "$metrics" | python3 -m json.tool 2>/dev/null || echo "$metrics"
    fi
}

# Function to display symbol accuracy in a readable format
display_symbol_accuracy() {
    local symbol="$1"
    local accuracy="$2"
    
    if command -v jq &> /dev/null; then
        echo "=== ACCURACY SUMMARY FOR $symbol ==="
        echo "Total Predictions: $(echo "$accuracy" | jq -r '.total_predictions // "N/A"')"
        echo "Predictions with Actual Data: $(echo "$accuracy" | jq -r '.predictions_with_actual // "N/A"')"
        echo "Average MAPE: $(echo "$accuracy" | jq -r '.average_accuracy_mape // "N/A"')%"
        echo "Direction Accuracy: $(echo "$accuracy" | jq -r '.direction_accuracy // "N/A"')%"
        echo "Average Confidence: $(echo "$accuracy" | jq -r '.average_confidence // "N/A"')"
        echo "Best Accuracy: $(echo "$accuracy" | jq -r '.best_accuracy // "N/A"')%"
        echo "Worst Accuracy: $(echo "$accuracy" | jq -r '.worst_accuracy // "N/A"')%"
        echo "Last Prediction Date: $(echo "$accuracy" | jq -r '.last_prediction_date // "N/A"')"
        echo ""
    else
        echo "=== ACCURACY SUMMARY FOR $symbol (Raw JSON) ==="
        echo "$accuracy" | python3 -m json.tool 2>/dev/null || echo "$accuracy"
    fi
}

# Function to get top performing symbols
get_top_performers() {
    local limit="${1:-10}"
    
    # Log to file only, not stdout
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: Fetching top $limit performing symbols" >> "$LOG_FILE"
    
    local response
    response=$(curl -s "$API_BASE_URL/api/v1/predictions/top-performers?limit=$limit" 2>/dev/null || echo "")
    
    if [ -z "$response" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Failed to get top performers" >> "$LOG_FILE"
        return 1
    fi
    
    echo "$response"
    return 0
}

# Function to display top performers
display_top_performers() {
    local performers="$1"
    
    if command -v jq &> /dev/null; then
        echo "=== TOP PERFORMING SYMBOLS ==="
        echo "$performers" | jq -r '.[] | 
            "Rank: \(.rank // "N/A")
            Symbol: \(.symbol)
            Direction Accuracy: \(.direction_accuracy)%
            Average MAPE: \(.average_accuracy_mape)%
            Total Predictions: \(.total_predictions)
            Predictions with Actual: \(.predictions_with_actual)
            "'
    else
        echo "=== TOP PERFORMING SYMBOLS (Raw JSON) ==="
        echo "$performers" | python3 -m json.tool 2>/dev/null || echo "$performers"
    fi
}

# Function to run accuracy update process
run_accuracy_update() {
    log_info "Running accuracy update process"
    
    # First, update actual prices for recent predictions
    if [ -f "$SCRIPT_DIR/update_actual_prices.sh" ]; then
        log_info "Updating actual prices..."
        if "$SCRIPT_DIR/update_actual_prices.sh"; then
            log_success "Actual prices updated successfully"
        else
            log_error "Failed to update actual prices"
            return 1
        fi
    else
        log_error "update_actual_prices.sh not found"
        return 1
    fi
    
    # Small delay to allow database updates to complete
    sleep 2
    
    log_success "Accuracy update process completed"
    return 0
}

# Main execution function
main() {
    log_info "=== Calculate Accuracy Script Started ==="
    log_info "Timestamp: $(date)"
    log_info "API Base URL: $API_BASE_URL"
    
    # Check service health
    if ! check_service_health; then
        log_error "Service is not healthy, aborting"
        exit 1
    fi
    
    case "${1:-summary}" in
        "update")
            log_info "Running accuracy update process"
            if run_accuracy_update; then
                log_success "Accuracy update completed successfully"
            else
                log_error "Accuracy update failed"
                exit 1
            fi
            ;;
        "summary"|"")
            log_info "Displaying overall performance summary"
            if metrics=$(get_overall_performance); then
                display_performance_metrics "$metrics"
            else
                log_error "Failed to get performance metrics"
                exit 1
            fi
            ;;
        "symbol")
            if [ -z "${2:-}" ]; then
                log_error "Symbol required for symbol command"
                echo "Usage: $0 symbol SYMBOL_NAME"
                exit 1
            fi
            local symbol="$2"
            log_info "Displaying accuracy for symbol: $symbol"
            if accuracy=$(get_symbol_accuracy "$symbol"); then
                display_symbol_accuracy "$symbol" "$accuracy"
            else
                log_error "Failed to get accuracy for $symbol"
                exit 1
            fi
            ;;
        "top")
            local limit="${2:-10}"
            log_info "Displaying top $limit performers"
            if performers=$(get_top_performers "$limit"); then
                display_top_performers "$performers"
            else
                log_error "Failed to get top performers"
                exit 1
            fi
            ;;
        "all")
            log_info "Running comprehensive accuracy analysis"
            
            # Update actual prices first
            if run_accuracy_update; then
                log_success "Actual prices updated"
            else
                log_error "Failed to update actual prices"
            fi
            
            echo ""
            
            # Display overall metrics
            if metrics=$(get_overall_performance); then
                display_performance_metrics "$metrics"
            else
                log_error "Failed to get performance metrics"
            fi
            
            echo ""
            
            # Display top performers
            if performers=$(get_top_performers 5); then
                display_top_performers "$performers"
            else
                log_error "Failed to get top performers"
            fi
            ;;
        "range")
            if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
                log_error "Start date and end date required for range command"
                echo "Usage: $0 range START_DATE END_DATE [SYMBOLS]"
                echo "Example: $0 range 2025-08-10 2025-08-15 NVDA,TSLA"
                exit 1
            fi
            local start_date="$2"
            local end_date="$3"
            local symbols_filter="${4:-}"
            
            log_info "Displaying accuracy analysis for date range: $start_date to $end_date"
            
            # Use the dedicated range analysis script
            if [ -f "$SCRIPT_DIR/analyze_accuracy_range.sh" ]; then
                if [ -n "$symbols_filter" ]; then
                    "$SCRIPT_DIR/analyze_accuracy_range.sh" "$start_date" "$end_date" "$symbols_filter"
                else
                    "$SCRIPT_DIR/analyze_accuracy_range.sh" "$start_date" "$end_date"
                fi
            else
                log_error "Range analysis script not found: $SCRIPT_DIR/analyze_accuracy_range.sh"
                exit 1
            fi
            ;;
        "backfill")
            if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
                log_error "Start date and end date required for backfill command"
                echo "Usage: $0 backfill START_DATE END_DATE [SYMBOLS]"
                echo "Example: $0 backfill 2025-08-10 2025-08-15 NVDA,TSLA"
                exit 1
            fi
            local start_date="$2"
            local end_date="$3"
            local symbols_filter="${4:-}"
            
            log_info "Running backfill for date range: $start_date to $end_date"
            
            # Call the update range script
            local backfill_cmd="$SCRIPT_DIR/update_accuracy_range.sh"
            if [ -n "$symbols_filter" ]; then
                backfill_cmd="$backfill_cmd --symbols $symbols_filter"
            fi
            backfill_cmd="$backfill_cmd $start_date $end_date"
            
            if [ -f "$SCRIPT_DIR/update_accuracy_range.sh" ]; then
                log_info "Executing: $backfill_cmd"
                eval "$backfill_cmd"
                
                # Show updated results
                echo ""
                log_info "Backfill completed. Showing updated accuracy analysis:"
                echo ""
                main "range" "$start_date" "$end_date" "$symbols_filter"
            else
                log_error "update_accuracy_range.sh script not found"
                exit 1
            fi
            ;;
        "--help"|"-h")
            echo "Usage: $0 [COMMAND] [OPTIONS]"
            echo ""
            echo "Calculate and display accuracy metrics for stock predictions"
            echo ""
            echo "Commands:"
            echo "  summary              Display overall performance summary (default)"
            echo "  symbol SYMBOL        Display accuracy for specific symbol"
            echo "  top [N]              Display top N performing symbols (default: 10)"
            echo "  update               Update actual prices and recalculate accuracy"
            echo "  all                  Run comprehensive analysis (update + summary + top)"
            echo "  range START END [SYM] Display accuracy analysis for date range"
            echo "  backfill START END [SYM] Update actual prices for date range and show results"
            echo ""
            echo "Date Range Commands:"
            echo "  range 2025-08-10 2025-08-15           # Show accuracy for date range"
            echo "  range 2025-08-10 2025-08-15 NVDA,TSLA # Show accuracy for specific symbols"
            echo "  backfill 2025-08-10 2025-08-15        # Update prices and show results"
            echo ""
            echo "Environment Variables:"
            echo "  API_BASE_URL         Base URL for the API (default: http://localhost:8081)"
            echo ""
            echo "Examples:"
            echo "  $0                              # Show overall summary"
            echo "  $0 symbol NVDA                  # Show accuracy for NVDA"
            echo "  $0 top 5                        # Show top 5 performers"
            echo "  $0 update                       # Update actual prices"
            echo "  $0 all                          # Comprehensive analysis"
            echo "  $0 range 2025-08-10 2025-08-15 # Date range analysis"
            echo "  $0 backfill 2025-08-01 2025-08-31 # Backfill entire month"
            exit 0
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 --help' for usage information"
            exit 1
            ;;
    esac
    
    log_info "=== Calculate Accuracy Script Completed ==="
}

# Execute main function with all arguments
main "$@"
