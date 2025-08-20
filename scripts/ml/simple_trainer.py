#!/usr/bin/env python3
"""
Simple Symbol-Specific LSTM Model Training
Handles yfinance MultiIndex columns properly
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
from tensorflow.keras.layers import LSTM, Dense, Dropout
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.callbacks import EarlyStopping
import joblib
import json
from datetime import datetime, timedelta
import warnings
warnings.filterwarnings('ignore')

def download_and_prepare_data(symbol, days=730):
    """Download and prepare stock data"""
    end_date = datetime.now()
    start_date = end_date - timedelta(days=days)
    
    print(f"Downloading data for {symbol}...")
    data = yf.download(symbol, start=start_date, end=end_date, progress=False)
    
    if data.empty:
        raise ValueError(f"No data available for {symbol}")
    
    # Handle MultiIndex columns from yfinance
    if isinstance(data.columns, pd.MultiIndex):
        # Flatten the MultiIndex columns
        data.columns = [col[0] for col in data.columns]
    
    print(f"Downloaded {len(data)} days of data")
    return data

def create_features(data):
    """Create technical indicators"""
    df = data.copy()
    
    # Basic moving averages
    df['SMA_5'] = df['Close'].rolling(window=5).mean()
    df['SMA_10'] = df['Close'].rolling(window=10).mean()
    df['SMA_20'] = df['Close'].rolling(window=20).mean()
    
    # Exponential moving averages
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
    
    # Price changes
    df['Price_Change'] = df['Close'].pct_change()
    df['Price_Change_5'] = df['Close'].pct_change(5)
    
    # Volatility
    df['Volatility'] = df['Price_Change'].rolling(window=20).std()
    
    # Volume ratio
    df['Volume_SMA'] = df['Volume'].rolling(window=20).mean()
    df['Volume_Ratio'] = df['Volume'] / df['Volume_SMA']
    
    # High-Low ratio
    df['High_Low_Ratio'] = df['High'] / df['Low']
    
    # Clean up NaN values
    df = df.fillna(method='ffill').fillna(method='bfill').fillna(0)
    
    return df

def prepare_lstm_data(data, lookback_days=60):
    """Prepare data for LSTM training"""
    # Create features
    feature_data = create_features(data)
    
    # Select feature columns (exclude basic OHLCV)
    feature_cols = [col for col in feature_data.columns 
                   if col not in ['Open', 'High', 'Low', 'Close', 'Volume']]
    
    features = feature_data[feature_cols].values
    target = feature_data['Close'].values
    
    # Scale features
    scaler = MinMaxScaler(feature_range=(0, 1))
    features_scaled = scaler.fit_transform(features)
    
    # Create sequences
    X, y = [], []
    for i in range(lookback_days, len(features_scaled)):
        X.append(features_scaled[i-lookback_days:i])
        y.append(target[i])
    
    return np.array(X), np.array(y), scaler, feature_cols

def create_model(input_shape, symbol):
    """Create LSTM model with symbol-specific configuration"""
    # Symbol-specific configurations
    configs = {
        'NVDA': {'units': [128, 64, 32], 'dropout': 0.3, 'epochs': 50},
        'MP': {'units': [150, 75, 35], 'dropout': 0.4, 'epochs': 60},
        'TSLA': {'units': [100, 50, 25], 'dropout': 0.25, 'epochs': 40},
        'DEFAULT': {'units': [100, 50, 25], 'dropout': 0.25, 'epochs': 40}
    }
    
    config = configs.get(symbol, configs['DEFAULT'])
    
    model = Sequential([
        LSTM(units=config['units'][0], return_sequences=True, input_shape=input_shape),
        Dropout(config['dropout']),
        LSTM(units=config['units'][1], return_sequences=True),
        Dropout(config['dropout']),
        LSTM(units=config['units'][2]),
        Dropout(config['dropout']),
        Dense(units=25, activation='relu'),
        Dense(units=1)
    ])
    
    model.compile(optimizer=Adam(learning_rate=0.001), loss='mse', metrics=['mae'])
    return model, config

def train_model(symbol):
    """Train symbol-specific model"""
    print(f"Training symbol-specific model for {symbol}")
    
    # Download and prepare data
    data = download_and_prepare_data(symbol)
    X, y, scaler, feature_cols = prepare_lstm_data(data)
    
    if len(X) < 100:
        raise ValueError(f"Not enough data for training {symbol} (need at least 100 samples, got {len(X)})")
    
    # Split data
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
    
    # Create and train model
    model, config = create_model((X_train.shape[1], X_train.shape[2]), symbol)
    
    early_stopping = EarlyStopping(monitor='val_loss', patience=10, restore_best_weights=True)
    
    print(f"Training {symbol}-specific model...")
    history = model.fit(
        X_train, y_train,
        batch_size=32,
        epochs=config['epochs'],
        validation_data=(X_val, y_val),
        callbacks=[early_stopping],
        verbose=1
    )
    
    # Evaluate model
    predictions = model.predict(X_test)
    mape = mean_absolute_percentage_error(y_test, predictions) * 100
    
    print(f"Model MAPE: {mape:.2f}%")
    
    # Save model
    model_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'persistent_data', 'ml_models')
    symbol_dir = os.path.join(model_dir, f"{symbol.lower()}_specific")
    os.makedirs(symbol_dir, exist_ok=True)
    
    # Save model files
    model_path = os.path.join(symbol_dir, f"{symbol.lower()}_lstm_model.h5")
    scaler_path = os.path.join(symbol_dir, f"{symbol.lower()}_scaler.pkl")
    config_path = os.path.join(symbol_dir, f"{symbol.lower()}_config.json")
    
    model.save(model_path)
    joblib.dump(scaler, scaler_path)
    
    # Save configuration
    config_data = {
        'symbol': symbol,
        'mape': float(mape),
        'feature_columns': feature_cols,
        'model_config': config,
        'trained_date': datetime.now().isoformat(),
        'train_samples': len(X_train),
        'test_samples': len(X_test)
    }
    
    with open(config_path, 'w') as f:
        json.dump(config_data, f, indent=2)
    
    print(f"Model saved to: {model_path}")
    print(f"Scaler saved to: {scaler_path}")
    print(f"Configuration saved to: {config_path}")
    
    return {
        'symbol': symbol,
        'mape': mape,
        'model_path': model_path,
        'scaler_path': scaler_path,
        'config_path': config_path
    }

def main():
    if len(sys.argv) != 2:
        print("Usage: python simple_trainer.py <SYMBOL>")
        sys.exit(1)
    
    symbol = sys.argv[1].upper()
    
    try:
        results = train_model(symbol)
        print(f"Training completed for {results['symbol']} with {results['mape']:.2f}% MAPE")
        return 0
    except Exception as e:
        print(f"Error training model for {symbol}: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())
