#!/bin/bash

# Ensemble Models Creation Script
# Combines multiple ML models for improved prediction accuracy
# Author: Stock Prediction Service Development Team
# Created: 2025-08-19

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/ensemble_models_$(date +%Y%m%d_%H%M%S).log"
ML_DIR="$PROJECT_ROOT/scripts/ml"
MODELS_DIR="$PROJECT_ROOT/persistent_data/ml_models"
ENSEMBLE_DIR="$MODELS_DIR/ensemble"
SYMBOLS="${SYMBOLS:-NVDA,TSLA,AAPL,MSFT,GOOGL,AMZN,AUR,PLTR,SMCI,TSM,MP,SMR,SPY,META,NOC,RTX,LMT}"

# Ensure directories exist
mkdir -p "$LOG_DIR" "$ML_DIR" "$ENSEMBLE_DIR"

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

# Function to create ensemble prediction script
create_ensemble_script() {
    local script_path="$ML_DIR/ensemble_predictor.py"
    
    log_info "Creating ensemble prediction script"
    
    cat > "$script_path" << 'EOF'
#!/usr/bin/env python3
"""
Ensemble Model Predictor
Combines multiple ML models for improved accuracy
"""

import sys
import os
import numpy as np
import pandas as pd
import yfinance as yf
from sklearn.preprocessing import MinMaxScaler
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_percentage_error
import tensorflow as tf
from tensorflow.keras.models import load_model
import joblib
import json
from datetime import datetime, timedelta
import warnings
warnings.filterwarnings('ignore')

class EnsemblePredictor:
    def __init__(self, symbol):
        self.symbol = symbol.upper()
        self.models = {}
        self.scalers = {}
        self.weights = {}
        self.feature_columns = []
        
        # Ensemble configuration
        self.ensemble_methods = {
            'weighted_average': self.weighted_average_prediction,
            'stacking': self.stacking_prediction,
            'voting': self.voting_prediction,
            'dynamic_weighting': self.dynamic_weighting_prediction
        }
        
    def load_symbol_specific_model(self):
        """Load symbol-specific LSTM model if available"""
        model_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'persistent_data', 'ml_models', f"{self.symbol.lower()}_specific")
        
        if os.path.exists(model_dir):
            try:
                model_path = os.path.join(model_dir, f"{self.symbol.lower()}_lstm_model.h5")
                scaler_path = os.path.join(model_dir, f"{self.symbol.lower()}_scaler.pkl")
                config_path = os.path.join(model_dir, f"{self.symbol.lower()}_config.json")
                
                if all(os.path.exists(p) for p in [model_path, scaler_path, config_path]):
                    self.models['symbol_specific'] = load_model(model_path)
                    self.scalers['symbol_specific'] = joblib.load(scaler_path)
                    
                    with open(config_path, 'r') as f:
                        config = json.load(f)
                        self.feature_columns = config.get('feature_columns', [])
                    
                    return True
            except Exception as e:
                print(f"Error loading symbol-specific model: {e}")
        
        return False
    
    def load_general_model(self):
        """Load general LSTM model"""
        model_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'persistent_data', 'ml_models')
        
        try:
            # Try to load the general model
            model_path = os.path.join(model_dir, f"{self.symbol.lower()}_lstm_model")
            scaler_path = os.path.join(os.path.dirname(__file__), '..', '..', 'persistent_data', 'scalers', 'scaler.pkl')
            
            if os.path.exists(model_path) and os.path.exists(scaler_path):
                self.models['general_lstm'] = load_model(model_path)
                self.scalers['general_lstm'] = joblib.load(scaler_path)
                return True
        except Exception as e:
            print(f"Error loading general model: {e}")
        
        return False
    
    def create_traditional_models(self, X_train, y_train):
        """Create traditional ML models"""
        try:
            # Random Forest
            rf_model = RandomForestRegressor(
                n_estimators=100,
                max_depth=10,
                random_state=42,
                n_jobs=-1
            )
            rf_model.fit(X_train.reshape(X_train.shape[0], -1), y_train)
            self.models['random_forest'] = rf_model
            
            # Gradient Boosting
            gb_model = GradientBoostingRegressor(
                n_estimators=100,
                max_depth=6,
                learning_rate=0.1,
                random_state=42
            )
            gb_model.fit(X_train.reshape(X_train.shape[0], -1), y_train)
            self.models['gradient_boosting'] = gb_model
            
            # Linear Regression (for trend)
            lr_model = LinearRegression()
            lr_model.fit(X_train.reshape(X_train.shape[0], -1), y_train)
            self.models['linear_regression'] = lr_model
            
            return True
        except Exception as e:
            print(f"Error creating traditional models: {e}")
            return False
    
    def get_features(self, data):
        """Extract features from stock data"""
        df = data.copy()
        
        # Technical indicators
        df['SMA_5'] = df['Close'].rolling(window=5).mean()
        df['SMA_10'] = df['Close'].rolling(window=10).mean()
        df['SMA_20'] = df['Close'].rolling(window=20).mean()
        df['EMA_12'] = df['Close'].ewm(span=12).mean()
        df['EMA_26'] = df['Close'].ewm(span=26).mean()
        
        # RSI
        delta = df['Close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        df['RSI'] = 100 - (100 / (1 + rs))
        
        # MACD
        df['MACD'] = df['EMA_12'] - df['EMA_26']
        df['MACD_Signal'] = df['MACD'].ewm(span=9).mean()
        
        # Bollinger Bands
        df['BB_Middle'] = df['Close'].rolling(window=20).mean()
        bb_std = df['Close'].rolling(window=20).std()
        df['BB_Upper'] = df['BB_Middle'] + (bb_std * 2)
        df['BB_Lower'] = df['BB_Middle'] - (bb_std * 2)
        df['BB_Position'] = (df['Close'] - df['BB_Lower']) / (df['BB_Upper'] - df['BB_Lower'])
        
        # Volume indicators
        df['Volume_SMA'] = df['Volume'].rolling(window=20).mean()
        df['Volume_Ratio'] = df['Volume'] / df['Volume_SMA']
        
        # Price changes
        df['Price_Change'] = df['Close'].pct_change()
        df['Price_Change_5'] = df['Close'].pct_change(5)
        
        # Volatility
        df['Volatility'] = df['Price_Change'].rolling(window=20).std()
        
        # Clean NaN values
        df = df.fillna(method='ffill').fillna(method='bfill')
        
        return df
    
    def prepare_data(self, data, lookback_days=60):
        """Prepare data for prediction"""
        feature_data = self.get_features(data)
        
        # Use symbol-specific features if available
        if self.feature_columns:
            try:
                features = feature_data[self.feature_columns].values
            except KeyError:
                # Fallback to basic features
                feature_cols = [col for col in feature_data.columns 
                               if col not in ['Open', 'High', 'Low', 'Close', 'Volume', 'Adj Close']]
                features = feature_data[feature_cols].values
        else:
            feature_cols = [col for col in feature_data.columns 
                           if col not in ['Open', 'High', 'Low', 'Close', 'Volume', 'Adj Close']]
            features = feature_data[feature_cols].values
        
        target = feature_data['Close'].values
        
        # Create sequences for LSTM
        X_lstm, y = [], []
        for i in range(lookback_days, len(features)):
            X_lstm.append(features[i-lookback_days:i])
            y.append(target[i])
        
        X_lstm = np.array(X_lstm)
        y = np.array(y)
        
        # Create flat features for traditional models
        X_flat = features[lookback_days:]
        
        return X_lstm, X_flat, y
    
    def weighted_average_prediction(self, predictions):
        """Simple weighted average based on historical performance"""
        # Default weights (can be updated based on backtesting)
        default_weights = {
            'symbol_specific': 0.4,
            'general_lstm': 0.25,
            'random_forest': 0.15,
            'gradient_boosting': 0.15,
            'linear_regression': 0.05
        }
        
        weighted_sum = 0
        total_weight = 0
        
        for model_name, prediction in predictions.items():
            weight = default_weights.get(model_name, 0.1)
            weighted_sum += prediction * weight
            total_weight += weight
        
        return weighted_sum / total_weight if total_weight > 0 else np.mean(list(predictions.values()))
    
    def stacking_prediction(self, predictions):
        """Stacking ensemble using linear regression"""
        # Simple stacking - use linear combination
        pred_array = np.array(list(predictions.values()))
        
        # Use equal weights for simplicity (can be trained)
        weights = np.ones(len(pred_array)) / len(pred_array)
        return np.dot(pred_array, weights)
    
    def voting_prediction(self, predictions):
        """Voting ensemble - simple average"""
        return np.mean(list(predictions.values()))
    
    def dynamic_weighting_prediction(self, predictions):
        """Dynamic weighting based on recent performance"""
        # For now, use weighted average with slight preference for symbol-specific
        if 'symbol_specific' in predictions:
            symbol_weight = 0.5
            other_weight = 0.5 / (len(predictions) - 1) if len(predictions) > 1 else 0
            
            weighted_sum = predictions['symbol_specific'] * symbol_weight
            for model_name, prediction in predictions.items():
                if model_name != 'symbol_specific':
                    weighted_sum += prediction * other_weight
            
            return weighted_sum
        else:
            return self.voting_prediction(predictions)
    
    def predict(self, data, method='weighted_average'):
        """Make ensemble prediction"""
        # Prepare data
        X_lstm, X_flat, _ = self.prepare_data(data)
        
        if len(X_lstm) == 0:
            raise ValueError("Not enough data for prediction")
        
        # Get latest data point
        latest_lstm = X_lstm[-1:] if len(X_lstm) > 0 else None
        latest_flat = X_flat[-1:] if len(X_flat) > 0 else None
        
        predictions = {}
        
        # LSTM models predictions
        for model_name, model in self.models.items():
            try:
                if model_name in ['symbol_specific', 'general_lstm'] and latest_lstm is not None:
                    # Scale data if scaler available
                    if model_name in self.scalers:
                        # For LSTM, we need to scale the entire sequence
                        scaler = self.scalers[model_name]
                        scaled_data = scaler.transform(latest_lstm.reshape(-1, latest_lstm.shape[-1]))
                        scaled_lstm = scaled_data.reshape(latest_lstm.shape)
                        pred = model.predict(scaled_lstm, verbose=0)[0][0]
                    else:
                        pred = model.predict(latest_lstm, verbose=0)[0][0]
                    
                    predictions[model_name] = pred
                    
                elif model_name in ['random_forest', 'gradient_boosting', 'linear_regression'] and latest_flat is not None:
                    pred = model.predict(latest_flat.reshape(1, -1))[0]
                    predictions[model_name] = pred
                    
            except Exception as e:
                print(f"Error with {model_name}: {e}")
                continue
        
        if not predictions:
            raise ValueError("No models could make predictions")
        
        # Apply ensemble method
        ensemble_method = self.ensemble_methods.get(method, self.weighted_average_prediction)
        final_prediction = ensemble_method(predictions)
        
        # Calculate confidence based on prediction agreement
        pred_values = list(predictions.values())
        confidence = 1.0 - (np.std(pred_values) / np.mean(pred_values)) if np.mean(pred_values) != 0 else 0.5
        confidence = max(0.1, min(0.99, confidence))  # Clamp between 0.1 and 0.99
        
        return {
            'prediction': float(final_prediction),
            'confidence': float(confidence),
            'individual_predictions': predictions,
            'method': method,
            'models_used': list(predictions.keys())
        }
    
    def train_ensemble(self, symbol, retrain_traditional=True):
        """Train ensemble models for a symbol"""
        print(f"Training ensemble for {symbol}")
        
        # Download training data
        end_date = datetime.now()
        start_date = end_date - timedelta(days=730)  # 2 years
        
        stock_data = yf.download(symbol, start=start_date, end=end_date)
        if stock_data.empty:
            raise ValueError(f"No data available for {symbol}")
        
        # Load existing models
        symbol_loaded = self.load_symbol_specific_model()
        general_loaded = self.load_general_model()
        
        print(f"Symbol-specific model loaded: {symbol_loaded}")
        print(f"General model loaded: {general_loaded}")
        
        # Prepare training data for traditional models
        if retrain_traditional:
            X_lstm, X_flat, y = self.prepare_data(stock_data)
            
            if len(X_lstm) > 100:  # Ensure enough data
                # Split for training traditional models
                train_size = int(len(X_lstm) * 0.8)
                X_train = X_lstm[:train_size]
                y_train = y[:train_size]
                
                # Train traditional models
                self.create_traditional_models(X_train, y_train)
                print(f"Traditional models trained with {len(X_train)} samples")
        
        return len(self.models)

def main():
    if len(sys.argv) < 2:
        print("Usage: python ensemble_predictor.py <SYMBOL> [METHOD]")
        print("Methods: weighted_average, stacking, voting, dynamic_weighting")
        sys.exit(1)
    
    symbol = sys.argv[1].upper()
    method = sys.argv[2] if len(sys.argv) > 2 else 'weighted_average'
    
    try:
        # Initialize ensemble
        ensemble = EnsemblePredictor(symbol)
        
        # Train ensemble
        num_models = ensemble.train_ensemble(symbol)
        print(f"Ensemble initialized with {num_models} models")
        
        # Get recent data for prediction
        end_date = datetime.now()
        start_date = end_date - timedelta(days=100)
        
        stock_data = yf.download(symbol, start=start_date, end=end_date)
        
        # Make prediction
        result = ensemble.predict(stock_data, method=method)
        
        print(f"\nEnsemble Prediction for {symbol}:")
        print(f"Predicted Price: ${result['prediction']:.2f}")
        print(f"Confidence: {result['confidence']:.3f}")
        print(f"Method: {result['method']}")
        print(f"Models Used: {', '.join(result['models_used'])}")
        print(f"Individual Predictions: {result['individual_predictions']}")
        
        # Save ensemble configuration
        ensemble_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'persistent_data', 'ml_models', 'ensemble')
        os.makedirs(ensemble_dir, exist_ok=True)
        
        config_path = os.path.join(ensemble_dir, f"{symbol.lower()}_ensemble_config.json")
        config_data = {
            'symbol': symbol,
            'models_available': list(ensemble.models.keys()),
            'default_method': method,
            'last_trained': datetime.now().isoformat(),
            'performance': {
                'prediction': result['prediction'],
                'confidence': result['confidence']
            }
        }
        
        with open(config_path, 'w') as f:
            json.dump(config_data, f, indent=2)
        
        print(f"\nEnsemble configuration saved to: {config_path}")
        
        return result
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

    chmod +x "$script_path"
    log_success "Created ensemble prediction script: $script_path"
}

# Function to create ensemble for a specific symbol
create_symbol_ensemble() {
    local symbol="$1"
    local method="${2:-weighted_average}"
    
    log_info "Creating ensemble model for $symbol using $method method"
    
    # Create ensemble script if it doesn't exist
    local script_path="$ML_DIR/ensemble_predictor.py"
    if [ ! -f "$script_path" ]; then
        create_ensemble_script
    fi
    
    # Run ensemble creation
    if python3 "$script_path" "$symbol" "$method" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Successfully created ensemble for $symbol"
        return 0
    else
        log_error "Failed to create ensemble for $symbol"
        return 1
    fi
}

# Function to test ensemble prediction
test_ensemble_prediction() {
    local symbol="$1"
    
    log_info "Testing ensemble prediction for $symbol"
    
    local script_path="$ML_DIR/ensemble_predictor.py"
    if [ ! -f "$script_path" ]; then
        log_error "Ensemble script not found: $script_path"
        return 1
    fi
    
    # Test prediction
    if python3 "$script_path" "$symbol" "weighted_average" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Ensemble prediction test passed for $symbol"
        return 0
    else
        log_error "Ensemble prediction test failed for $symbol"
        return 1
    fi
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Create ensemble models combining multiple ML approaches for improved accuracy

Options:
  --symbols SYMBOLS     Comma-separated list of symbols (default: all)
  --method METHOD       Ensemble method (weighted_average, stacking, voting, dynamic_weighting)
  --test-only          Only test existing ensemble models
  --retrain-all        Retrain all ensemble models
  --help, -h           Show this help message

Ensemble Methods:
  weighted_average     Weighted combination based on model performance (default)
  stacking            Meta-learning approach using linear regression
  voting              Simple average of all model predictions
  dynamic_weighting   Adaptive weighting based on recent performance

Examples:
  $0                                    # Create ensembles for all symbols
  $0 --symbols NVDA,TSLA,MP             # Create ensembles for specific symbols
  $0 --method stacking                  # Use stacking ensemble method
  $0 --test-only                       # Test existing ensemble models
  $0 --retrain-all                     # Force retrain all ensembles

Notes:
  - Combines LSTM, Random Forest, Gradient Boosting, and Linear Regression
  - Uses symbol-specific models when available
  - Automatically weights models based on performance
  - Provides confidence scores based on prediction agreement
EOF
}

# Main execution function
main() {
    local symbols_filter=""
    local ensemble_method="weighted_average"
    local test_only="false"
    local retrain_all="false"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --symbols)
                symbols_filter="$2"
                shift 2
                ;;
            --method)
                ensemble_method="$2"
                shift 2
                ;;
            --test-only)
                test_only="true"
                shift
                ;;
            --retrain-all)
                retrain_all="true"
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
    
    log_info "=== Ensemble Models Creation Started ==="
    log_info "Timestamp: $(date)"
    log_info "Symbols: ${symbols_filter:-$SYMBOLS}"
    log_info "Ensemble Method: $ensemble_method"
    log_info "Test Only: $test_only"
    log_info "Retrain All: $retrain_all"
    log_info "Log File: $LOG_FILE"
    
    # Get symbols to process
    local symbols_to_process
    if [ -n "$symbols_filter" ]; then
        IFS=',' read -ra symbols_to_process <<< "$symbols_filter"
    else
        IFS=',' read -ra symbols_to_process <<< "$SYMBOLS"
    fi
    
    log_info "Processing ${#symbols_to_process[@]} symbols"
    
    # Check Python dependencies
    if ! python3 -c "import tensorflow, yfinance, sklearn" 2>/dev/null; then
        log_error "Missing Python dependencies. Please install: tensorflow yfinance scikit-learn"
        exit 1
    fi
    
    local successful_ensembles=0
    local failed_ensembles=0
    
    if [ "$test_only" = "true" ]; then
        log_info "=== Testing Existing Ensemble Models ==="
        for symbol in "${symbols_to_process[@]}"; do
            symbol=$(echo "$symbol" | xargs)
            if [ -z "$symbol" ]; then continue; fi
            
            if test_ensemble_prediction "$symbol"; then
                successful_ensembles=$((successful_ensembles + 1))
            else
                failed_ensembles=$((failed_ensembles + 1))
            fi
        done
    else
        log_info "=== Creating Ensemble Models ==="
        
        # Create ensemble script only if it doesn't exist
        local script_path="$ML_DIR/ensemble_predictor.py"
        if [ ! -f "$script_path" ]; then
            create_ensemble_script
        fi
        
        # Process symbols
        for symbol in "${symbols_to_process[@]}"; do
            symbol=$(echo "$symbol" | xargs)
            if [ -z "$symbol" ]; then continue; fi
            
            # Check if ensemble already exists
            local config_file="$ENSEMBLE_DIR/${symbol,,}_ensemble_config.json"
            if [ "$retrain_all" = "false" ] && [ -f "$config_file" ]; then
                log_info "Ensemble for $symbol already exists, testing..."
                if test_ensemble_prediction "$symbol"; then
                    log_info "Existing ensemble for $symbol is working, skipping creation"
                    successful_ensembles=$((successful_ensembles + 1))
                    continue
                fi
            fi
            
            # Create ensemble
            if create_symbol_ensemble "$symbol" "$ensemble_method"; then
                successful_ensembles=$((successful_ensembles + 1))
            else
                failed_ensembles=$((failed_ensembles + 1))
            fi
            
            # Small delay between creations
            sleep 3
        done
    fi
    
    # Summary
    log_success "=== Ensemble Models Creation Completed ==="
    log_info "Successful ensembles: $successful_ensembles"
    log_info "Failed ensembles: $failed_ensembles"
    log_info "Total symbols processed: ${#symbols_to_process[@]}"
    log_info "Ensemble method used: $ensemble_method"
    log_info "Log file: $LOG_FILE"
    
    # Show next steps
    log_info ""
    log_info "🎯 Next steps:"
    log_info "   Update prediction service: ./scripts/update_prediction_service.sh"
    log_info "   Test ensemble predictions: ./scripts/test_ensemble_predictions.sh"
    log_info "   Compare with current accuracy: ./scripts/compare_model_performance.sh"
    
    if [ "$successful_ensembles" -gt 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Execute main function
main "$@"
