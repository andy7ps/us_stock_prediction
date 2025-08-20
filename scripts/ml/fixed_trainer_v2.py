#!/usr/bin/env python3
"""
Fixed Symbol-Specific LSTM Model Training v2
Robust handling of pandas operations and yfinance API
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

def ensure_series(data):
    """Ensure data is a pandas Series, not DataFrame"""
    if isinstance(data, pd.DataFrame):
        if data.shape[1] == 1:
            return data.iloc[:, 0]
        else:
            raise ValueError(f"Cannot convert DataFrame with {data.shape[1]} columns to Series")
    return data

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
            'MP': {'epochs': 200, 'batch_size': 16, 'lstm_units': [150, 75, 35], 'dropout': 0.4},
            'SMCI': {'epochs': 180, 'batch_size': 16, 'lstm_units': [120, 60, 30], 'dropout': 0.35},
            'DEFAULT': {'epochs': 100, 'batch_size': 32, 'lstm_units': [100, 50, 25], 'dropout': 0.25}
        }
        
        self.config = self.symbol_configs.get(self.symbol, self.symbol_configs['DEFAULT'])
        
    def get_symbol_specific_features(self, data):
        """Add symbol-specific technical indicators with robust pandas handling"""
        df = data.copy()
        
        # Ensure we have basic columns
        required_cols = ['Open', 'High', 'Low', 'Close', 'Volume']
        for col in required_cols:
            if col not in df.columns:
                raise ValueError(f"Missing required column: {col}")
        
        # Basic technical indicators
        df['SMA_5'] = ensure_series(df['Close'].rolling(window=5).mean())
        df['SMA_10'] = ensure_series(df['Close'].rolling(window=10).mean())
        df['SMA_20'] = ensure_series(df['Close'].rolling(window=20).mean())
        df['EMA_12'] = ensure_series(df['Close'].ewm(span=12).mean())
        df['EMA_26'] = ensure_series(df['Close'].ewm(span=26).mean())
        
        # RSI with robust calculation
        delta = ensure_series(df['Close'].diff())
        gain = ensure_series((delta.where(delta > 0, 0)).rolling(window=14).mean())
        loss = ensure_series((-delta.where(delta < 0, 0)).rolling(window=14).mean())
        
        # Handle division by zero in RSI
        loss_safe = loss.replace(0, np.nan)
        rs = gain / loss_safe
        rsi_calc = 100 - (100 / (1 + rs))
        df['RSI'] = ensure_series(rsi_calc.fillna(50))
        
        # MACD
        df['MACD'] = ensure_series(df['EMA_12'] - df['EMA_26'])
        df['MACD_Signal'] = ensure_series(df['MACD'].ewm(span=9).mean())
        df['MACD_Histogram'] = ensure_series(df['MACD'] - df['MACD_Signal'])
        
        # Bollinger Bands with robust calculation
        bb_middle = ensure_series(df['Close'].rolling(window=20).mean())
        bb_std = ensure_series(df['Close'].rolling(window=20).std())
        
        df['BB_Middle'] = bb_middle
        df['BB_Upper'] = ensure_series(bb_middle + (bb_std * 2))
        df['BB_Lower'] = ensure_series(bb_middle - (bb_std * 2))
        df['BB_Width'] = ensure_series(df['BB_Upper'] - df['BB_Lower'])
        
        # BB Position with safe division
        bb_width_safe = df['BB_Width'].replace(0, np.nan)
        bb_position = (df['Close'] - df['BB_Lower']) / bb_width_safe
        df['BB_Position'] = ensure_series(bb_position.fillna(0.5))
        
        # Volume indicators with safe division
        volume_sma = ensure_series(df['Volume'].rolling(window=20).mean())
        df['Volume_SMA'] = volume_sma
        volume_sma_safe = volume_sma.replace(0, np.nan)
        volume_ratio = df['Volume'] / volume_sma_safe
        df['Volume_Ratio'] = ensure_series(volume_ratio.fillna(1.0))
        
        # Price momentum
        df['Price_Change'] = ensure_series(df['Close'].pct_change())
        df['Price_Change_5'] = ensure_series(df['Close'].pct_change(5))
        df['Price_Change_10'] = ensure_series(df['Close'].pct_change(10))
        
        # Volatility
        df['Volatility'] = ensure_series(df['Price_Change'].rolling(window=20).std())
        
        # Symbol-specific features with safe operations
        if self.symbol in ['NVDA', 'AMD', 'INTC']:  # Semiconductor stocks
            low_safe = df['Low'].replace(0, np.nan)
            high_low_ratio = df['High'] / low_safe
            df['High_Low_Ratio'] = ensure_series(high_low_ratio.fillna(1.0))
            df['Price_Volume_Trend'] = ensure_series(df['Price_Change'] * df['Volume_Ratio'])
            
        elif self.symbol in ['MP', 'FCX', 'NEM']:  # Materials stocks
            df['Price_Volatility_Product'] = ensure_series(df['Close'] * df['Volatility'])
            df['Volume_Price_Momentum'] = ensure_series(df['Volume_Ratio'] * df['Price_Change_5'])
            
        elif self.symbol in ['TSLA', 'F', 'GM']:  # Auto stocks
            df['Momentum_Strength'] = ensure_series(df['RSI'] * df['Price_Change'])
        
        # Clean up NaN and infinite values
        df = df.replace([np.inf, -np.inf], np.nan)
        df = df.fillna(method='ffill').fillna(method='bfill')
        df = df.fillna(0)  # Final fallback
        
        return df
    
    def prepare_data(self, data):
        """Prepare training data with features"""
        print("Adding technical indicators...")
        feature_data = self.get_symbol_specific_features(data)
        
        # Select feature columns (exclude non-numeric and target)
        exclude_cols = ['Dividends', 'Stock Splits']
        feature_cols = [col for col in feature_data.columns if col not in exclude_cols]
        
        # Store feature columns for later use
        self.feature_columns = feature_cols
        
        # Create sequences for LSTM
        print(f"Creating sequences with {len(feature_cols)} features...")
        scaled_data = self.scaler.fit_transform(feature_data[feature_cols])
        
        X, y = [], []
        for i in range(self.lookback_days, len(scaled_data) - self.prediction_days + 1):
            X.append(scaled_data[i-self.lookback_days:i])
            # Target is the Close price (index 3 in OHLCV)
            close_idx = feature_cols.index('Close')
            y.append(scaled_data[i + self.prediction_days - 1, close_idx])
        
        return np.array(X), np.array(y)
    
    def create_model(self, input_shape):
        """Create symbol-specific LSTM model"""
        model = Sequential()
        
        # First LSTM layer
        model.add(LSTM(self.config['lstm_units'][0], 
                      return_sequences=True, 
                      input_shape=input_shape))
        model.add(Dropout(self.config['dropout']))
        model.add(BatchNormalization())
        
        # Second LSTM layer
        model.add(LSTM(self.config['lstm_units'][1], 
                      return_sequences=True))
        model.add(Dropout(self.config['dropout']))
        model.add(BatchNormalization())
        
        # Third LSTM layer
        model.add(LSTM(self.config['lstm_units'][2]))
        model.add(Dropout(self.config['dropout']))
        model.add(BatchNormalization())
        
        # Dense layers
        model.add(Dense(25, activation='relu'))
        model.add(Dense(1))
        
        # Compile model
        model.compile(optimizer=Adam(learning_rate=0.001), 
                     loss='mse', 
                     metrics=['mae'])
        
        return model
    
    def train_model(self, X_train, y_train, X_val, y_val):
        """Train the LSTM model"""
        print(f"Training {self.symbol} model with configuration: {self.config}")
        
        # Create model
        self.model = self.create_model((X_train.shape[1], X_train.shape[2]))
        
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
            'predictions': predictions,
            'actual': y_test
        }
    
    def save_model(self, model_dir):
        """Save model, scaler, and configuration"""
        os.makedirs(model_dir, exist_ok=True)
        
        # Save paths
        model_path = os.path.join(model_dir, f'{self.symbol.lower()}_lstm_model.keras')
        scaler_path = os.path.join(model_dir, f'{self.symbol.lower()}_scaler.pkl')
        config_path = os.path.join(model_dir, f'{self.symbol.lower()}_config.json')
        
        # Save model
        self.model.save(model_path)
        
        # Save scaler
        joblib.dump(self.scaler, scaler_path)
        
        # Save configuration
        config_data = {
            'symbol': self.symbol,
            'lookback_days': self.lookback_days,
            'prediction_days': self.prediction_days,
            'feature_columns': self.feature_columns,
            'model_config': self.config,
            'created_at': datetime.now().isoformat()
        }
        
        with open(config_path, 'w') as f:
            json.dump(config_data, f, indent=2)
        
        return {
            'model_path': model_path,
            'scaler_path': scaler_path,
            'config_path': config_path
        }

def main():
    if len(sys.argv) != 2:
        print("Usage: python fixed_trainer_v2.py <SYMBOL>")
        sys.exit(1)
    
    symbol = sys.argv[1].upper()
    print(f"Training symbol-specific model for {symbol}")
    
    # Initialize trainer
    trainer = SymbolSpecificTrainer(symbol)
    
    # Download data
    print("Downloading data...")
    ticker = yf.Ticker(symbol)
    stock_data = ticker.history(period="500d")
    print(f"Downloaded {len(stock_data)} days of data")
    
    if len(stock_data) < 100:
        print(f"Insufficient data for {symbol}. Need at least 100 days.")
        sys.exit(1)
    
    # Prepare data
    print("Preparing data...")
    X, y = trainer.prepare_data(stock_data)
    
    # Split data
    train_size = int(len(X) * 0.8)
    val_size = int(len(X) * 0.1)
    
    X_train, X_val, X_test = X[:train_size], X[train_size:train_size+val_size], X[train_size+val_size:]
    y_train, y_val, y_test = y[:train_size], y[train_size:train_size+val_size], y[train_size+val_size:]
    
    print(f"Training samples: {len(X_train)}")
    print(f"Validation samples: {len(X_val)}")
    print(f"Test samples: {len(X_test)}")
    
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
