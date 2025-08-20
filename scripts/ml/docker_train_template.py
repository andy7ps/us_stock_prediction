#!/usr/bin/env python3
"""
Docker-Optimized Training Script Template
No virtual environment needed - runs directly in Docker container
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

class DockerTrainer:
    """Docker-optimized trainer that saves all data to persistent_data"""
    
    def __init__(self, symbol, lookback_days=60, prediction_days=1):
        self.symbol = symbol.upper()
        self.lookback_days = lookback_days
        self.prediction_days = prediction_days
        self.scaler = MinMaxScaler(feature_range=(0, 1))
        self.model = None
        self.feature_columns = []
        
        # Docker persistent data paths (no virtual environment needed)
        self.base_dir = "/app/persistent_data"
        self.model_dir = os.path.join(self.base_dir, "ml_models")
        self.log_dir = os.path.join(self.base_dir, "logs")
        
        # Ensure directories exist
        os.makedirs(self.model_dir, exist_ok=True)
        os.makedirs(self.log_dir, exist_ok=True)
        
        # Symbol-specific configurations
        self.symbol_configs = {
            'NVDA': {'epochs': 150, 'batch_size': 32, 'lstm_units': [128, 64, 32], 'dropout': 0.3},
            'TSLA': {'epochs': 120, 'batch_size': 32, 'lstm_units': [100, 50, 25], 'dropout': 0.25},
            'AAPL': {'epochs': 100, 'batch_size': 64, 'lstm_units': [80, 40, 20], 'dropout': 0.2},
            'MSFT': {'epochs': 100, 'batch_size': 64, 'lstm_units': [80, 40, 20], 'dropout': 0.2},
            'GOOGL': {'epochs': 120, 'batch_size': 32, 'lstm_units': [100, 50, 25], 'dropout': 0.25},
            'AMZN': {'epochs': 120, 'batch_size': 32, 'lstm_units': [100, 50, 25], 'dropout': 0.25},
            'SMR': {'epochs': 180, 'batch_size': 16, 'lstm_units': [120, 60, 30], 'dropout': 0.35},
            'SPY': {'epochs': 100, 'batch_size': 64, 'lstm_units': [80, 40, 20], 'dropout': 0.2},
            'DEFAULT': {'epochs': 100, 'batch_size': 32, 'lstm_units': [100, 50, 25], 'dropout': 0.25}
        }
        
        self.config = self.symbol_configs.get(self.symbol, self.symbol_configs['DEFAULT'])
        
    def log(self, message):
        """Log message to both console and persistent log file"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_message = f"[{timestamp}] {self.symbol}: {message}"
        print(log_message)
        
        # Also log to persistent file
        log_file = os.path.join(self.log_dir, f"docker_training_{self.symbol.lower()}.log")
        with open(log_file, 'a') as f:
            f.write(log_message + "\n")
    
    def fetch_data(self, period="2y"):
        """Fetch stock data using yfinance"""
        self.log(f"Fetching data for {self.symbol}...")
        
        try:
            ticker = yf.Ticker(self.symbol)
            data = ticker.history(period=period)
            
            if data.empty:
                raise ValueError(f"No data found for symbol {self.symbol}")
            
            self.log(f"Fetched {len(data)} days of data")
            return data
        
        except Exception as e:
            self.log(f"Error fetching data: {str(e)}")
            raise
    
    def prepare_features(self, data):
        """Prepare features for training"""
        self.log("Preparing features...")
        
        df = data.copy()
        
        # Basic price features
        df['Returns'] = df['Close'].pct_change()
        df['High_Low_Pct'] = (df['High'] - df['Low']) / df['Close']
        df['Price_Change'] = df['Close'] - df['Open']
        
        # Moving averages
        for window in [5, 10, 20, 50]:
            df[f'MA_{window}'] = df['Close'].rolling(window=window).mean()
            df[f'MA_{window}_ratio'] = df['Close'] / df[f'MA_{window}']
        
        # Volatility
        df['Volatility'] = df['Returns'].rolling(window=20).std()
        
        # Volume features
        df['Volume_MA'] = df['Volume'].rolling(window=20).mean()
        df['Volume_ratio'] = df['Volume'] / df['Volume_MA']
        
        # RSI
        delta = df['Close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        df['RSI'] = 100 - (100 / (1 + rs))
        
        # MACD
        exp1 = df['Close'].ewm(span=12).mean()
        exp2 = df['Close'].ewm(span=26).mean()
        df['MACD'] = exp1 - exp2
        df['MACD_signal'] = df['MACD'].ewm(span=9).mean()
        
        # Bollinger Bands
        bb_window = 20
        bb_std = df['Close'].rolling(window=bb_window).std()
        df['BB_middle'] = df['Close'].rolling(window=bb_window).mean()
        df['BB_upper'] = df['BB_middle'] + (bb_std * 2)
        df['BB_lower'] = df['BB_middle'] - (bb_std * 2)
        df['BB_position'] = (df['Close'] - df['BB_lower']) / (df['BB_upper'] - df['BB_lower'])
        
        # Select feature columns
        feature_cols = [
            'Open', 'High', 'Low', 'Close', 'Volume',
            'Returns', 'High_Low_Pct', 'Price_Change',
            'MA_5_ratio', 'MA_10_ratio', 'MA_20_ratio', 'MA_50_ratio',
            'Volatility', 'Volume_ratio', 'RSI', 'MACD', 'MACD_signal', 'BB_position'
        ]
        
        # Remove any columns that don't exist
        feature_cols = [col for col in feature_cols if col in df.columns]
        self.feature_columns = feature_cols
        
        # Drop NaN values
        df = df[feature_cols].dropna()
        
        self.log(f"Prepared {len(feature_cols)} features with {len(df)} samples")
        return df[feature_cols].values
    
    def create_sequences(self, data):
        """Create sequences for LSTM training"""
        self.log(f"Creating sequences with lookback={self.lookback_days}...")
        
        X, y = [], []
        for i in range(self.lookback_days, len(data)):
            X.append(data[i-self.lookback_days:i])
            y.append(data[i, 3])  # Close price index
        
        X, y = np.array(X), np.array(y)
        self.log(f"Created {len(X)} sequences")
        return X, y
    
    def build_model(self, input_shape):
        """Build LSTM model"""
        self.log("Building LSTM model...")
        
        model = Sequential()
        
        # First LSTM layer
        model.add(LSTM(
            units=self.config['lstm_units'][0],
            return_sequences=True,
            input_shape=input_shape
        ))
        model.add(Dropout(self.config['dropout']))
        model.add(BatchNormalization())
        
        # Second LSTM layer
        model.add(LSTM(
            units=self.config['lstm_units'][1],
            return_sequences=True
        ))
        model.add(Dropout(self.config['dropout']))
        model.add(BatchNormalization())
        
        # Third LSTM layer
        model.add(LSTM(units=self.config['lstm_units'][2]))
        model.add(Dropout(self.config['dropout']))
        model.add(BatchNormalization())
        
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
        
        self.log(f"Model built with {model.count_params()} parameters")
        return model
    
    def train_model(self, X_train, y_train, X_val, y_val):
        """Train the LSTM model"""
        self.log(f"Starting training for {self.config['epochs']} epochs...")
        
        # Callbacks
        early_stopping = EarlyStopping(
            monitor='val_loss',
            patience=15,
            restore_best_weights=True
        )
        
        reduce_lr = ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=10,
            min_lr=0.0001
        )
        
        # Train model
        history = self.model.fit(
            X_train, y_train,
            batch_size=self.config['batch_size'],
            epochs=self.config['epochs'],
            validation_data=(X_val, y_val),
            callbacks=[early_stopping, reduce_lr],
            verbose=1
        )
        
        self.log("Training completed")
        return history
    
    def save_model(self):
        """Save model and related files to persistent storage"""
        self.log("Saving model to persistent storage...")
        
        # Create symbol-specific directory
        symbol_dir = os.path.join(self.model_dir, f"{self.symbol.lower()}_specific")
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
            'training_config': self.config,
            'feature_columns': self.feature_columns,
            'trained_at': datetime.now().isoformat(),
            'model_path': model_path,
            'scaler_path': scaler_path
        }
        
        with open(config_path, 'w') as f:
            json.dump(config_data, f, indent=2)
        
        self.log(f"Model saved to {symbol_dir}")
        return symbol_dir
    
    def run_training(self):
        """Complete training pipeline"""
        try:
            self.log("🚀 Starting Docker training pipeline...")
            
            # Fetch data
            data = self.fetch_data()
            
            # Prepare features
            features = self.prepare_features(data)
            
            # Scale features
            scaled_features = self.scaler.fit_transform(features)
            
            # Create sequences
            X, y = self.create_sequences(scaled_features)
            
            # Split data
            split_idx = int(len(X) * 0.8)
            X_train, X_val = X[:split_idx], X[split_idx:]
            y_train, y_val = y[:split_idx], y[split_idx:]
            
            self.log(f"Training set: {len(X_train)}, Validation set: {len(X_val)}")
            
            # Build model
            self.model = self.build_model((X_train.shape[1], X_train.shape[2]))
            
            # Train model
            history = self.train_model(X_train, y_train, X_val, y_val)
            
            # Evaluate model
            val_predictions = self.model.predict(X_val)
            mape = mean_absolute_percentage_error(y_val, val_predictions) * 100
            
            self.log(f"Validation MAPE: {mape:.2f}%")
            
            # Save model
            model_dir = self.save_model()
            
            self.log("✅ Training completed successfully!")
            return {
                'success': True,
                'symbol': self.symbol,
                'mape': mape,
                'model_dir': model_dir,
                'epochs_trained': len(history.history['loss'])
            }
            
        except Exception as e:
            self.log(f"❌ Training failed: {str(e)}")
            return {
                'success': False,
                'symbol': self.symbol,
                'error': str(e)
            }

def main():
    """Main training function"""
    if len(sys.argv) < 2:
        print("Usage: python3 docker_train_template.py <SYMBOL>")
        sys.exit(1)
    
    symbol = sys.argv[1].upper()
    
    print(f"🐳 Docker Training for {symbol}")
    print("=" * 50)
    
    trainer = DockerTrainer(symbol)
    result = trainer.run_training()
    
    if result['success']:
        print(f"\n🎉 Training successful for {symbol}!")
        print(f"📊 MAPE: {result['mape']:.2f}%")
        print(f"📁 Model saved to: {result['model_dir']}")
    else:
        print(f"\n❌ Training failed for {symbol}: {result['error']}")
        sys.exit(1)

if __name__ == "__main__":
    main()
