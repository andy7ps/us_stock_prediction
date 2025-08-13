#!/bin/bash

# Performance Monitoring Script - Persistent Data Edition
# Monitors ML model performance and system health
# ALL data stored in persistent_data/ directory

set -e

# PERSISTENT DATA PATHS - MANDATORY
PERSISTENT_DATA_DIR="./persistent_data"
MODEL_DIR="$PERSISTENT_DATA_DIR/ml_models"
SCALERS_DIR="$PERSISTENT_DATA_DIR/scalers"
ML_CACHE_DIR="$PERSISTENT_DATA_DIR/ml_cache"
STOCK_DATA_DIR="$PERSISTENT_DATA_DIR/stock_data"
LOG_DIR="$PERSISTENT_DATA_DIR/logs/monitoring"
CONFIG_DIR="$PERSISTENT_DATA_DIR/config"
BACKUPS_DIR="$PERSISTENT_DATA_DIR/backups"

# Ensure persistent data structure exists
if [ ! -d "$PERSISTENT_DATA_DIR" ]; then
    echo "🚨 ERROR: persistent_data directory not found!"
    echo "Run: ./setup_persistent_data.sh"
    exit 1
fi

# Create required directories
mkdir -p "$LOG_DIR" "$CONFIG_DIR"

# Configuration
SYMBOLS="NVDA TSLA AAPL MSFT GOOGL AMZN AUR PLTR SMCI TSM MP SMR SPY"
API_BASE_URL="http://localhost:8081"
PERFORMANCE_LOG="$LOG_DIR/performance.log"
HEALTH_LOG="$LOG_DIR/health.log"
ALERT_LOG="$LOG_DIR/alerts.log"
METRICS_CSV="$LOG_DIR/metrics.csv"

# Performance thresholds
MIN_ACCURACY=45.0
MAX_MAPE=5.0
MIN_CONFIDENCE=60.0
MAX_RESPONSE_TIME=5.0
MAX_MODEL_AGE_DAYS=7

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$PERFORMANCE_LOG"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$PERFORMANCE_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$PERFORMANCE_LOG" | tee -a "$ALERT_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$PERFORMANCE_LOG" | tee -a "$ALERT_LOG"
}

log_critical() {
    echo -e "${PURPLE}[CRITICAL]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$PERFORMANCE_LOG" | tee -a "$ALERT_LOG"
}

# Check system health
check_system_health() {
    log_info "=== System Health Check - Persistent Data ==="
    
    # Check persistent data directory
    if [ -d "$PERSISTENT_DATA_DIR" ]; then
        local size=$(du -sh "$PERSISTENT_DATA_DIR" | cut -f1)
        log_success "Persistent data directory: $PERSISTENT_DATA_DIR ($size)"
    else
        log_critical "Persistent data directory missing: $PERSISTENT_DATA_DIR"
        return 1
    fi
    
    # Check API health
    local health_response=$(curl -s "$API_BASE_URL/api/v1/health" 2>/dev/null || echo "ERROR")
    if echo "$health_response" | grep -q "healthy"; then
        local version=$(echo "$health_response" | jq -r '.version' 2>/dev/null || echo "unknown")
        log_success "API health check passed (version: $version)"
    else
        log_error "API health check failed"
        return 1
    fi
    
    # Check disk space for persistent data
    local disk_usage=$(df -h "$PERSISTENT_DATA_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        log_critical "Disk usage critical: ${disk_usage}% for persistent data"
    elif [ "$disk_usage" -gt 80 ]; then
        log_warning "Disk usage high: ${disk_usage}% for persistent data"
    else
        log_success "Disk usage normal: ${disk_usage}% for persistent data"
    fi
    
    # Check model files
    local model_count=$(find "$MODEL_DIR" -name "*.h5" 2>/dev/null | wc -l)
    local scaler_count=$(find "$SCALERS_DIR" -name "*.pkl" 2>/dev/null | wc -l)
    
    log_info "Models found: $model_count in $MODEL_DIR"
    log_info "Scalers found: $scaler_count in $SCALERS_DIR"
    
    if [ "$model_count" -eq 0 ]; then
        log_warning "No trained models found in persistent storage"
    fi
    
    return 0
}

# Check model performance
check_model_performance() {
    local symbol=$1
    log_info "Checking performance for $symbol"
    
    # Check if model exists
    local model_file="$MODEL_DIR/${symbol,,}_lstm_model.h5"
    if [ ! -f "$model_file" ]; then
        log_warning "Model not found for $symbol: $model_file"
        return 1
    fi
    
    # Check model age
    local model_age_days=$(( ($(date +%s) - $(stat -c %Y "$model_file")) / 86400 ))
    if [ $model_age_days -gt $MAX_MODEL_AGE_DAYS ]; then
        log_warning "Model for $symbol is $model_age_days days old (threshold: $MAX_MODEL_AGE_DAYS days)"
    else
        log_success "Model age for $symbol: $model_age_days days (within threshold)"
    fi
    
    # Test API prediction
    local start_time=$(date +%s.%N)
    local prediction_response=$(curl -s "$API_BASE_URL/api/v1/predict/$symbol" 2>/dev/null || echo "ERROR")
    local end_time=$(date +%s.%N)
    local response_time=$(echo "$end_time - $start_time" | bc)
    
    if echo "$prediction_response" | grep -q "predicted_price"; then
        local confidence=$(echo "$prediction_response" | jq -r '.confidence' 2>/dev/null || echo "0")
        local confidence_percent=$(echo "$confidence * 100" | bc | cut -d. -f1)
        
        log_success "Prediction API working for $symbol (${response_time}s, ${confidence_percent}% confidence)"
        
        # Check response time
        if (( $(echo "$response_time > $MAX_RESPONSE_TIME" | bc -l) )); then
            log_warning "Slow response time for $symbol: ${response_time}s (threshold: ${MAX_RESPONSE_TIME}s)"
        fi
        
        # Check confidence
        if (( $(echo "$confidence_percent < $MIN_CONFIDENCE" | bc -l) )); then
            log_warning "Low confidence for $symbol: ${confidence_percent}% (threshold: ${MIN_CONFIDENCE}%)"
        fi
        
        # Log performance metrics
        echo "$(date '+%Y-%m-%d %H:%M:%S'),$symbol,$response_time,$confidence_percent,$model_age_days" >> "$METRICS_CSV"
        
    else
        log_error "Prediction API failed for $symbol"
        return 1
    fi
    
    return 0
}

# Generate performance report
generate_report() {
    log_info "=== Performance Report - Persistent Data ==="
    
    local report_file="$LOG_DIR/performance_report_$(date +%Y%m%d_%H%M%S).json"
    local total_symbols=0
    local healthy_symbols=0
    local warnings=0
    local errors=0
    
    echo "{" > "$report_file"
    echo "  \"timestamp\": \"$(date -Iseconds)\"," >> "$report_file"
    echo "  \"persistent_data_dir\": \"$PERSISTENT_DATA_DIR\"," >> "$report_file"
    echo "  \"system_health\": {" >> "$report_file"
    
    # System health
    if check_system_health; then
        echo "    \"status\": \"healthy\"," >> "$report_file"
    else
        echo "    \"status\": \"unhealthy\"," >> "$report_file"
        ((errors++))
    fi
    
    local disk_usage=$(df -h "$PERSISTENT_DATA_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
    local data_size=$(du -sh "$PERSISTENT_DATA_DIR" | cut -f1)
    
    echo "    \"disk_usage_percent\": $disk_usage," >> "$report_file"
    echo "    \"data_size\": \"$data_size\"" >> "$report_file"
    echo "  }," >> "$report_file"
    echo "  \"models\": [" >> "$report_file"
    
    # Check each symbol
    local first=true
    for symbol in $SYMBOLS; do
        if [ "$first" = false ]; then
            echo "    ," >> "$report_file"
        fi
        first=false
        
        ((total_symbols++))
        
        echo "    {" >> "$report_file"
        echo "      \"symbol\": \"$symbol\"," >> "$report_file"
        
        if check_model_performance "$symbol"; then
            echo "      \"status\": \"healthy\"" >> "$report_file"
            ((healthy_symbols++))
        else
            echo "      \"status\": \"unhealthy\"" >> "$report_file"
            ((errors++))
        fi
        
        echo "    }" >> "$report_file"
    done
    
    echo "  ]," >> "$report_file"
    echo "  \"summary\": {" >> "$report_file"
    echo "    \"total_symbols\": $total_symbols," >> "$report_file"
    echo "    \"healthy_symbols\": $healthy_symbols," >> "$report_file"
    echo "    \"warnings\": $warnings," >> "$report_file"
    echo "    \"errors\": $errors" >> "$report_file"
    echo "  }" >> "$report_file"
    echo "}" >> "$report_file"
    
    log_success "Performance report generated: $report_file"
    
    # Summary
    log_info "=== Performance Summary ==="
    log_info "Total symbols: $total_symbols"
    log_info "Healthy symbols: $healthy_symbols"
    log_info "Warnings: $warnings"
    log_info "Errors: $errors"
    log_info "Persistent data directory: $PERSISTENT_DATA_DIR"
    log_info "Data size: $data_size"
    log_info "Disk usage: ${disk_usage}%"
}

# Check if retraining is needed
check_retraining_needed() {
    log_info "=== Checking if retraining is needed ==="
    
    local symbols_needing_training=""
    
    for symbol in $SYMBOLS; do
        local model_file="$MODEL_DIR/${symbol,,}_lstm_model.h5"
        
        if [ ! -f "$model_file" ]; then
            log_warning "Model missing for $symbol - needs training"
            symbols_needing_training="$symbols_needing_training $symbol"
            continue
        fi
        
        # Check model age
        local model_age_days=$(( ($(date +%s) - $(stat -c %Y "$model_file")) / 86400 ))
        if [ $model_age_days -gt $MAX_MODEL_AGE_DAYS ]; then
            log_warning "Model for $symbol is $model_age_days days old - needs retraining"
            symbols_needing_training="$symbols_needing_training $symbol"
        fi
    done
    
    if [ -n "$symbols_needing_training" ]; then
        log_critical "Symbols needing retraining: $symbols_needing_training"
        
        # Trigger automatic retraining if script exists
        if [ -f "./enhanced_training.sh" ]; then
            log_info "Triggering automatic retraining..."
            ./enhanced_training.sh --symbols "$symbols_needing_training"
        else
            log_warning "Enhanced training script not found"
        fi
    else
        log_success "All models are up to date"
    fi
}

# Main monitoring function
main() {
    log_critical "=== Performance Monitoring - Persistent Data Edition ==="
    log_info "Persistent data directory: $PERSISTENT_DATA_DIR"
    log_info "Monitoring timestamp: $(date)"
    
    # Initialize CSV header if not exists
    if [ ! -f "$METRICS_CSV" ]; then
        echo "timestamp,symbol,response_time,confidence_percent,model_age_days" > "$METRICS_CSV"
    fi
    
    # Generate performance report
    generate_report
    
    # Check if retraining is needed
    check_retraining_needed
    
    log_success "=== Performance monitoring completed ==="
    log_info "Logs stored in: $LOG_DIR"
    log_info "Persistent data: $PERSISTENT_DATA_DIR"
}

# Run main function
main "$@"
