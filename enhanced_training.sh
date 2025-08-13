#!/bin/bash

# Enhanced Automatic Training Script
# Implements automatic retraining with performance monitoring and scheduling

set -e

# Configuration
SYMBOLS="NVDA TSLA AAPL MSFT GOOGL AMZN AUR PLTR SMCI TSM MP SMR SPY"
MODEL_DIR="persistent_data/ml_models"
LOG_DIR="logs/training"
EVALUATION_DIR="evaluation_results"
CONFIG_FILE="persistent_data/training_config.json"

# Performance thresholds
MIN_ACCURACY=45.0
MAX_MAPE=5.0
MIN_CONFIDENCE=60.0
MAX_MODEL_AGE_DAYS=7

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_DIR/training.log"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_DIR/training.log"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_DIR/training.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_DIR/training.log"
}

# Create necessary directories
setup_directories() {
    mkdir -p "$LOG_DIR" "$EVALUATION_DIR" "$MODEL_DIR"
    log_info "Directories created/verified"
}

# Check if models need retraining based on age
check_model_age() {
    local symbol=$1
    local model_file="$MODEL_DIR/${symbol,,}_lstm_model.h5"
    
    if [ ! -f "$model_file" ]; then
        log_info "Model for $symbol does not exist, needs training"
        return 0  # Needs training
    fi
    
    local age_days=$(find "$model_file" -mtime +$MAX_MODEL_AGE_DAYS | wc -l)
    if [ $age_days -gt 0 ]; then
        log_info "Model for $symbol is older than $MAX_MODEL_AGE_DAYS days, needs retraining"
        return 0  # Needs training
    fi
    
    return 1  # Does not need training
}

# Check model performance
check_model_performance() {
    local symbol=$1
    local eval_file="$EVALUATION_DIR/${symbol}_evaluation_report.json"
    
    if [ ! -f "$eval_file" ]; then
        log_warning "No evaluation report found for $symbol, assuming needs training"
        return 0  # Needs training
    fi
    
    # Extract performance metrics (simplified - would need jq for full JSON parsing)
    # For now, assume needs training if evaluation is old
    local eval_age=$(find "$eval_file" -mtime +1 | wc -l)
    if [ $eval_age -gt 0 ]; then
        log_info "Evaluation for $symbol is outdated, needs retraining"
        return 0  # Needs training
    fi
    
    return 1  # Performance OK
}

# Train models for symbols that need it
train_models() {
    local symbols_to_train=""
    local total_symbols=0
    local symbols_needing_training=0
    
    log_info "Checking which models need training..."
    
    for symbol in $SYMBOLS; do
        total_symbols=$((total_symbols + 1))
        
        if check_model_age "$symbol" || check_model_performance "$symbol"; then
            symbols_to_train="$symbols_to_train $symbol"
            symbols_needing_training=$((symbols_needing_training + 1))
            log_info "$symbol needs training"
        else
            log_info "$symbol model is up to date"
        fi
    done
    
    if [ -z "$symbols_to_train" ]; then
        log_success "All models are up to date, no training needed"
        return 0
    fi
    
    log_info "Training models for:$symbols_to_train"
    log_info "Training $symbols_needing_training out of $total_symbols symbols"
    
    # Train the models
    if ./manage_ml_models.sh train $symbols_to_train; then
        log_success "Model training completed successfully"
        
        # Update training log
        echo "{
            \"timestamp\": \"$(date -Iseconds)\",
            \"symbols_trained\": \"$symbols_to_train\",
            \"total_symbols\": $total_symbols,
            \"symbols_needing_training\": $symbols_needing_training,
            \"status\": \"success\"
        }" > "$LOG_DIR/last_training.json"
        
        return 0
    else
        log_error "Model training failed"
        return 1
    fi
}

# Evaluate model performance
evaluate_models() {
    log_info "Evaluating model performance..."
    
    if ./manage_ml_models.sh evaluate $SYMBOLS; then
        log_success "Model evaluation completed"
        return 0
    else
        log_warning "Model evaluation had issues (non-critical)"
        return 0  # Don't fail the whole process for evaluation issues
    fi
}

# Send notification (email, webhook, etc.)
send_notification() {
    local status=$1
    local message=$2
    
    # Log notification
    log_info "Notification: $status - $message"
    
    # You can add email, Slack, or other notification methods here
    # Example: echo "$message" | mail -s "ML Training $status" admin@yourcompany.com
    
    # For now, just create a notification file
    echo "{
        \"timestamp\": \"$(date -Iseconds)\",
        \"status\": \"$status\",
        \"message\": \"$message\",
        \"symbols\": \"$SYMBOLS\"
    }" > "$LOG_DIR/last_notification.json"
}

# Market hours check (optional - train during off-hours)
is_market_hours() {
    local hour=$(date +%H)
    local day=$(date +%u)  # 1=Monday, 7=Sunday
    
    # US market hours: 9:30 AM - 4:00 PM ET, Monday-Friday
    # Simplified: avoid 9-16 hours on weekdays
    if [ $day -ge 1 ] && [ $day -le 5 ] && [ $hour -ge 9 ] && [ $hour -le 16 ]; then
        return 0  # Is market hours
    else
        return 1  # Not market hours
    fi
}

# Health check before training
health_check() {
    log_info "Performing health check..."
    
    # Check Python environment
    if ! source venv/bin/activate 2>/dev/null; then
        log_error "Virtual environment not available"
        return 1
    fi
    
    # Check required packages
    if ! python3 -c "import numpy, pandas, sklearn, tensorflow" 2>/dev/null; then
        log_error "Required Python packages not available"
        return 1
    fi
    
    # Check disk space (need at least 1GB free)
    local free_space=$(df . | awk 'NR==2 {print $4}')
    if [ $free_space -lt 1048576 ]; then  # 1GB in KB
        log_error "Insufficient disk space for training"
        return 1
    fi
    
    log_success "Health check passed"
    return 0
}

# Backup existing models before training
backup_models() {
    local backup_dir="$MODEL_DIR/backup_$(date +%Y%m%d_%H%M%S)"
    
    if [ -n "$(ls -A $MODEL_DIR/*.h5 2>/dev/null)" ]; then
        log_info "Backing up existing models to $backup_dir"
        mkdir -p "$backup_dir"
        cp $MODEL_DIR/*.h5 $MODEL_DIR/*.pkl "$backup_dir/" 2>/dev/null || true
        log_success "Models backed up"
    fi
}

# Main execution function
main() {
    local force_training=false
    local skip_market_hours=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                force_training=true
                shift
                ;;
            --skip-market-hours)
                skip_market_hours=true
                shift
                ;;
            --help)
                echo "Usage: $0 [--force] [--skip-market-hours]"
                echo "  --force              Force training regardless of model age/performance"
                echo "  --skip-market-hours  Skip market hours check"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    log_info "=== Enhanced ML Training Started ==="
    log_info "Symbols: $SYMBOLS"
    log_info "Force training: $force_training"
    
    # Setup
    setup_directories
    
    # Health check
    if ! health_check; then
        send_notification "FAILED" "Health check failed"
        exit 1
    fi
    
    # Market hours check (unless skipped)
    if [ "$skip_market_hours" = false ] && is_market_hours; then
        log_warning "Currently in market hours, consider running during off-hours"
        log_info "Use --skip-market-hours to override this check"
    fi
    
    # Backup existing models
    backup_models
    
    # Training logic
    if [ "$force_training" = true ]; then
        log_info "Force training enabled, training all symbols"
        if ./manage_ml_models.sh train $SYMBOLS; then
            log_success "Force training completed successfully"
            send_notification "SUCCESS" "Force training completed for all symbols"
        else
            log_error "Force training failed"
            send_notification "FAILED" "Force training failed"
            exit 1
        fi
    else
        # Smart training based on age and performance
        if train_models; then
            send_notification "SUCCESS" "Automatic training completed successfully"
        else
            send_notification "FAILED" "Automatic training failed"
            exit 1
        fi
    fi
    
    # Evaluate models
    evaluate_models
    
    log_success "=== Enhanced ML Training Completed ==="
}

# Run main function with all arguments
main "$@"
