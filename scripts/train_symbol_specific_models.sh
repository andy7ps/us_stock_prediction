#!/bin/bash

# Symbol-Specific Model Training Script
# Creates individual ML models optimized for each stock symbol
# Author: Stock Prediction Service Development Team
# Created: 2025-08-19

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/symbol_specific_training_$(date +%Y%m%d_%H%M%S).log"
ML_DIR="$PROJECT_ROOT/scripts/ml"
MODELS_DIR="$PROJECT_ROOT/persistent_data/ml_models"
SYMBOLS="${SYMBOLS:-NVDA,TSLA,AAPL,MSFT,GOOGL,AMZN,AUR,PLTR,SMCI,TSM,MP,SMR,SPY,META,NOC,RTX,LMT}"

# Ensure directories exist
mkdir -p "$LOG_DIR" "$MODELS_DIR"

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

# Function to create symbol-specific Python training script
create_symbol_training_script() {
    local symbol="$1"
    local script_path="$ML_DIR/train_${symbol,,}_model.py"
    
    log_info "Creating symbol-specific training script for $symbol"
    
    cat > "$script_path" << 'EOF'
#!/usr/bin/env ./ml_env/bin/python3
"""
Symbol-Specific LSTM Model Training
Optimized for individual stock characteristics
"""

import sys
import os
import numpy as np
import pandas as pd
import yfinance as yf
from sklearn.preprocessing import MinMaxScaler
from sklearn.metrics import mean_absolute_percentage_error
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout, BatchNormalization
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau
import joblib
import json
from datetime import datetime, timedelta
import warnings
warnings.filterwarnings('ignore')

class SymbolSpecificTrainer:
    def __init__(self, symbol, lookback_days=60, prediction_days=1):
        self.symbol = symbol.upper()
        self.lookback_days = lookback_days
        self.prediction_days = prediction_days
        self.scaler = MinMaxScaler(feature_range=(0, 1))
        self.model = None
        self.feature_columns = []
        
        # Symbol-specific configurations
        self.symbol_configs = {
            'NVDA': {'epochs': 150, 'batch_size': 32, 'lstm_units': [128, 64, 32], 'dropout': 0.3},
            'TSLA': {'epochs': 120, 'batch_size': 32, 'lstm_units': [100, 50, 25], 'dropout': 0.25},
            'AAPL': {'epochs': 100, 'batch_size': 64, 'lstm_units': [80, 40, 20], 'dropout': 0.2},
            'MSFT': {'epochs': 100, 'batch_size': 64, 'lstm_units': [80, 40, 20], 'dropout': 0.2},
            'GOOGL': {'epochs': 120, 'batch_size': 32, 'lstm_units': [100, 50, 25], 'dropout': 0.25},
            'AMZN': {'epochs': 120, 'batch_size': 32, 'lstm_units': [100, 50, 25], 'dropout': 0.25},
            'MP': {'epochs': 200, 'batch_size': 16, 'lstm_units': [150, 75, 35], 'dropout': 0.4},  # High volatility
            'SMCI': {'epochs': 180, 'batch_size': 16, 'lstm_units': [120, 60, 30], 'dropout': 0.35},
            'DEFAULT': {'epochs': 100, 'batch_size': 32, 'lstm_units': [100, 50, 25], 'dropout': 0.25}
        }
        
        self.config = self.symbol_configs.get(self.symbol, self.symbol_configs['DEFAULT'])
        
    def get_symbol_specific_features(self, data):
        """Add symbol-specific technical indicators"""
        df = data.copy()
        
        # Basic technical indicators for all symbols
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
        df['MACD_Histogram'] = df['MACD'] - df['MACD_Signal']
        
        # Bollinger Bands
        df['BB_Middle'] = df['Close'].rolling(window=20).mean()
        bb_std = df['Close'].rolling(window=20).std()
        df['BB_Upper'] = df['BB_Middle'] + (bb_std * 2)
        df['BB_Lower'] = df['BB_Middle'] - (bb_std * 2)
        df['BB_Width'] = df['BB_Upper'] - df['BB_Lower']
        df['BB_Position'] = (df['Close'] - df['BB_Lower']) / df['BB_Width']
        
        # Volume indicators
        df['Volume_SMA'] = df['Volume'].rolling(window=20).mean()
        df['Volume_Ratio'] = df['Volume'] / df['Volume_SMA']
        
        # Price momentum
        df['Price_Change'] = df['Close'].pct_change()
        df['Price_Change_5'] = df['Close'].pct_change(5)
        df['Price_Change_10'] = df['Close'].pct_change(10)
        
        # Volatility
        df['Volatility'] = df['Price_Change'].rolling(window=20).std()
        
        # Symbol-specific features
        if self.symbol in ['NVDA', 'AMD', 'INTC']:  # Semiconductor stocks
            # Add tech sector specific indicators
            df['High_Low_Ratio'] = df['High'] / df['Low']
            df['Price_Volume_Trend'] = df['Price_Change'] * df['Volume_Ratio']
            
        elif self.symbol in ['MP', 'FCX', 'NEM']:  # Materials stocks
            # Add materials sector specific indicators
            df['Price_Volatility_Product'] = df['Close'] * df['Volatility']
            df['Volume_Price_Momentum'] = df['Volume_Ratio'] * df['Price_Change_5']
            
        elif self.symbol in ['TSLA', 'F', 'GM']:  # Auto stocks
            # Add automotive sector specific indicators
            df['Momentum_Strength'] = df['RSI'] * df['Price_Change']
            
        # Clean up NaN values
        df = df.fillna(method='ffill').fillna(method='bfill')
        
        return df
    
    def prepare_data(self, data):
        """Prepare data for training"""
        # Get features
        feature_data = self.get_symbol_specific_features(data)
        
        # Select feature columns (exclude basic OHLCV)
        feature_cols = [col for col in feature_data.columns 
                       if col not in ['Open', 'High', 'Low', 'Close', 'Volume', 'Adj Close']]
        
        self.feature_columns = feature_cols
        features = feature_data[feature_cols].values
        target = feature_data['Close'].values
        
        # Scale features
        features_scaled = self.scaler.fit_transform(features)
        
        # Create sequences
        X, y = [], []
        for i in range(self.lookback_days, len(features_scaled)):
            X.append(features_scaled[i-self.lookback_days:i])
            y.append(target[i])
        
        return np.array(X), np.array(y)
    
    def build_model(self, input_shape):
        """Build symbol-specific LSTM model"""
        model = Sequential()
        
        # First LSTM layer
        model.add(LSTM(units=self.config['lstm_units'][0], 
                      return_sequences=True, 
                      input_shape=input_shape))
        model.add(Dropout(self.config['dropout']))
        model.add(BatchNormalization())
        
        # Second LSTM layer
        model.add(LSTM(units=self.config['lstm_units'][1], 
                      return_sequences=True))
        model.add(Dropout(self.config['dropout']))
        model.add(BatchNormalization())
        
        # Third LSTM layer
        model.add(LSTM(units=self.config['lstm_units'][2]))
        model.add(Dropout(self.config['dropout']))
        model.add(BatchNormalization())
        
        # Dense layers
        model.add(Dense(units=25, activation='relu'))
        model.add(Dropout(0.1))
        model.add(Dense(units=1))
        
        # Compile model
        optimizer = Adam(learning_rate=0.001)
        model.compile(optimizer=optimizer, loss='mse', metrics=['mae'])
        
        return model
    
    def train_model(self, X_train, y_train, X_val, y_val):
        """Train the model"""
        # Build model
        self.model = self.build_model((X_train.shape[1], X_train.shape[2]))
        
        # Callbacks
        early_stopping = EarlyStopping(monitor='val_loss', patience=20, restore_best_weights=True)
        reduce_lr = ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=10, min_lr=0.0001)
        
        # Train model
        history = self.model.fit(
            X_train, y_train,
            batch_size=self.config['batch_size'],
            epochs=self.config['epochs'],
            validation_data=(X_val, y_val),
            callbacks=[early_stopping, reduce_lr],
            verbose=1
        )
        
        return history
    
    def evaluate_model(self, X_test, y_test):
        """Evaluate model performance"""
        predictions = self.model.predict(X_test)
        mape = mean_absolute_percentage_error(y_test, predictions) * 100
        
        return {
            'mape': mape,
            'predictions': predictions.flatten(),
            'actual': y_test
        }
    
    def save_model(self, model_dir):
        """Save the trained model and scaler"""
        symbol_dir = os.path.join(model_dir, f"{self.symbol.lower()}_specific")
        os.makedirs(symbol_dir, exist_ok=True)
        
        # Save model
        model_path = os.path.join(symbol_dir, f"{self.symbol.lower()}_lstm_model.h5")
        self.model.save(model_path)
        
        # Save scaler
        scaler_path = os.path.join(symbol_dir, f"{self.symbol.lower()}_scaler.pkl")
        joblib.dump(self.scaler, scaler_path)
        
        # Save feature columns
        features_path = os.path.join(symbol_dir, f"{self.symbol.lower()}_features.json")
        with open(features_path, 'w') as f:
            json.dump(self.feature_columns, f)
        
        # Save configuration
        config_path = os.path.join(symbol_dir, f"{self.symbol.lower()}_config.json")
        config_data = {
            'symbol': self.symbol,
            'lookback_days': self.lookback_days,
            'prediction_days': self.prediction_days,
            'feature_columns': self.feature_columns,
            'model_config': self.config,
            'trained_date': datetime.now().isoformat()
        }
        with open(config_path, 'w') as f:
            json.dump(config_data, f, indent=2)
        
        return {
            'model_path': model_path,
            'scaler_path': scaler_path,
            'features_path': features_path,
            'config_path': config_path
        }

def main():
    if len(sys.argv) != 2:
        print("Usage: python train_symbol_model.py <SYMBOL>")
        sys.exit(1)
    
    symbol = sys.argv[1].upper()
    print(f"Training symbol-specific model for {symbol}")
    
    # Initialize trainer
    trainer = SymbolSpecificTrainer(symbol)
    
    # Download data (2 years for better training)
    end_date = datetime.now()
    start_date = end_date - timedelta(days=730)
    
    print(f"Downloading data for {symbol}...")
    stock_data = yf.download(symbol, start=start_date, end=end_date)
    
    # Fix MultiIndex columns issue (yfinance compatibility)
    if isinstance(stock_data.columns, pd.MultiIndex):
        stock_data.columns = stock_data.columns.get_level_values(0)
    
    if stock_data.empty:
        print(f"No data available for {symbol}")
        sys.exit(1)
    
    print(f"Downloaded {len(stock_data)} days of data")
    
    # Prepare data
    print("Preparing data...")
    X, y = trainer.prepare_data(stock_data)
    
    # Split data (80% train, 10% val, 10% test)
    train_size = int(len(X) * 0.8)
    val_size = int(len(X) * 0.1)
    
    X_train = X[:train_size]
    y_train = y[:train_size]
    X_val = X[train_size:train_size+val_size]
    y_val = y[train_size:train_size+val_size]
    X_test = X[train_size+val_size:]
    y_test = y[train_size+val_size:]
    
    print(f"Training data shape: {X_train.shape}")
    print(f"Validation data shape: {X_val.shape}")
    print(f"Test data shape: {X_test.shape}")
    
    # Train model
    print(f"Training {symbol}-specific model...")
    history = trainer.train_model(X_train, y_train, X_val, y_val)
    
    # Evaluate model
    print("Evaluating model...")
    results = trainer.evaluate_model(X_test, y_test)
    
    print(f"Model MAPE: {results['mape']:.2f}%")
    
    # Save model
    model_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'persistent_data', 'ml_models')
    saved_paths = trainer.save_model(model_dir)
    
    print(f"Model saved to: {saved_paths['model_path']}")
    print(f"Scaler saved to: {saved_paths['scaler_path']}")
    print(f"Configuration saved to: {saved_paths['config_path']}")
    
    # Return results for shell script
    return {
        'symbol': symbol,
        'mape': results['mape'],
        'train_samples': len(X_train),
        'test_samples': len(X_test),
        'features': len(trainer.feature_columns),
        'saved_paths': saved_paths
    }

if __name__ == "__main__":
    results = main()
    print(f"Training completed for {results['symbol']} with {results['mape']:.2f}% MAPE")
EOF

    chmod +x "$script_path"
    log_success "Created training script for $symbol: $script_path"
}

# Function to train a symbol-specific model
train_symbol_model() {
    local symbol="$1"
    local max_retries=3
    local retry_count=0
    
    log_info "Training symbol-specific model for $symbol"
    
    # Create training script if it doesn't exist
    local script_path="$ML_DIR/train_${symbol,,}_model.py"
    if [ ! -f "$script_path" ]; then
        create_symbol_training_script "$symbol"
    fi
    
    while [ $retry_count -lt $max_retries ]; do
        if ./ml_env/bin/python3 "$script_path" "$symbol" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Successfully trained model for $symbol"
            return 0
        else
            retry_count=$((retry_count + 1))
            log_warning "Training failed for $symbol (attempt $retry_count/$max_retries)"
            if [ $retry_count -lt $max_retries ]; then
                log_info "Retrying in 10 seconds..."
                sleep 10
            fi
        fi
    done
    
    log_error "Failed to train model for $symbol after $max_retries attempts"
    return 1
}

# Function to validate trained model
validate_model() {
    local symbol="$1"
    local model_dir="$MODELS_DIR/${symbol,,}_specific"
    
    if [ -d "$model_dir" ]; then
        local model_file="$model_dir/${symbol,,}_lstm_model.h5"
        local scaler_file="$model_dir/${symbol,,}_scaler.pkl"
        local config_file="$model_dir/${symbol,,}_config.json"
        
        if [ -f "$model_file" ] && [ -f "$scaler_file" ] && [ -f "$config_file" ]; then
            log_success "Model validation passed for $symbol"
            return 0
        fi
    fi
    
    log_error "Model validation failed for $symbol"
    return 1
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Train symbol-specific ML models for improved prediction accuracy

Options:
  --symbols SYMBOLS     Comma-separated list of symbols to train (default: all)
  --parallel N          Number of parallel training processes (default: 1)
  --validate-only       Only validate existing models
  --retrain-all         Retrain all models even if they exist
  --help, -h            Show this help message

Examples:
  $0                                    # Train all symbols sequentially
  $0 --symbols NVDA,TSLA,MP             # Train specific symbols
  $0 --parallel 3                      # Train 3 symbols in parallel
  $0 --validate-only                   # Validate existing models
  $0 --retrain-all                     # Force retrain all models

Notes:
  - Each symbol gets optimized hyperparameters
  - High-volatility stocks (MP, NVDA) get special treatment
  - Models are saved in persistent_data/ml_models/
  - Training uses 2 years of historical data
EOF
}

# Main execution function
main() {
    local symbols_filter=""
    local parallel_jobs=1
    local validate_only="false"
    local retrain_all="false"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --symbols)
                symbols_filter="$2"
                shift 2
                ;;
            --parallel)
                parallel_jobs="$2"
                shift 2
                ;;
            --validate-only)
                validate_only="true"
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
    
    log_info "=== Symbol-Specific Model Training Started ==="
    log_info "Timestamp: $(date)"
    log_info "Symbols: ${symbols_filter:-$SYMBOLS}"
    log_info "Parallel Jobs: $parallel_jobs"
    log_info "Validate Only: $validate_only"
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
    if ! ./ml_env/bin/python3 -c "import tensorflow, yfinance, sklearn" 2>/dev/null; then
        log_error "Missing Python dependencies. Please install: tensorflow yfinance scikit-learn"
        exit 1
    fi
    
    local successful_models=0
    local failed_models=0
    local skipped_models=0
    
    if [ "$validate_only" = "true" ]; then
        log_info "=== Validating Existing Models ==="
        for symbol in "${symbols_to_process[@]}"; do
            symbol=$(echo "$symbol" | xargs)
            if [ -z "$symbol" ]; then continue; fi
            
            if validate_model "$symbol"; then
                successful_models=$((successful_models + 1))
            else
                failed_models=$((failed_models + 1))
            fi
        done
    else
        log_info "=== Training Symbol-Specific Models ==="
        
        # Process symbols
        for symbol in "${symbols_to_process[@]}"; do
            symbol=$(echo "$symbol" | xargs)
            if [ -z "$symbol" ]; then continue; fi
            
            # Check if model already exists
            if [ "$retrain_all" = "false" ] && validate_model "$symbol"; then
                log_info "Model for $symbol already exists and is valid, skipping"
                skipped_models=$((skipped_models + 1))
                continue
            fi
            
            # Train model
            if train_symbol_model "$symbol"; then
                successful_models=$((successful_models + 1))
            else
                failed_models=$((failed_models + 1))
            fi
            
            # Small delay between trainings
            sleep 2
        done
    fi
    
    # Summary
    log_success "=== Symbol-Specific Model Training Completed ==="
    log_info "Successful models: $successful_models"
    log_info "Failed models: $failed_models"
    log_info "Skipped models: $skipped_models"
    log_info "Total symbols processed: ${#symbols_to_process[@]}"
    log_info "Log file: $LOG_FILE"
    
    # Show next steps
    log_info ""
    log_info "🎯 Next steps:"
    log_info "   Create ensemble models: ./scripts/create_ensemble_models.sh"
    log_info "   Test symbol-specific predictions: ./scripts/test_symbol_models.sh"
    log_info "   Update prediction service: ./scripts/update_prediction_service.sh"
    
    if [ "$successful_models" -gt 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Execute main function
main "$@"
