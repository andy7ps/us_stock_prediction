#!/bin/bash

# ML Model Management Script - Persistent Data Edition
# ALL operations use persistent_data/ directory structure

set -e

# PERSISTENT DATA PATHS - MANDATORY
PERSISTENT_DATA_DIR="./persistent_data"
ML_MODELS_DIR="$PERSISTENT_DATA_DIR/ml_models"
ML_CACHE_DIR="$PERSISTENT_DATA_DIR/ml_cache"
SCALERS_DIR="$PERSISTENT_DATA_DIR/scalers"
STOCK_DATA_DIR="$PERSISTENT_DATA_DIR/stock_data"
LOGS_DIR="$PERSISTENT_DATA_DIR/logs"
CONFIG_DIR="$PERSISTENT_DATA_DIR/config"
BACKUPS_DIR="$PERSISTENT_DATA_DIR/backups"

# Ensure persistent data structure exists
if [ ! -d "$PERSISTENT_DATA_DIR" ]; then
    echo "🚨 ERROR: persistent_data directory not found!"
    echo "Run: ./setup_persistent_data.sh"
    exit 1
fi

# Create required directories
mkdir -p "$ML_MODELS_DIR" "$ML_CACHE_DIR" "$SCALERS_DIR" "$STOCK_DATA_DIR" "$LOGS_DIR/training"

# Default symbols list
DEFAULT_SYMBOLS="NVDA TSLA AAPL MSFT GOOGL AMZN AUR PLTR SMCI TSM MP SMR SPY"

# Logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGS_DIR/training/manage_models.log"
}

case "$1" in
    train)
        symbols="${@:2}"
        if [ -z "$symbols" ]; then
            symbols="$DEFAULT_SYMBOLS"
        fi
        log_message "Training models for symbols: $symbols"
        log_message "Using persistent data directory: $PERSISTENT_DATA_DIR"
        
        # Run training inside Docker container which has all dependencies
        echo "Running training inside Docker container..."
        docker exec v3_stock-prediction_1 python3 scripts/ml/simple_train.py \
            --symbols $symbols \
            --model-dir "$ML_MODELS_DIR" \
            --scalers-dir "$SCALERS_DIR" \
            --cache-dir "$ML_CACHE_DIR" \
            --data-dir "$STOCK_DATA_DIR" \
            --log-dir "$LOGS_DIR/training"
        
        log_message "Training completed for symbols: $symbols"
        ;;
        
    status)
        echo "=== ML Model Status - Persistent Data ==="
        echo "Persistent Data Directory: $PERSISTENT_DATA_DIR"
        echo "Models Directory: $ML_MODELS_DIR"
        echo ""
        echo "📁 Directory Structure:"
        ls -la "$PERSISTENT_DATA_DIR" 2>/dev/null || echo "Persistent data directory not accessible"
        echo ""
        echo "🧠 ML Models:"
        ls -la "$ML_MODELS_DIR" 2>/dev/null || echo "No models found"
        echo ""
        echo "📊 Scalers:"
        ls -la "$SCALERS_DIR" 2>/dev/null || echo "No scalers found"
        echo ""
        echo "🔄 Cache:"
        ls -la "$ML_CACHE_DIR" 2>/dev/null || echo "No cache found"
        echo ""
        echo "⚙️ Configuration:"
        if [ -f "$CONFIG_DIR/ml_config.json" ]; then
            cat "$CONFIG_DIR/ml_config.json"
        else
            echo "No ML configuration found"
        fi
        echo ""
        echo "=== Supported Symbols ==="
        echo "$DEFAULT_SYMBOLS"
        echo ""
        echo "=== Model Files ==="
        for symbol in $DEFAULT_SYMBOLS; do
            model_file="$ML_MODELS_DIR/${symbol,,}_lstm_model.h5"
            if [ -f "$model_file" ]; then
                size=$(ls -lh "$model_file" | awk '{print $5}')
                date=$(ls -l "$model_file" | awk '{print $6, $7, $8}')
                echo "✅ $symbol: $size ($date)"
            else
                echo "❌ $symbol: Not trained"
            fi
        done
        ;;
        
    backup)
        log_message "Creating ML models backup..."
        backup_file="$BACKUPS_DIR/ml_models_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        tar -czf "$backup_file" -C "$PERSISTENT_DATA_DIR" ml_models scalers ml_cache
        log_message "Backup created: $backup_file"
        echo "✅ Backup created: $backup_file"
        ;;
        
    clean)
        log_message "Cleaning old cache and temporary files..."
        # Clean old cache files (older than 7 days)
        find "$ML_CACHE_DIR" -name "*.cache" -mtime +7 -delete 2>/dev/null || true
        # Clean old log files (older than 30 days)
        find "$LOGS_DIR" -name "*.log" -mtime +30 -delete 2>/dev/null || true
        log_message "Cleanup completed"
        echo "✅ Cleanup completed"
        ;;
        
    *)
        echo "ML Model Management Script - Persistent Data Edition"
        echo "Usage: $0 {train|status|backup|clean}"
        echo ""
        echo "Commands:"
        echo "  train [symbols]     - Train models for specified symbols (default: all)"
        echo "  status             - Show model status and persistent data info"
        echo "  backup             - Create backup of models and data"
        echo "  clean              - Clean old cache and log files"
        echo ""
        echo "Persistent Data Directory: $PERSISTENT_DATA_DIR"
        echo "Supported Symbols: $DEFAULT_SYMBOLS"
        echo ""
        echo "🔥 IMPORTANT: All data is stored in persistent_data/ directory"
        exit 1
        ;;
esac
