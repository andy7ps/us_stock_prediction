#!/bin/bash

# Simple Date Range Accuracy Analysis Script
# Works directly with the database for fast analysis

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DB_PATH="$PROJECT_ROOT/database_data/predictions.db"

# Function to validate date format
validate_date() {
    local date_str="$1"
    if ! date -d "$date_str" +%Y-%m-%d > /dev/null 2>&1; then
        echo "ERROR: Invalid date format: $date_str (use YYYY-MM-DD)" >&2
        return 1
    fi
    return 0
}

# Function to analyze accuracy for date range
analyze_range() {
    local start_date="$1"
    local end_date="$2"
    local symbols_filter="$3"
    
    if [ ! -f "$DB_PATH" ]; then
        echo "ERROR: Database not found: $DB_PATH" >&2
        return 1
    fi
    
    echo "=== ACCURACY ANALYSIS FOR DATE RANGE ==="
    echo "Period: $start_date to $end_date"
    echo "Database: $DB_PATH"
    echo ""
    
    # Build WHERE clause for symbols
    local symbol_where=""
    if [ -n "$symbols_filter" ]; then
        # Convert comma-separated symbols to SQL IN clause
        local symbols_sql=$(echo "$symbols_filter" | sed "s/,/','/g" | sed "s/^/'/" | sed "s/$/'/")
        symbol_where="AND symbol IN ($symbols_sql)"
    fi
    
    # Get overall statistics
    local total_predictions
    total_predictions=$(sqlite3 "$DB_PATH" "
        SELECT COUNT(*) 
        FROM prediction_tracking 
        WHERE prediction_date BETWEEN '$start_date' AND '$end_date' 
        $symbol_where;
    " 2>/dev/null || echo "0")
    
    if [ "$total_predictions" -eq 0 ]; then
        echo "❌ No predictions found for the specified date range and symbols"
        echo ""
        echo "💡 Available dates in database:"
        sqlite3 "$DB_PATH" "SELECT DISTINCT prediction_date FROM prediction_tracking ORDER BY prediction_date DESC LIMIT 10;" 2>/dev/null || echo "No data available"
        return 0
    fi
    
    echo "📊 Found $total_predictions predictions in date range"
    echo ""
    
    # Get predictions with actual prices
    local with_actual
    with_actual=$(sqlite3 "$DB_PATH" "
        SELECT COUNT(*) 
        FROM prediction_tracking 
        WHERE prediction_date BETWEEN '$start_date' AND '$end_date' 
        AND actual_close IS NOT NULL 
        $symbol_where;
    " 2>/dev/null || echo "0")
    
    echo "📈 Predictions with actual prices: $with_actual ($((with_actual * 100 / total_predictions))%)"
    echo ""
    
    if [ "$with_actual" -gt 0 ]; then
        echo "=== SYMBOL PERFORMANCE ==="
        
        # Get per-symbol statistics
        sqlite3 "$DB_PATH" "
            SELECT 
                symbol,
                COUNT(*) as predictions,
                COUNT(CASE WHEN actual_close IS NOT NULL THEN 1 END) as with_actual,
                ROUND(AVG(CASE WHEN accuracy_mape IS NOT NULL THEN accuracy_mape END), 2) as avg_mape,
                ROUND(AVG(CASE WHEN direction_correct IS NOT NULL THEN CAST(direction_correct AS FLOAT) END) * 100, 1) as direction_accuracy,
                ROUND(AVG(confidence), 4) as avg_confidence,
                MIN(prediction_date) as first_date,
                MAX(prediction_date) as last_date
            FROM prediction_tracking 
            WHERE prediction_date BETWEEN '$start_date' AND '$end_date' 
            $symbol_where
            GROUP BY symbol 
            ORDER BY avg_mape ASC;
        " 2>/dev/null | while IFS='|' read -r symbol predictions with_actual avg_mape direction_accuracy avg_confidence first_date last_date; do
            echo "Symbol: $symbol"
            echo "  Predictions: $predictions (with actual: $with_actual)"
            echo "  Average MAPE: ${avg_mape:-N/A}%"
            echo "  Direction Accuracy: ${direction_accuracy:-N/A}%"
            echo "  Average Confidence: ${avg_confidence:-N/A}"
            echo "  Date Range: $first_date to $last_date"
            echo ""
        done
        
        echo "=== DAILY BREAKDOWN ==="
        
        # Get daily statistics
        sqlite3 "$DB_PATH" "
            SELECT 
                prediction_date,
                COUNT(*) as predictions,
                COUNT(CASE WHEN actual_close IS NOT NULL THEN 1 END) as with_actual,
                ROUND(AVG(CASE WHEN accuracy_mape IS NOT NULL THEN accuracy_mape END), 1) as avg_mape,
                GROUP_CONCAT(symbol, ', ') as symbols
            FROM prediction_tracking 
            WHERE prediction_date BETWEEN '$start_date' AND '$end_date' 
            $symbol_where
            GROUP BY prediction_date 
            ORDER BY prediction_date;
        " 2>/dev/null | while IFS='|' read -r date predictions with_actual avg_mape symbols; do
            echo "$date: $predictions predictions ($with_actual with actual), ${avg_mape:-N/A}% avg MAPE"
            echo "  Symbols: $symbols"
        done
        
        echo ""
        echo "=== OVERALL SUMMARY ==="
        
        # Get overall averages
        sqlite3 "$DB_PATH" "
            SELECT 
                ROUND(AVG(CASE WHEN accuracy_mape IS NOT NULL THEN accuracy_mape END), 2) as overall_mape,
                ROUND(AVG(CASE WHEN direction_correct IS NOT NULL THEN CAST(direction_correct AS FLOAT) END) * 100, 1) as overall_direction_accuracy,
                ROUND(AVG(confidence), 4) as overall_confidence,
                MIN(accuracy_mape) as best_mape,
                MAX(accuracy_mape) as worst_mape
            FROM prediction_tracking 
            WHERE prediction_date BETWEEN '$start_date' AND '$end_date' 
            AND actual_close IS NOT NULL
            $symbol_where;
        " 2>/dev/null | while IFS='|' read -r overall_mape overall_direction_accuracy overall_confidence best_mape worst_mape; do
            echo "Overall MAPE: ${overall_mape:-N/A}%"
            echo "Overall Direction Accuracy: ${overall_direction_accuracy:-N/A}%"
            echo "Overall Confidence: ${overall_confidence:-N/A}"
            echo "Best MAPE: ${best_mape:-N/A}%"
            echo "Worst MAPE: ${worst_mape:-N/A}%"
        done
    else
        echo "⚠️  No predictions have actual price data yet"
        echo ""
        echo "💡 To update actual prices for this range, run:"
        echo "   ./scripts/update_accuracy_range.sh $start_date $end_date"
    fi
}

# Main function
main() {
    local start_date=""
    local end_date=""
    local symbols_filter=""
    
    # Parse arguments
    case "${1:-}" in
        --help|-h)
            echo "Usage: $0 START_DATE END_DATE [SYMBOLS]"
            echo ""
            echo "Analyze prediction accuracy for a date range"
            echo ""
            echo "Arguments:"
            echo "  START_DATE    Start date in YYYY-MM-DD format"
            echo "  END_DATE      End date in YYYY-MM-DD format"
            echo "  SYMBOLS       Optional comma-separated list of symbols"
            echo ""
            echo "Examples:"
            echo "  $0 2025-08-10 2025-08-15"
            echo "  $0 2025-08-10 2025-08-15 NVDA,TSLA,AAPL"
            exit 0
            ;;
        "")
            echo "ERROR: START_DATE and END_DATE are required" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
    
    start_date="$1"
    end_date="$2"
    symbols_filter="${3:-}"
    
    # Validate dates
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
        echo "ERROR: Start date must be before or equal to end date" >&2
        exit 1
    fi
    
    # Run analysis
    analyze_range "$start_date" "$end_date" "$symbols_filter"
}

# Execute main function
main "$@"
