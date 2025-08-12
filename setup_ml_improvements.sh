#!/bin/bash

# ML Improvements Setup Script
# Sets up advanced ML models and dependencies for stock prediction

set -e

echo "=== Stock Prediction ML Improvements Setup ==="
echo "This script will install advanced ML dependencies and train initial models"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "main.go" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Create necessary directories
print_status "Creating ML directories..."
mkdir -p persistent_data/ml_models
mkdir -p persistent_data/ml_cache
mkdir -p persistent_data/scalers
mkdir -p logs/ml
mkdir -p scripts/ml/models
mkdir -p evaluation_results

# Check Python version
print_status "Checking Python version..."
python_version=$(python3 --version 2>&1 | cut -d' ' -f2)
print_status "Python version: $python_version"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    print_status "Creating Python virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
print_status "Activating virtual environment..."
source venv/bin/activate

# Upgrade pip
print_status "Upgrading pip..."
pip install --upgrade pip

# Install basic requirements first
print_status "Installing basic ML requirements..."
pip install numpy pandas scikit-learn joblib

# Install TensorFlow (with fallback for different systems)
print_status "Installing TensorFlow..."
if pip install tensorflow==2.13.0; then
    print_success "TensorFlow installed successfully"
else
    print_warning "TensorFlow installation failed, trying CPU-only version..."
    if pip install tensorflow-cpu==2.13.0; then
        print_success "TensorFlow CPU installed successfully"
    else
        print_error "TensorFlow installation failed completely"
        print_warning "Deep learning models will not be available"
    fi
fi

# Install financial data library
print_status "Installing yfinance for real market data..."
if pip install yfinance==0.2.18; then
    print_success "yfinance installed successfully"
else
    print_warning "yfinance installation failed, using dummy data for training"
fi

# Install additional ML libraries
print_status "Installing additional ML libraries..."
pip install matplotlib seaborn plotly tqdm requests

# Try to install optional advanced libraries
print_status "Installing optional advanced ML libraries..."
optional_packages=("xgboost" "lightgbm")

for package in "${optional_packages[@]}"; do
    if pip install "$package"; then
        print_success "$package installed successfully"
    else
        print_warning "$package installation failed (optional)"
    fi
done

# Make ML scripts executable
print_status "Making ML scripts executable..."
chmod +x scripts/ml/*.py

# Test basic functionality
print_status "Testing basic ML functionality..."

# Test enhanced prediction
if python3 scripts/ml/enhanced_predict.py "100,101,102,103,104" > /dev/null 2>&1; then
    print_success "Enhanced prediction model working"
else
    print_error "Enhanced prediction model test failed"
fi

# Test LSTM model (fallback mode)
if python3 scripts/ml/lstm_model.py "100,101,102,103,104" > /dev/null 2>&1; then
    print_success "LSTM model working (fallback mode)"
else
    print_error "LSTM model test failed"
fi

# Test ensemble model
if python3 scripts/ml/ensemble_predict.py "100,101,102,103,104" > /dev/null 2>&1; then
    print_success "Ensemble model working"
else
    print_error "Ensemble model test failed"
fi

# Create configuration for ML models
print_status "Creating ML configuration..."
cat > persistent_data/ml_config.json << EOF
{
    "model_version": "v3.3.0",
    "created_date": "$(date -Iseconds)",
    "models": {
        "lstm": {
            "enabled": true,
            "sequence_length": 60,
            "features": ["close", "volume", "technical_indicators"]
        },
        "ensemble": {
            "enabled": true,
            "methods": ["lstm", "enhanced", "sklearn"],
            "dynamic_weighting": true
        },
        "enhanced": {
            "enabled": true,
            "indicators": ["sma", "ema", "rsi", "macd", "bollinger"]
        }
    },
    "training": {
        "default_epochs": 50,
        "batch_size": 32,
        "validation_split": 0.2,
        "early_stopping": true
    }
}
EOF

# Update Go service configuration to use new models
print_status "Updating Go service configuration..."
if [ -f ".env" ]; then
    # Update existing .env file
    if grep -q "ML_PYTHON_SCRIPT" .env; then
        sed -i 's|ML_PYTHON_SCRIPT=.*|ML_PYTHON_SCRIPT=scripts/ml/ensemble_predict.py|' .env
    else
        echo "ML_PYTHON_SCRIPT=scripts/ml/ensemble_predict.py" >> .env
    fi
    
    if grep -q "ML_MODEL_VERSION" .env; then
        sed -i 's|ML_MODEL_VERSION=.*|ML_MODEL_VERSION=v3.3.0|' .env
    else
        echo "ML_MODEL_VERSION=v3.3.0" >> .env
    fi
else
    # Create new .env file
    cp .env.example .env
    echo "ML_PYTHON_SCRIPT=scripts/ml/ensemble_predict.py" >> .env
    echo "ML_MODEL_VERSION=v3.2.0" >> .env
fi

# Offer to train initial models
echo
read -p "Would you like to train initial models with sample data? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Training initial models..."
    
    # Train models for popular stocks
    symbols=("NVDA" "TSLA" "AAPL")
    
    for symbol in "${symbols[@]}"; do
        print_status "Training model for $symbol..."
        if python3 scripts/ml/train_model.py --symbols "$symbol" --epochs 20 --model-dir persistent_data/ml_models; then
            print_success "Model training completed for $symbol"
        else
            print_warning "Model training failed for $symbol (will use statistical fallback)"
        fi
    done
    
    # Run evaluation
    print_status "Running model evaluation..."
    if python3 scripts/ml/evaluate_models.py --symbols "${symbols[@]}" --model-dir persistent_data/ml_models --output-dir evaluation_results; then
        print_success "Model evaluation completed"
        print_status "Check evaluation_results/ directory for detailed reports"
    else
        print_warning "Model evaluation failed"
    fi
fi

# Create model management script
print_status "Creating model management script..."
cat > manage_ml_models.sh << 'EOF'
#!/bin/bash

# ML Model Management Script

case "$1" in
    train)
        echo "Training models for symbols: ${@:2}"
        python3 scripts/ml/train_model.py --symbols "${@:2}" --model-dir persistent_data/ml_models
        ;;
    evaluate)
        echo "Evaluating models for symbols: ${@:2}"
        python3 scripts/ml/evaluate_models.py --symbols "${@:2}" --model-dir persistent_data/ml_models --output-dir evaluation_results
        ;;
    test)
        echo "Testing prediction with sample data..."
        python3 scripts/ml/ensemble_predict.py "100,101,102,103,104,105,106,107,108,109,110"
        ;;
    status)
        echo "=== ML Model Status ==="
        echo "Models directory: persistent_data/ml_models"
        ls -la persistent_data/ml_models/
        echo
        echo "Configuration:"
        cat persistent_data/ml_config.json
        ;;
    *)
        echo "Usage: $0 {train|evaluate|test|status} [symbols...]"
        echo "Examples:"
        echo "  $0 train NVDA TSLA AAPL"
        echo "  $0 evaluate NVDA TSLA"
        echo "  $0 test"
        echo "  $0 status"
        ;;
esac
EOF

chmod +x manage_ml_models.sh

# Update Docker configuration
print_status "Updating Docker configuration..."
if [ -f "Dockerfile" ]; then
    # Check if TensorFlow is already in Dockerfile
    if ! grep -q "tensorflow" Dockerfile; then
        print_status "Adding ML dependencies to Dockerfile..."
        # Add after the requirements.txt installation
        sed -i '/RUN pip install -r requirements.txt/a RUN pip install tensorflow==2.13.0 || pip install tensorflow-cpu==2.13.0' Dockerfile
    fi
fi

# Create ML monitoring script
print_status "Creating ML monitoring script..."
cat > scripts/ml/monitor_predictions.py << 'EOF'
#!/usr/bin/env python3
"""
ML Prediction Monitoring Script
Monitors prediction accuracy and model performance over time.
"""

import json
import os
from datetime import datetime
import numpy as np

def log_prediction(symbol, actual_price, predicted_price, model_used):
    """Log a prediction for monitoring."""
    log_entry = {
        'timestamp': datetime.now().isoformat(),
        'symbol': symbol,
        'actual_price': actual_price,
        'predicted_price': predicted_price,
        'model_used': model_used,
        'error': abs(actual_price - predicted_price),
        'error_percentage': abs(actual_price - predicted_price) / actual_price * 100
    }
    
    log_file = 'logs/ml/prediction_log.jsonl'
    os.makedirs(os.path.dirname(log_file), exist_ok=True)
    
    with open(log_file, 'a') as f:
        f.write(json.dumps(log_entry) + '\n')

def analyze_performance():
    """Analyze recent prediction performance."""
    log_file = 'logs/ml/prediction_log.jsonl'
    
    if not os.path.exists(log_file):
        print("No prediction logs found")
        return
    
    predictions = []
    with open(log_file, 'r') as f:
        for line in f:
            predictions.append(json.loads(line.strip()))
    
    if not predictions:
        print("No predictions to analyze")
        return
    
    # Calculate metrics
    errors = [p['error_percentage'] for p in predictions]
    
    print(f"=== Prediction Performance Analysis ===")
    print(f"Total predictions: {len(predictions)}")
    print(f"Average error: {np.mean(errors):.2f}%")
    print(f"Median error: {np.median(errors):.2f}%")
    print(f"Max error: {np.max(errors):.2f}%")
    print(f"Min error: {np.min(errors):.2f}%")
    
    # Model breakdown
    models = {}
    for p in predictions:
        model = p['model_used']
        if model not in models:
            models[model] = []
        models[model].append(p['error_percentage'])
    
    print(f"\n=== Performance by Model ===")
    for model, errors in models.items():
        print(f"{model}: {np.mean(errors):.2f}% avg error ({len(errors)} predictions)")

if __name__ == "__main__":
    analyze_performance()
EOF

chmod +x scripts/ml/monitor_predictions.py

# Final status
echo
print_success "=== ML Improvements Setup Complete ==="
echo
print_status "What was installed:"
echo "  ✓ Advanced LSTM neural network model"
echo "  ✓ Ensemble prediction combining multiple algorithms"
echo "  ✓ Enhanced technical analysis features"
echo "  ✓ Model training and evaluation scripts"
echo "  ✓ Performance monitoring tools"
echo
print_status "Key files created:"
echo "  • scripts/ml/lstm_model.py - Advanced LSTM model"
echo "  • scripts/ml/ensemble_predict.py - Ensemble predictor"
echo "  • scripts/ml/train_model.py - Model training script"
echo "  • scripts/ml/evaluate_models.py - Model evaluation"
echo "  • manage_ml_models.sh - Model management commands"
echo
print_status "Next steps:"
echo "  1. Test the new models: ./manage_ml_models.sh test"
echo "  2. Train models with real data: ./manage_ml_models.sh train NVDA TSLA AAPL"
echo "  3. Evaluate performance: ./manage_ml_models.sh evaluate NVDA TSLA AAPL"
echo "  4. Restart your Go service to use the new ensemble model"
echo
print_status "The Go service will now use the ensemble model by default"
print_status "Check evaluation_results/ for detailed performance reports"
echo

# Deactivate virtual environment
deactivate

print_success "Setup completed successfully!"
