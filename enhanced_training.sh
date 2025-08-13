#!/bin/bash

# Enhanced Automatic Training Script - Persistent Data Edition
# Implements automatic retraining with performance monitoring and scheduling
# ALL operations use persistent_data/ directory structure

set -e

# PERSISTENT DATA PATHS - MANDATORY
PERSISTENT_DATA_DIR="./persistent_data"
MODEL_DIR="$PERSISTENT_DATA_DIR/ml_models"
SCALERS_DIR="$PERSISTENT_DATA_DIR/scalers"
ML_CACHE_DIR="$PERSISTENT_DATA_DIR/ml_cache"
STOCK_DATA_DIR="$PERSISTENT_DATA_DIR/stock_data"
LOG_DIR="$PERSISTENT_DATA_DIR/logs/training"
CONFIG_DIR="$PERSISTENT_DATA_DIR/config"
BACKUPS_DIR="$PERSISTENT_DATA_DIR/backups"

# Ensure persistent data structure exists
if [ ! -d "$PERSISTENT_DATA_DIR" ]; then
    echo "🚨 ERROR: persistent_data directory not found!"
    echo "Run: ./setup_persistent_data.sh"
    exit 1
fi

# Create required directories
mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$BACKUPS_DIR"

# Configuration
SYMBOLS="NVDA TSLA AAPL MSFT GOOGL AMZN AUR PLTR SMCI TSM MP SMR SPY"
CONFIG_FILE="$CONFIG_DIR/training_config.json"

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
PURPLE='\033[0;35m'
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

log_critical() {
    echo -e "${PURPLE}[CRITICAL]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_DIR/training.log"
}

# Initialize training configuration
init_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_info "Creating training configuration file"
        cat > "$CONFIG_FILE" << EOF
{
  "last_training": "$(date -Iseconds)",
  "training_mode": "automatic",
  "persistent_data_dir": "$PERSISTENT_DATA_DIR",
  "model_dir": "$MODEL_DIR",
  "scalers_dir": "$SCALERS_DIR",
  "cache_dir": "$ML_CACHE_DIR",
  "log_dir": "$LOG_DIR",
  "thresholds": {
    "min_accuracy": $MIN_ACCURACY,
    "max_mape": $MAX_MAPE,
    "min_confidence": $MIN_CONFIDENCE,
    "max_model_age_days": $MAX_MODEL_AGE_DAYS
  },
  "symbols": "$SYMBOLS"
}
EOF
    fi
}

# Check if model needs retraining
needs_retraining() {
    local symbol=$1
    local model_file="$MODEL_DIR/${symbol,,}_lstm_model.h5"
    
    # Check if model exists
    if [ ! -f "$model_file" ]; then
        log_warning "Model not found for $symbol: $model_file"
        return 0  # Needs training
    fi
    
    # Check model age
    local model_age_days=$(( ($(date +%s) - $(stat -c %Y "$model_file")) / 86400 ))
    if [ $model_age_days -gt $MAX_MODEL_AGE_DAYS ]; then
        log_warning "Model for $symbol is $model_age_days days old (threshold: $MAX_MODEL_AGE_DAYS days)"
        return 0  # Needs retraining
    fi
    
    # Check performance (if evaluation results exist)
    local eval_file="$LOG_DIR/evaluation/${symbol,,}_evaluation.json"
    if [ -f "$eval_file" ]; then
        local accuracy=$(jq -r '.accuracy // 0' "$eval_file" 2>/dev/null || echo "0")
        local mape=$(jq -r '.mape // 100' "$eval_file" 2>/dev/null || echo "100")
        local confidence=$(jq -r '.confidence // 0' "$eval_file" 2>/dev/null || echo "0")
        
        if (( $(echo "$accuracy < $MIN_ACCURACY" | bc -l) )); then
            log_warning "Model for $symbol has low accuracy: $accuracy% (threshold: $MIN_ACCURACY%)"
            return 0  # Needs retraining
        fi
        
        if (( $(echo "$mape > $MAX_MAPE" | bc -l) )); then
            log_warning "Model for $symbol has high MAPE: $mape% (threshold: $MAX_MAPE%)"
            return 0  # Needs retraining
        fi
        
        if (( $(echo "$confidence < $MIN_CONFIDENCE" | bc -l) )); then
            log_warning "Model for $symbol has low confidence: $confidence% (threshold: $MIN_CONFIDENCE%)"
            return 0  # Needs retraining
        fi
    fi
    
    return 1  # No retraining needed
}

# Create backup before training
create_backup() {
    log_info "Creating backup before training..."
    local backup_file="$BACKUPS_DIR/pre_training_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    if [ -d "$MODEL_DIR" ] && [ "$(ls -A $MODEL_DIR)" ]; then
        tar -czf "$backup_file" -C "$PERSISTENT_DATA_DIR" ml_models scalers ml_cache 2>/dev/null || true
        log_success "Backup created: $backup_file"
    else
        log_info "No existing models to backup"
    fi
}

# Train models with persistent data
train_models() {
    local symbols_to_train="$1"
    local force_training="$2"
    
    log_info "Starting training process with persistent data"
    log_info "Persistent data directory: $PERSISTENT_DATA_DIR"
    log_info "Models directory: $MODEL_DIR"
    log_info "Scalers directory: $SCALERS_DIR"
    log_info "Cache directory: $ML_CACHE_DIR"
    
    # Activate virtual environment if available
    if [ -d "venv" ]; then
        log_info "Activating virtual environment"
        source venv/bin/activate
    fi
    
    # Set environment variables for persistent data
    export ML_MODEL_PATH="$MODEL_DIR"
    export SCALERS_PATH="$SCALERS_DIR"
    export ML_CACHE_PATH="$ML_CACHE_DIR"
    export STOCK_DATA_CACHE_PATH="$STOCK_DATA_DIR/cache"
    export LOG_PATH="$LOG_DIR"
    
    # Train models using manage_ml_models.sh with persistent data
    if [ "$force_training" = "true" ]; then
        log_info "Force training all models: $symbols_to_train"
        ./manage_ml_models.sh train $symbols_to_train
    else
        # Check each symbol individually
        local symbols_needing_training=""
        for symbol in $symbols_to_train; do
            if needs_retraining "$symbol"; then
                symbols_needing_training="$symbols_needing_training $symbol"
            else
                log_info "Model for $symbol is up to date"
            fi
        done
        
        if [ -n "$symbols_needing_training" ]; then
            log_info "Training models for symbols: $symbols_needing_training"
            ./manage_ml_models.sh train $symbols_needing_training
        else
            log_info "All models are up to date"
        fi
    fi
}

# Evaluate trained models
evaluate_models() {
    local symbols="$1"
    
    log_info "Evaluating trained models"
    mkdir -p "$LOG_DIR/evaluation"
    
    if [ -d "venv" ]; then
        source venv/bin/activate
    fi
    
    # Set environment variables
    export ML_MODEL_PATH="$MODEL_DIR"
    export SCALERS_PATH="$SCALERS_DIR"
    
    ./manage_ml_models.sh evaluate $symbols
}

# Update configuration after training
update_config() {
    log_info "Updating training configuration"
    
    # Update last training time
    if [ -f "$CONFIG_FILE" ]; then
        jq --arg date "$(date -Iseconds)" '.last_training = $date' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    fi
}

# Main training logic
main() {
    local force_training=false
    local symbols_to_train="$SYMBOLS"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                force_training=true
                shift
                ;;
            --symbols)
                symbols_to_train="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    log_critical "=== Enhanced Training Script - Persistent Data Edition ==="
    log_info "Persistent data directory: $PERSISTENT_DATA_DIR"
    log_info "Force training: $force_training"
    log_info "Symbols to process: $symbols_to_train"
    
    # Initialize configuration
    init_config
    
    # Create backup
    create_backup
    
    # Train models
    train_models "$symbols_to_train" "$force_training"
    
    # Evaluate models
    evaluate_models "$symbols_to_train"
    
    # Update configuration
    update_config
    
    log_success "=== Training process completed ==="
    log_info "All data stored in persistent directory: $PERSISTENT_DATA_DIR"
    log_info "Models: $MODEL_DIR"
    log_info "Scalers: $SCALERS_DIR"
    log_info "Logs: $LOG_DIR"
    log_info "Backups: $BACKUPS_DIR"
}

# Run main function
main "$@"
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
