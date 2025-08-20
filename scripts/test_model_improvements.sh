#!/bin/bash

# Model Improvements Test Script
# Quick verification that everything is ready for implementation
# Author: Stock Prediction Service Development Team
# Created: 2025-08-19

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/test_model_improvements_$(date +%Y%m%d_%H%M%S).log"

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

# Function to check Python dependencies
check_python_dependencies() {
    log_info "Checking Python dependencies..."
    
    local missing_deps=()
    
    # Check each required package
    if ! python3 -c "import tensorflow" 2>/dev/null; then
        missing_deps+=("tensorflow")
    fi
    
    if ! python3 -c "import yfinance" 2>/dev/null; then
        missing_deps+=("yfinance")
    fi
    
    if ! python3 -c "import sklearn" 2>/dev/null; then
        missing_deps+=("scikit-learn")
    fi
    
    if ! python3 -c "import joblib" 2>/dev/null; then
        missing_deps+=("joblib")
    fi
    
    if ! python3 -c "import pandas" 2>/dev/null; then
        missing_deps+=("pandas")
    fi
    
    if ! python3 -c "import numpy" 2>/dev/null; then
        missing_deps+=("numpy")
    fi
    
    if [ ${#missing_deps[@]} -eq 0 ]; then
        log_success "All Python dependencies are installed"
        return 0
    else
        log_error "Missing Python dependencies: ${missing_deps[*]}"
        log_info "Install with: pip install ${missing_deps[*]}"
        return 1
    fi
}

# Function to check script files
check_script_files() {
    log_info "Checking script files..."
    
    local required_scripts=(
        "train_symbol_specific_models.sh"
        "create_ensemble_models.sh"
        "compare_model_performance.sh"
    )
    
    local missing_scripts=()
    
    for script in "${required_scripts[@]}"; do
        if [ ! -f "$SCRIPT_DIR/$script" ]; then
            missing_scripts+=("$script")
        elif [ ! -x "$SCRIPT_DIR/$script" ]; then
            log_warning "$script exists but is not executable"
            chmod +x "$SCRIPT_DIR/$script"
        fi
    done
    
    if [ ${#missing_scripts[@]} -eq 0 ]; then
        log_success "All required scripts are present and executable"
        return 0
    else
        log_error "Missing scripts: ${missing_scripts[*]}"
        return 1
    fi
}

# Function to check directories
check_directories() {
    log_info "Checking directory structure..."
    
    local required_dirs=(
        "$PROJECT_ROOT/persistent_data/ml_models"
        "$PROJECT_ROOT/scripts/ml"
        "$LOG_DIR"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            log_info "Creating directory: $dir"
            mkdir -p "$dir"
        fi
    done
    
    log_success "Directory structure is ready"
    return 0
}

# Function to test API connectivity
test_api_connectivity() {
    log_info "Testing API connectivity..."
    
    local api_url="${API_BASE_URL:-http://localhost:8081}"
    
    if curl -s -f "$api_url/api/v1/health" > /dev/null 2>&1; then
        log_success "API is accessible at $api_url"
        return 0
    else
        log_error "API is not accessible at $api_url"
        log_info "Make sure the stock prediction service is running"
        return 1
    fi
}

# Function to test data download
test_data_download() {
    log_info "Testing data download capability..."
    
    python3 << 'EOF'
import yfinance as yf
from datetime import datetime, timedelta

try:
    # Test downloading data for NVDA
    end_date = datetime.now()
    start_date = end_date - timedelta(days=30)
    
    data = yf.download('NVDA', start=start_date, end=end_date, progress=False)
    
    if data.empty:
        print("ERROR: No data downloaded")
        exit(1)
    else:
        print(f"SUCCESS: Downloaded {len(data)} days of NVDA data")
        exit(0)
        
except Exception as e:
    print(f"ERROR: Data download failed: {e}")
    exit(1)
EOF
    
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        log_success "Data download is working"
        return 0
    else
        log_error "Data download failed"
        return 1
    fi
}

# Function to run a quick training test
test_training_capability() {
    log_info "Testing training capability with minimal example..."
    
    python3 << 'EOF'
import numpy as np
import tensorflow as tf
from sklearn.preprocessing import MinMaxScaler
from sklearn.ensemble import RandomForestRegressor

try:
    # Test TensorFlow
    model = tf.keras.Sequential([
        tf.keras.layers.Dense(10, activation='relu', input_shape=(5,)),
        tf.keras.layers.Dense(1)
    ])
    model.compile(optimizer='adam', loss='mse')
    
    # Test with dummy data
    X = np.random.random((100, 5))
    y = np.random.random((100, 1))
    
    model.fit(X, y, epochs=1, verbose=0)
    prediction = model.predict(X[:1], verbose=0)
    
    print(f"TensorFlow test: SUCCESS (prediction shape: {prediction.shape})")
    
    # Test scikit-learn
    rf = RandomForestRegressor(n_estimators=10, random_state=42)
    rf.fit(X, y.ravel())
    rf_pred = rf.predict(X[:1])
    
    print(f"Scikit-learn test: SUCCESS (prediction: {rf_pred[0]:.3f})")
    
    # Test scaler
    scaler = MinMaxScaler()
    X_scaled = scaler.fit_transform(X)
    
    print(f"Scaler test: SUCCESS (scaled range: {X_scaled.min():.3f} to {X_scaled.max():.3f})")
    
    print("All ML components working correctly")
    
except Exception as e:
    print(f"ERROR: ML test failed: {e}")
    exit(1)
EOF
    
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        log_success "ML training capability is working"
        return 0
    else
        log_error "ML training capability failed"
        return 1
    fi
}

# Function to show current system status
show_current_status() {
    log_info "Current system status:"
    
    # Get current accuracy
    if [ -f "$SCRIPT_DIR/calculate_accuracy.sh" ]; then
        log_info "Running accuracy summary..."
        "$SCRIPT_DIR/calculate_accuracy.sh" summary 2>/dev/null | grep -E "(Overall|MAPE)" | head -5 || log_warning "Could not get current accuracy"
    fi
    
    # Check existing models
    local model_count
    model_count=$(find "$PROJECT_ROOT/persistent_data/ml_models" -name "*.h5" 2>/dev/null | wc -l || echo "0")
    log_info "Existing ML models: $model_count"
    
    # Check predictions
    if [ -f "$PROJECT_ROOT/database_data/predictions.db" ]; then
        local pred_count
        pred_count=$(sqlite3 "$PROJECT_ROOT/database_data/predictions.db" "SELECT COUNT(*) FROM prediction_tracking;" 2>/dev/null || echo "0")
        log_info "Total predictions in database: $pred_count"
    fi
}

# Function to show next steps
show_next_steps() {
    log_info ""
    log_info "🚀 Ready to implement model improvements!"
    log_info ""
    log_info "Quick start commands:"
    log_info "1. Train high-priority symbols:"
    log_info "   ./scripts/train_symbol_specific_models.sh --symbols NVDA,MP"
    log_info ""
    log_info "2. Create ensemble models:"
    log_info "   ./scripts/create_ensemble_models.sh --symbols NVDA,MP"
    log_info ""
    log_info "3. Compare performance:"
    log_info "   ./scripts/compare_model_performance.sh --symbols NVDA,MP"
    log_info ""
    log_info "Full implementation guide: MODEL_IMPROVEMENT_GUIDE.md"
    log_info ""
}

# Main execution function
main() {
    log_info "=== Model Improvements Test Started ==="
    log_info "Timestamp: $(date)"
    log_info "Log File: $LOG_FILE"
    
    local all_tests_passed=true
    
    # Run all tests
    if ! check_python_dependencies; then
        all_tests_passed=false
    fi
    
    if ! check_script_files; then
        all_tests_passed=false
    fi
    
    if ! check_directories; then
        all_tests_passed=false
    fi
    
    if ! test_api_connectivity; then
        all_tests_passed=false
    fi
    
    if ! test_data_download; then
        all_tests_passed=false
    fi
    
    if ! test_training_capability; then
        all_tests_passed=false
    fi
    
    # Show current status
    show_current_status
    
    # Summary
    log_info ""
    if [ "$all_tests_passed" = "true" ]; then
        log_success "=== All Tests Passed! System Ready for Model Improvements ==="
        show_next_steps
        exit 0
    else
        log_error "=== Some Tests Failed - Please Fix Issues Before Proceeding ==="
        log_info "Check the log file for details: $LOG_FILE"
        exit 1
    fi
}

# Execute main function
main "$@"
