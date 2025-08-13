#!/bin/bash

# ML Model Management Script
# Enhanced version with support for all specified symbols

# Default symbols list
DEFAULT_SYMBOLS="NVDA TSLA AAPL MSFT GOOGL AMZN AUR PLTR SMCI TSM MP SMR SPY"

case "$1" in
    train)
        symbols="${@:2}"
        if [ -z "$symbols" ]; then
            symbols="$DEFAULT_SYMBOLS"
        fi
        echo "Training models for symbols: $symbols"
        source venv/bin/activate
        python3 scripts/ml/train_model.py --symbols $symbols --model-dir persistent_data/ml_models
        ;;
    evaluate)
        symbols="${@:2}"
        if [ -z "$symbols" ]; then
            symbols="$DEFAULT_SYMBOLS"
        fi
        echo "Evaluating models for symbols: $symbols"
        source venv/bin/activate
        python3 scripts/ml/evaluate_models.py --symbols $symbols --model-dir persistent_data/ml_models --output-dir evaluation_results
        ;;
    test)
        echo "Testing prediction with sample data..."
        source venv/bin/activate
        python3 scripts/ml/ensemble_predict.py "100,101,102,103,104,105,106,107,108,109,110"
        ;;
    test-symbol)
        symbol="${2:-NVDA}"
        echo "Testing prediction for $symbol..."
        curl -s "http://localhost:8081/api/v1/predict/$symbol" | jq . 2>/dev/null || curl -s "http://localhost:8081/api/v1/predict/$symbol"
        ;;
    status)
        echo "=== ML Model Status ==="
        echo "Models directory: persistent_data/ml_models"
        ls -la persistent_data/ml_models/
        echo
        echo "Configuration:"
        if [ -f "persistent_data/ml_config.json" ]; then
            cat persistent_data/ml_config.json
        else
            echo "No ML configuration found"
        fi
        echo
        echo "=== Supported Symbols ==="
        echo "$DEFAULT_SYMBOLS"
        echo
        echo "=== Model Files ==="
        for symbol in $DEFAULT_SYMBOLS; do
            model_file="persistent_data/ml_models/${symbol,,}_lstm_model.h5"
            if [ -f "$model_file" ]; then
                size=$(ls -lh "$model_file" | awk '{print $5}')
                date=$(ls -l "$model_file" | awk '{print $6, $7, $8}')
                echo "✅ $symbol: $size ($date)"
            else
                echo "❌ $symbol: Not trained"
            fi
        done
        ;;
    train-all)
        echo "Training models for all supported symbols: $DEFAULT_SYMBOLS"
        source venv/bin/activate
        python3 scripts/ml/train_model.py --symbols $DEFAULT_SYMBOLS --model-dir persistent_data/ml_models
        ;;
    quick-train)
        symbols="${@:2}"
        if [ -z "$symbols" ]; then
            symbols="NVDA TSLA AAPL"
        fi
        echo "Quick training (10 epochs) for symbols: $symbols"
        source venv/bin/activate
        python3 scripts/ml/train_model.py --symbols $symbols --epochs 10 --model-dir persistent_data/ml_models
        ;;
    performance)
        echo "=== Performance Monitoring ==="
        ./monitor_performance.sh
        ;;
    auto-train)
        echo "=== Automatic Training ==="
        ./enhanced_training.sh "$@"
        ;;
    backup)
        backup_dir="persistent_data/ml_models/backup_$(date +%Y%m%d_%H%M%S)"
        echo "Backing up models to $backup_dir"
        mkdir -p "$backup_dir"
        cp persistent_data/ml_models/*.h5 persistent_data/ml_models/*.pkl "$backup_dir/" 2>/dev/null || true
        echo "Backup completed"
        ;;
    clean)
        echo "Cleaning old model files and logs..."
        find persistent_data/ml_models -name "*.h5" -mtime +30 -delete 2>/dev/null || true
        find logs -name "*.log" -mtime +7 -delete 2>/dev/null || true
        echo "Cleanup completed"
        ;;
    *)
        echo "Usage: $0 {train|evaluate|test|test-symbol|status|train-all|quick-train|performance|auto-train|backup|clean} [symbols...]"
        echo
        echo "Commands:"
        echo "  train [symbols...]     Train models for specific symbols (default: all)"
        echo "  evaluate [symbols...]  Evaluate models for specific symbols (default: all)"
        echo "  test                   Test prediction with sample data"
        echo "  test-symbol [symbol]   Test API prediction for specific symbol"
        echo "  status                 Show model status and configuration"
        echo "  train-all              Train models for all supported symbols"
        echo "  quick-train [symbols]  Quick training with 10 epochs"
        echo "  performance            Run performance monitoring"
        echo "  auto-train [options]   Run automatic training with performance checks"
        echo "  backup                 Backup current models"
        echo "  clean                  Clean old model files and logs"
        echo
        echo "Supported symbols: $DEFAULT_SYMBOLS"
        echo
        echo "Examples:"
        echo "  $0 train NVDA TSLA AAPL"
        echo "  $0 evaluate MSFT GOOGL"
        echo "  $0 test-symbol NVDA"
        echo "  $0 auto-train --force"
        ;;
esac
