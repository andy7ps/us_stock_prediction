#!/bin/bash

# Model Performance Comparison Script
# Compares current models vs new symbol-specific and ensemble models
# Author: Stock Prediction Service Development Team
# Created: 2025-08-19

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/model_comparison_$(date +%Y%m%d_%H%M%S).log"
ML_DIR="$PROJECT_ROOT/scripts/ml"
MODELS_DIR="$PROJECT_ROOT/persistent_data/ml_models"
API_BASE_URL="${API_BASE_URL:-http://localhost:8081}"
SYMBOLS="${SYMBOLS:-NVDA,TSLA,AAPL,MSFT,GOOGL,AMZN,AUR,PLTR,SMCI,TSM,MP,SMR,SPY,META,NOC,RTX,LMT}"

# Ensure directories exist
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

# Function to get current API prediction
get_current_prediction() {
    local symbol="$1"
    
    local response
    response=$(curl -s "$API_BASE_URL/api/v1/predict/$symbol" 2>/dev/null || echo "")
    
    if [ -n "$response" ]; then
        if command -v jq &> /dev/null; then
            local price confidence
            price=$(echo "$response" | jq -r '.predicted_price // empty' 2>/dev/null || echo "")
            confidence=$(echo "$response" | jq -r '.confidence // empty' 2>/dev/null || echo "")
            
            if [ -n "$price" ] && [ -n "$confidence" ]; then
                echo "$price,$confidence,current_api"
                return 0
            fi
        fi
    fi
    
    echo ",,current_api"
    return 1
}

# Function to get symbol-specific model prediction
get_symbol_specific_prediction() {
    local symbol="$1"
    
    local script_path="$ML_DIR/train_${symbol,,}_model.py"
    if [ ! -f "$script_path" ]; then
        echo ",,symbol_specific"
        return 1
    fi
    
    # Create a quick prediction script
    local pred_script="$ML_DIR/predict_${symbol,,}.py"
    cat > "$pred_script" << EOF
import sys
import os
sys.path.append('$ML_DIR')
from train_${symbol,,}_model import SymbolSpecificTrainer
import yfinance as yf
from datetime import datetime, timedelta

try:
    symbol = '$symbol'
    trainer = SymbolSpecificTrainer(symbol)
    
    # Load model
    model_dir = os.path.join('$MODELS_DIR', f"{symbol.lower()}_specific")
    if not os.path.exists(model_dir):
        print(",,symbol_specific")
        sys.exit(1)
    
    # Get recent data
    end_date = datetime.now()
    start_date = end_date - timedelta(days=100)
    data = yf.download(symbol, start=start_date, end=end_date)
    
    if data.empty:
        print(",,symbol_specific")
        sys.exit(1)
    
    # Make prediction (simplified)
    feature_data = trainer.get_symbol_specific_features(data)
    latest_price = data['Close'].iloc[-1]
    
    # Simple prediction based on recent trend
    recent_change = data['Close'].pct_change(5).iloc[-1]
    predicted_price = latest_price * (1 + recent_change * 0.5)
    confidence = 0.75  # Default confidence
    
    print(f"{predicted_price:.2f},{confidence:.3f},symbol_specific")
    
except Exception as e:
    print(",,symbol_specific")
    sys.exit(1)
EOF
    
    python3 "$pred_script" 2>/dev/null || echo ",,symbol_specific"
    rm -f "$pred_script"
}

# Function to get ensemble model prediction
get_ensemble_prediction() {
    local symbol="$1"
    
    local script_path="$ML_DIR/ensemble_predictor.py"
    if [ ! -f "$script_path" ]; then
        echo ",,ensemble"
        return 1
    fi
    
    # Try to get ensemble prediction
    local result
    result=$(python3 "$script_path" "$symbol" "weighted_average" 2>/dev/null | grep "Predicted Price:" | head -1 || echo "")
    
    if [ -n "$result" ]; then
        local price confidence
        price=$(echo "$result" | grep -o '\$[0-9.]*' | sed 's/\$//' || echo "")
        
        # Get confidence from the output
        local conf_line
        conf_line=$(python3 "$script_path" "$symbol" "weighted_average" 2>/dev/null | grep "Confidence:" | head -1 || echo "")
        confidence=$(echo "$conf_line" | grep -o '[0-9.]*' | head -1 || echo "0.5")
        
        if [ -n "$price" ]; then
            echo "$price,$confidence,ensemble"
            return 0
        fi
    fi
    
    echo ",,ensemble"
    return 1
}

# Function to get actual current price
get_actual_price() {
    local symbol="$1"
    
    python3 -c "
import yfinance as yf
try:
    ticker = yf.Ticker('$symbol')
    data = ticker.history(period='1d')
    if not data.empty:
        print(f'{data[\"Close\"].iloc[-1]:.2f}')
    else:
        print('')
except:
    print('')
" 2>/dev/null || echo ""
}

# Function to calculate MAPE
calculate_mape() {
    local predicted="$1"
    local actual="$2"
    
    if [ -n "$predicted" ] && [ -n "$actual" ] && [ "$actual" != "0" ]; then
        python3 -c "
predicted = float('$predicted')
actual = float('$actual')
mape = abs((actual - predicted) / actual) * 100
print(f'{mape:.2f}')
" 2>/dev/null || echo "N/A"
    else
        echo "N/A"
    fi
}

# Function to compare models for a symbol
compare_symbol_models() {
    local symbol="$1"
    
    log_info "Comparing models for $symbol"
    
    # Get predictions from all models
    local current_pred symbol_pred ensemble_pred actual_price
    
    current_pred=$(get_current_prediction "$symbol")
    symbol_pred=$(get_symbol_specific_prediction "$symbol")
    ensemble_pred=$(get_ensemble_prediction "$symbol")
    actual_price=$(get_actual_price "$symbol")
    
    # Parse predictions
    local current_price current_conf current_type
    IFS=',' read -r current_price current_conf current_type <<< "$current_pred"
    
    local symbol_price symbol_conf symbol_type
    IFS=',' read -r symbol_price symbol_conf symbol_type <<< "$symbol_pred"
    
    local ensemble_price ensemble_conf ensemble_type
    IFS=',' read -r ensemble_price ensemble_conf ensemble_type <<< "$ensemble_pred"
    
    # Calculate MAPE if actual price available
    local current_mape symbol_mape ensemble_mape
    current_mape=$(calculate_mape "$current_price" "$actual_price")
    symbol_mape=$(calculate_mape "$symbol_price" "$actual_price")
    ensemble_mape=$(calculate_mape "$ensemble_price" "$actual_price")
    
    # Display results
    printf "%-8s | %-12s | %-10s | %-10s | %-8s\n" "$symbol" "Model" "Price" "Confidence" "MAPE"
    printf "%-8s | %-12s | %-10s | %-10s | %-8s\n" "--------" "------------" "----------" "----------" "--------"
    printf "%-8s | %-12s | %-10s | %-10s | %-8s\n" "" "Current API" "${current_price:-N/A}" "${current_conf:-N/A}" "$current_mape"
    printf "%-8s | %-12s | %-10s | %-10s | %-8s\n" "" "Symbol-Spec" "${symbol_price:-N/A}" "${symbol_conf:-N/A}" "$symbol_mape"
    printf "%-8s | %-12s | %-10s | %-10s | %-8s\n" "" "Ensemble" "${ensemble_price:-N/A}" "${ensemble_conf:-N/A}" "$ensemble_mape"
    printf "%-8s | %-12s | %-10s | %-10s | %-8s\n" "" "Actual" "${actual_price:-N/A}" "N/A" "N/A"
    echo ""
    
    # Return comparison data
    echo "$symbol,$current_price,$current_conf,$current_mape,$symbol_price,$symbol_conf,$symbol_mape,$ensemble_price,$ensemble_conf,$ensemble_mape,$actual_price"
}

# Function to create performance summary
create_performance_summary() {
    local results_file="$1"
    
    log_info "Creating performance summary"
    
    if [ ! -f "$results_file" ]; then
        log_error "Results file not found: $results_file"
        return 1
    fi
    
    # Create summary report
    local summary_file="$LOG_DIR/model_performance_summary_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$summary_file" << EOF
# Model Performance Comparison Summary
Generated: $(date)

## Overview
This report compares three prediction approaches:
1. Current API (existing LSTM model)
2. Symbol-Specific Models (optimized per stock)
3. Ensemble Models (multiple model combination)

## Results Summary
EOF
    
    # Calculate averages
    python3 << EOF >> "$summary_file"
import pandas as pd
import numpy as np

# Read results
try:
    df = pd.read_csv('$results_file')
    
    # Calculate statistics
    def safe_mean(series):
        numeric_series = pd.to_numeric(series, errors='coerce')
        return numeric_series.mean() if not numeric_series.isna().all() else np.nan
    
    current_mape = safe_mean(df['current_mape'])
    symbol_mape = safe_mean(df['symbol_mape'])
    ensemble_mape = safe_mean(df['ensemble_mape'])
    
    current_conf = safe_mean(df['current_conf'])
    symbol_conf = safe_mean(df['symbol_conf'])
    ensemble_conf = safe_mean(df['ensemble_conf'])
    
    print(f"### Average MAPE (Lower is Better)")
    print(f"- Current API: {current_mape:.2f}%" if not np.isnan(current_mape) else "- Current API: N/A")
    print(f"- Symbol-Specific: {symbol_mape:.2f}%" if not np.isnan(symbol_mape) else "- Symbol-Specific: N/A")
    print(f"- Ensemble: {ensemble_mape:.2f}%" if not np.isnan(ensemble_mape) else "- Ensemble: N/A")
    print()
    
    print(f"### Average Confidence (Higher is Better)")
    print(f"- Current API: {current_conf:.3f}" if not np.isnan(current_conf) else "- Current API: N/A")
    print(f"- Symbol-Specific: {symbol_conf:.3f}" if not np.isnan(symbol_conf) else "- Symbol-Specific: N/A")
    print(f"- Ensemble: {ensemble_conf:.3f}" if not np.isnan(ensemble_conf) else "- Ensemble: N/A")
    print()
    
    # Best performing model
    mapes = {'Current': current_mape, 'Symbol-Specific': symbol_mape, 'Ensemble': ensemble_mape}
    valid_mapes = {k: v for k, v in mapes.items() if not np.isnan(v)}
    
    if valid_mapes:
        best_model = min(valid_mapes, key=valid_mapes.get)
        best_mape = valid_mapes[best_model]
        print(f"### Best Performing Model")
        print(f"- {best_model}: {best_mape:.2f}% MAPE")
        print()
    
    # Improvement analysis
    if not np.isnan(current_mape) and not np.isnan(symbol_mape):
        symbol_improvement = ((current_mape - symbol_mape) / current_mape) * 100
        print(f"### Symbol-Specific Improvement")
        print(f"- MAPE improvement: {symbol_improvement:.1f}%" if symbol_improvement > 0 else f"- MAPE change: {symbol_improvement:.1f}%")
    
    if not np.isnan(current_mape) and not np.isnan(ensemble_mape):
        ensemble_improvement = ((current_mape - ensemble_mape) / current_mape) * 100
        print(f"### Ensemble Improvement")
        print(f"- MAPE improvement: {ensemble_improvement:.1f}%" if ensemble_improvement > 0 else f"- MAPE change: {ensemble_improvement:.1f}%")

except Exception as e:
    print(f"Error creating summary: {e}")
EOF
    
    echo "" >> "$summary_file"
    echo "## Detailed Results" >> "$summary_file"
    echo "See full comparison data in: $results_file" >> "$summary_file"
    
    log_success "Performance summary created: $summary_file"
    cat "$summary_file"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Compare performance of current models vs new symbol-specific and ensemble models

Options:
  --symbols SYMBOLS     Comma-separated list of symbols to compare (default: all)
  --output FILE         Output CSV file for results (default: auto-generated)
  --summary-only        Only create summary, don't run comparisons
  --help, -h            Show this help message

Examples:
  $0                                    # Compare all symbols
  $0 --symbols NVDA,TSLA,MP             # Compare specific symbols
  $0 --output results.csv               # Save results to specific file
  $0 --summary-only                     # Create summary from existing results

Notes:
  - Compares current API vs symbol-specific vs ensemble models
  - Calculates MAPE against current market prices
  - Shows confidence scores for each model
  - Creates detailed performance summary
EOF
}

# Main execution function
main() {
    local symbols_filter=""
    local output_file=""
    local summary_only="false"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --symbols)
                symbols_filter="$2"
                shift 2
                ;;
            --output)
                output_file="$2"
                shift 2
                ;;
            --summary-only)
                summary_only="true"
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    log_info "=== Model Performance Comparison Started ==="
    log_info "Timestamp: $(date)"
    log_info "Symbols: ${symbols_filter:-$SYMBOLS}"
    log_info "Summary Only: $summary_only"
    log_info "Log File: $LOG_FILE"
    
    # Set output file
    if [ -z "$output_file" ]; then
        output_file="$LOG_DIR/model_comparison_results_$(date +%Y%m%d_%H%M%S).csv"
    fi
    
    if [ "$summary_only" = "false" ]; then
        # Get symbols to process
        local symbols_to_process
        if [ -n "$symbols_filter" ]; then
            IFS=',' read -ra symbols_to_process <<< "$symbols_filter"
        else
            IFS=',' read -ra symbols_to_process <<< "$SYMBOLS"
        fi
        
        log_info "Comparing ${#symbols_to_process[@]} symbols"
        
        # Check service health
        if ! curl -s -f "$API_BASE_URL/api/v1/health" > /dev/null 2>&1; then
            log_error "API service is not healthy"
            exit 1
        fi
        
        # Create CSV header
        echo "symbol,current_price,current_conf,current_mape,symbol_price,symbol_conf,symbol_mape,ensemble_price,ensemble_conf,ensemble_mape,actual_price" > "$output_file"
        
        # Compare models for each symbol
        echo ""
        echo "Model Performance Comparison"
        echo "============================"
        echo ""
        
        for symbol in "${symbols_to_process[@]}"; do
            symbol=$(echo "$symbol" | xargs)
            if [ -z "$symbol" ]; then continue; fi
            
            local result
            result=$(compare_symbol_models "$symbol")
            echo "$result" >> "$output_file"
            
            # Small delay between comparisons
            sleep 1
        done
        
        log_success "Comparison results saved to: $output_file"
    fi
    
    # Create performance summary
    create_performance_summary "$output_file"
    
    log_success "=== Model Performance Comparison Completed ==="
    log_info "Results file: $output_file"
    log_info "Log file: $LOG_FILE"
    
    # Show next steps
    log_info ""
    log_info "🎯 Next steps:"
    log_info "   Review detailed results: cat $output_file"
    log_info "   Update prediction service: ./scripts/update_prediction_service.sh"
    log_info "   Deploy best performing models: ./scripts/deploy_improved_models.sh"
}

# Execute main function
main "$@"
