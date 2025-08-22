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
            'BRK/B': {'epochs': 100, 'batch_size': 32, 'lstm_units': [80, 40, 20], 'dropout': 0.2},  # Lower volatility value stock
            'DEFAULT': {'epochs': 100, 'batch_size': 32, 'lstm_units': [100, 50, 25], 'dropout': 0.25}
        }
        
        self.config = self.symbol_configs.get(self.symbol, self.symbol_configs['DEFAULT'])
        
    def get_symbol_specific_features(self, data):
        """Add symbol-specific technical indicators"""
        # Price-based features
        data['price_change'] = data['Close'].pct_change()
        data['price_change_2d'] = data['Close'].pct_change(periods=2)
        data['price_change_5d'] = data['Close'].pct_change(periods=5)
        
        # Moving averages
        data['ma_5'] = data['Close'].rolling(window=5).mean()
        data['ma_10'] = data['Close'].rolling(window=10).mean()
        data['ma_20'] = data['Close'].rolling(window=20).mean()
        data['ma_50'] = data['Close'].rolling(window=50).mean()
        data['ma_100'] = data['Close'].rolling(window=100).mean()  # Longer term for value stock
        
        # Moving average ratios
        data['ma_ratio_5_20'] = data['ma_5'] / data['ma_20']
        data['ma_ratio_10_50'] = data['ma_10'] / data['ma_50']
        data['ma_ratio_20_100'] = data['ma_20'] / data['ma_100']  # Long-term trend
        
        # Volatility features (lower for value stocks)
        data['volatility_5d'] = data['price_change'].rolling(window=5).std()
        data['volatility_20d'] = data['price_change'].rolling(window=20).std()
        
        # Volume features
        data['volume_ma_10'] = data['Volume'].rolling(window=10).mean()
        data['volume_ratio'] = data['Volume'] / data['volume_ma_10']
        
        # Price position features
        data['high_low_ratio'] = data['High'] / data['Low']
        data['close_high_ratio'] = data['Close'] / data['High']
        data['close_low_ratio'] = data['Close'] / data['Low']
        
        # Bollinger Bands
        data['bb_middle'] = data['Close'].rolling(window=20).mean()
        data['bb_std'] = data['Close'].rolling(window=20).std()
        data['bb_upper'] = data['bb_middle'] + (data['bb_std'] * 2)
        data['bb_lower'] = data['bb_middle'] - (data['bb_std'] * 2)
        data['bb_position'] = (data['Close'] - data['bb_lower']) / (data['bb_upper'] - data['bb_lower'])
        
        # RSI
        delta = data['Close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        data['rsi'] = 100 - (100 / (1 + rs))
        
        # MACD
        exp1 = data['Close'].ewm(span=12).mean()
        exp2 = data['Close'].ewm(span=26).mean()
        data['macd'] = exp1 - exp2
        data['macd_signal'] = data['macd'].ewm(span=9).mean()
        data['macd_histogram'] = data['macd'] - data['macd_signal']
        
        # Long-term trend features for value investing
        data['long_term_trend'] = data['Close'] / data['Close'].shift(252) - 1  # 1-year trend
        data['quarterly_trend'] = data['Close'] / data['Close'].shift(63) - 1   # Quarterly trend
        
        return data
    
    def prepare_features(self, data):
        """Prepare feature columns for training"""
        feature_columns = [
            'Close', 'Volume', 'High', 'Low', 'Open',
            'price_change', 'price_change_2d', 'price_change_5d',
            'ma_5', 'ma_10', 'ma_20', 'ma_50', 'ma_100',
            'ma_ratio_5_20', 'ma_ratio_10_50', 'ma_ratio_20_100',
            'volatility_5d', 'volatility_20d',
            'volume_ratio', 'high_low_ratio', 'close_high_ratio', 'close_low_ratio',
            'bb_position', 'rsi', 'macd', 'macd_signal', 'macd_histogram',
            'long_term_trend', 'quarterly_trend'
        ]
        
        # Filter out columns that don't exist or have all NaN values
        available_columns = []
        for col in feature_columns:
            if col in data.columns and not data[col].isna().all():
                available_columns.append(col)
        
        self.feature_columns = available_columns
        return data[available_columns].fillna(method='ffill').fillna(method='bfill')
    
    def create_sequences(self, data, target_col='Close'):
        """Create sequences for LSTM training"""
        X, y = [], []
        
        for i in range(self.lookback_days, len(data) - self.prediction_days + 1):
            X.append(data.iloc[i-self.lookback_days:i].values)
            y.append(data[target_col].iloc[i + self.prediction_days - 1])
        
        return np.array(X), np.array(y)
    
    def build_model(self, input_shape):
        """Build LSTM model with symbol-specific configuration"""
        model = Sequential()
        
        # First LSTM layer
        model.add(LSTM(
            units=self.config['lstm_units'][0],
            return_sequences=True,
            input_shape=input_shape
        ))
        model.add(BatchNormalization())
        model.add(Dropout(self.config['dropout']))
        
        # Second LSTM layer
        model.add(LSTM(
            units=self.config['lstm_units'][1],
            return_sequences=True
        ))
        model.add(BatchNormalization())
        model.add(Dropout(self.config['dropout']))
        
        # Third LSTM layer
        model.add(LSTM(
            units=self.config['lstm_units'][2],
            return_sequences=False
        ))
        model.add(BatchNormalization())
        model.add(Dropout(self.config['dropout']))
        
        # Dense layers
        model.add(Dense(50, activation='relu'))
        model.add(Dropout(0.2))
        model.add(Dense(25, activation='relu'))
        model.add(Dense(1))
        
        # Compile model
        model.compile(
            optimizer=Adam(learning_rate=0.001),
            loss='mse',
            metrics=['mae']
        )
        
        return model
    
    def train(self, data_period='2y'):
        """Train the model"""
        print(f"Training {self.symbol} model...")
        print(f"Configuration: {self.config}")
        
        # Download data
        try:
            ticker = yf.Ticker(self.symbol)
            data = ticker.history(period=data_period)
            
            if data.empty:
                raise ValueError(f"No data found for symbol {self.symbol}")
                
            print(f"Downloaded {len(data)} days of data for {self.symbol}")
            
        except Exception as e:
            print(f"Error downloading data for {self.symbol}: {e}")
            return False
        
        # Add technical indicators
        data = self.get_symbol_specific_features(data)
        
        # Prepare features
        feature_data = self.prepare_features(data)
        
        if len(feature_data) < self.lookback_days + 50:
            print(f"Insufficient data for {self.symbol}. Need at least {self.lookback_days + 50} days.")
            return False
        
        # Scale the data
        scaled_data = self.scaler.fit_transform(feature_data)
        scaled_df = pd.DataFrame(scaled_data, columns=feature_data.columns, index=feature_data.index)
        
        # Create sequences
        X, y = self.create_sequences(scaled_df)
        
        if len(X) == 0:
            print(f"No sequences created for {self.symbol}")
            return False
        
        # Split data
        split_idx = int(len(X) * 0.8)
        X_train, X_test = X[:split_idx], X[split_idx:]
        y_train, y_test = y[:split_idx], y[split_idx:]
        
        print(f"Training data shape: {X_train.shape}")
        print(f"Test data shape: {X_test.shape}")
        
        # Build model
        self.model = self.build_model((X_train.shape[1], X_train.shape[2]))
        
        # Callbacks
        early_stopping = EarlyStopping(
            monitor='val_loss',
            patience=15,  # Less patience for stable value stock
            restore_best_weights=True
        )
        
        reduce_lr = ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=8,
            min_lr=0.0001
        )
        
        # Train model
        history = self.model.fit(
            X_train, y_train,
            epochs=self.config['epochs'],
            batch_size=self.config['batch_size'],
            validation_data=(X_test, y_test),
            callbacks=[early_stopping, reduce_lr],
            verbose=1
        )
        
        # Evaluate model
        train_loss = self.model.evaluate(X_train, y_train, verbose=0)
        test_loss = self.model.evaluate(X_test, y_test, verbose=0)
        
        # Make predictions for evaluation
        y_pred_train = self.model.predict(X_train)
        y_pred_test = self.model.predict(X_test)
        
        # Calculate MAPE
        train_mape = mean_absolute_percentage_error(y_train, y_pred_train) * 100
        test_mape = mean_absolute_percentage_error(y_test, y_pred_test) * 100
        
        print(f"\nTraining Results for {self.symbol}:")
        print(f"Train Loss: {train_loss[0]:.6f}")
        print(f"Test Loss: {test_loss[0]:.6f}")
        print(f"Train MAPE: {train_mape:.2f}%")
        print(f"Test MAPE: {test_mape:.2f}%")
        
        # Save training metrics
        self.training_metrics = {
            'symbol': self.symbol,
            'train_loss': float(train_loss[0]),
            'test_loss': float(test_loss[0]),
            'train_mape': float(train_mape),
            'test_mape': float(test_mape),
            'epochs_trained': len(history.history['loss']),
            'config': self.config,
            'feature_columns': self.feature_columns,
            'training_date': datetime.now().isoformat()
        }
        
        return True
    
    def save_model(self, model_dir='persistent_data/ml_models', scaler_dir='persistent_data/scalers'):
        """Save the trained model and scaler"""
        if self.model is None:
            print("No model to save. Train the model first.")
            return False
        
        # Create directories
        os.makedirs(model_dir, exist_ok=True)
        os.makedirs(scaler_dir, exist_ok=True)
        
        # Save model with brkb filename (no slash)
        model_filename = 'brkb_lstm_model.h5' if self.symbol == 'BRK/B' else f'{self.symbol.lower()}_lstm_model.h5'
        model_path = os.path.join(model_dir, model_filename)
        self.model.save(model_path)
        print(f"Model saved to: {model_path}")
        
        # Save scaler
        scaler_filename = 'brkb_scaler.pkl' if self.symbol == 'BRK/B' else f'{self.symbol.lower()}_scaler.pkl'
        scaler_path = os.path.join(scaler_dir, scaler_filename)
        joblib.dump(self.scaler, scaler_path)
        print(f"Scaler saved to: {scaler_path}")
        
        # Save metadata
        metadata_filename = 'brkb_metadata.json' if self.symbol == 'BRK/B' else f'{self.symbol.lower()}_metadata.json'
        metadata_path = os.path.join(model_dir, metadata_filename)
        with open(metadata_path, 'w') as f:
            json.dump(self.training_metrics, f, indent=2)
        print(f"Metadata saved to: {metadata_path}")
        
        return True

def main():
    """Main training function"""
    symbol = 'BRK/B'
    
    # Initialize trainer
    trainer = SymbolSpecificTrainer(symbol)
    
    # Train model
    if trainer.train():
        # Save model
        trainer.save_model()
        print(f"\n✅ Successfully trained and saved {symbol} model!")
        return True
    else:
        print(f"\n❌ Failed to train {symbol} model!")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
