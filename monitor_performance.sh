#!/bin/bash

# Performance Monitoring Script
# Monitors ML model performance and triggers retraining when needed

set -e

# Configuration
SYMBOLS="NVDA TSLA AAPL MSFT GOOGL AMZN AUR PLTR SMCI TSM MP SMR SPY"
LOG_DIR="logs/monitoring"
EVALUATION_DIR="evaluation_results"
PERFORMANCE_LOG="$LOG_DIR/performance_history.jsonl"

# Performance thresholds
MIN_ACCURACY=45.0
MAX_MAPE=5.0
MIN_CONFIDENCE=60.0
CONSECUTIVE_FAILURES=3

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[MONITOR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_DIR/monitoring.log"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_DIR/monitoring.log"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_DIR/monitoring.log"
}

log_error() {
    echo -e "${RED}[ALERT]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_DIR/monitoring.log"
}

# Setup monitoring directories
setup_monitoring() {
    mkdir -p "$LOG_DIR" "$EVALUATION_DIR"
    touch "$PERFORMANCE_LOG"
}

# Test API performance for a symbol
test_api_performance() {
    local symbol=$1
    local start_time=$(date +%s.%N)
    
    # Test API endpoint
    local response=$(curl -s "http://localhost:8081/api/v1/predict/$symbol" 2>/dev/null || echo "ERROR")
    local end_time=$(date +%s.%N)
    local response_time=$(echo "$end_time - $start_time" | bc -l)
    
    if [[ "$response" == "ERROR" ]] || [[ "$response" == *"error"* ]]; then
        log_error "API test failed for $symbol"
        return 1
    fi
    
    # Extract confidence from JSON response (simplified)
    local confidence=$(echo "$response" | grep -o '"confidence":[0-9.]*' | cut -d':' -f2 || echo "0")
    
    # Log performance data
    echo "{
        \"timestamp\": \"$(date -Iseconds)\",
        \"symbol\": \"$symbol\",
        \"response_time\": $response_time,
        \"confidence\": $confidence,
        \"status\": \"success\"
    }" >> "$PERFORMANCE_LOG"
    
    log_info "$symbol API test: ${response_time}s response time, ${confidence} confidence"
    
    # Check if confidence is below threshold
    if (( $(echo "$confidence < $MIN_CONFIDENCE/100" | bc -l) )); then
        log_warning "$symbol confidence ($confidence) below threshold ($MIN_CONFIDENCE%)"
        return 2  # Low confidence
    fi
    
    return 0
}

# Check recent prediction accuracy
check_prediction_accuracy() {
    local symbol=$1
    
    # This would typically compare predictions with actual prices
    # For now, we'll check if the model files exist and are recent
    local model_file="persistent_data/ml_models/${symbol,,}_lstm_model.h5"
    
    if [ ! -f "$model_file" ]; then
        log_error "Model file missing for $symbol"
        return 1
    fi
    
    # Check if model is older than 14 days (warning threshold)
    local age_days=$(find "$model_file" -mtime +14 | wc -l)
    if [ $age_days -gt 0 ]; then
        log_warning "$symbol model is older than 14 days"
        return 2
    fi
    
    return 0
}

# Monitor system resources
check_system_resources() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    local disk_usage=$(df . | awk 'NR==2 {print $5}' | cut -d'%' -f1)
    
    log_info "System resources - CPU: ${cpu_usage}%, Memory: ${memory_usage}%, Disk: ${disk_usage}%"
    
    # Alert if resources are high
    if (( $(echo "$cpu_usage > 80" | bc -l) )); then
        log_warning "High CPU usage: ${cpu_usage}%"
    fi
    
    if (( $(echo "$memory_usage > 80" | bc -l) )); then
        log_warning "High memory usage: ${memory_usage}%"
    fi
    
    if [ "$disk_usage" -gt 90 ]; then
        log_error "High disk usage: ${disk_usage}%"
        return 1
    fi
    
    return 0
}

# Check if Go service is running
check_service_health() {
    local health_response=$(curl -s "http://localhost:8081/api/v1/health" 2>/dev/null || echo "ERROR")
    
    if [[ "$health_response" == "ERROR" ]] || [[ "$health_response" != *"healthy"* ]]; then
        log_error "Go service health check failed"
        return 1
    fi
    
    log_success "Go service is healthy"
    return 0
}

# Analyze performance trends
analyze_performance_trends() {
    local symbol=$1
    local recent_entries=$(tail -n 10 "$PERFORMANCE_LOG" | grep "\"symbol\": \"$symbol\"" | wc -l)
    
    if [ $recent_entries -lt 3 ]; then
        log_info "Insufficient data for trend analysis of $symbol"
        return 0
    fi
    
    # Simple trend analysis - check if recent confidence scores are declining
    local recent_confidences=$(tail -n 50 "$PERFORMANCE_LOG" | grep "\"symbol\": \"$symbol\"" | tail -n 5 | grep -o '"confidence":[0-9.]*' | cut -d':' -f2)
    
    if [ -n "$recent_confidences" ]; then
        local avg_confidence=$(echo "$recent_confidences" | awk '{sum+=$1} END {print sum/NR}')
        log_info "$symbol average recent confidence: $avg_confidence"
        
        if (( $(echo "$avg_confidence < $MIN_CONFIDENCE/100" | bc -l) )); then
            log_warning "$symbol showing declining performance trend"
            return 1
        fi
    fi
    
    return 0
}

# Trigger retraining if needed
trigger_retraining() {
    local symbols_needing_retraining="$1"
    
    if [ -n "$symbols_needing_retraining" ]; then
        log_error "Performance issues detected for: $symbols_needing_retraining"
        log_info "Triggering automatic retraining..."
        
        # Create a flag file to indicate performance-based retraining
        echo "{
            \"timestamp\": \"$(date -Iseconds)\",
            \"reason\": \"performance_degradation\",
            \"symbols\": \"$symbols_needing_retraining\",
            \"triggered_by\": \"monitor_performance.sh\"
        }" > "logs/training/retraining_trigger.json"
        
        # Trigger enhanced training script
        if ./enhanced_training.sh --force; then
            log_success "Performance-based retraining completed"
        else
            log_error "Performance-based retraining failed"
            return 1
        fi
    fi
    
    return 0
}

# Generate performance report
generate_report() {
    local report_file="$LOG_DIR/performance_report_$(date +%Y%m%d).json"
    
    log_info "Generating performance report: $report_file"
    
    echo "{
        \"timestamp\": \"$(date -Iseconds)\",
        \"monitoring_period\": \"$(date -d '1 day ago' -Iseconds) to $(date -Iseconds)\",
        \"symbols_monitored\": \"$SYMBOLS\",
        \"total_symbols\": $(echo $SYMBOLS | wc -w),
        \"system_status\": \"$(check_service_health && echo 'healthy' || echo 'unhealthy')\",
        \"performance_log_entries\": $(wc -l < "$PERFORMANCE_LOG"),
        \"generated_by\": \"monitor_performance.sh\"
    }" > "$report_file"
    
    log_success "Performance report generated"
}

# Main monitoring function
main() {
    local mode="check"  # Default mode
    local symbols_to_monitor="$SYMBOLS"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --continuous)
                mode="continuous"
                shift
                ;;
            --report)
                mode="report"
                shift
                ;;
            --symbols)
                symbols_to_monitor="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 [--continuous] [--report] [--symbols 'SYMBOL1 SYMBOL2']"
                echo "  --continuous  Run continuous monitoring (daemon mode)"
                echo "  --report      Generate performance report only"
                echo "  --symbols     Monitor specific symbols only"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    setup_monitoring
    
    if [ "$mode" = "report" ]; then
        generate_report
        exit 0
    fi
    
    log_info "=== Performance Monitoring Started ==="
    log_info "Mode: $mode"
    log_info "Symbols: $symbols_to_monitor"
    
    local symbols_needing_retraining=""
    local monitoring_cycle=0
    
    while true; do
        monitoring_cycle=$((monitoring_cycle + 1))
        log_info "Monitoring cycle #$monitoring_cycle"
        
        # Check system health
        if ! check_service_health; then
            log_error "Service health check failed, skipping API tests"
        else
            # Test each symbol
            for symbol in $symbols_to_monitor; do
                case $(test_api_performance "$symbol") in
                    1)
                        log_error "$symbol API test failed"
                        symbols_needing_retraining="$symbols_needing_retraining $symbol"
                        ;;
                    2)
                        log_warning "$symbol has low confidence"
                        # Add to retraining list if consistently low
                        if analyze_performance_trends "$symbol"; then
                            symbols_needing_retraining="$symbols_needing_retraining $symbol"
                        fi
                        ;;
                    0)
                        log_success "$symbol performing well"
                        ;;
                esac
                
                # Check prediction accuracy
                if ! check_prediction_accuracy "$symbol"; then
                    symbols_needing_retraining="$symbols_needing_retraining $symbol"
                fi
                
                # Small delay between symbol tests
                sleep 1
            done
        fi
        
        # Check system resources
        check_system_resources
        
        # Trigger retraining if needed
        if [ -n "$symbols_needing_retraining" ]; then
            trigger_retraining "$symbols_needing_retraining"
            symbols_needing_retraining=""  # Reset after triggering
        fi
        
        # Generate report every 24 cycles (if running hourly)
        if [ $((monitoring_cycle % 24)) -eq 0 ]; then
            generate_report
        fi
        
        # Exit if not in continuous mode
        if [ "$mode" != "continuous" ]; then
            break
        fi
        
        # Wait before next cycle (1 hour for continuous mode)
        log_info "Waiting 1 hour before next monitoring cycle..."
        sleep 3600
    done
    
    log_success "=== Performance Monitoring Completed ==="
}

# Run main function with all arguments
main "$@"
