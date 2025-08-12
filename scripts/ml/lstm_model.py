#!/usr/bin/env python3
"""
Advanced LSTM Stock Price Prediction Model
Implements a sophisticated deep learning approach with multiple features and ensemble methods.
"""

import sys
import json
import numpy as np
import pandas as pd
from sklearn.preprocessing import MinMaxScaler, StandardScaler
from sklearn.metrics import mean_squared_error, mean_absolute_error
import joblib
import os
import warnings
warnings.filterwarnings('ignore')

# Try to import TensorFlow/Keras, fallback to statistical methods if not available
try:
    import tensorflow as tf
    from tensorflow.keras.models import Sequential, load_model
    from tensorflow.keras.layers import LSTM, Dense, Dropout, BatchNormalization, GRU
    from tensorflow.keras.optimizers import Adam
    from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau
    DEEP_LEARNING_AVAILABLE = True
except ImportError:
    DEEP_LEARNING_AVAILABLE = False
    print("Warning: TensorFlow not available, using statistical methods", file=sys.stderr)

class AdvancedFeatureEngineer:
    """Advanced feature engineering for stock prediction."""
    
    def __init__(self):
        self.scalers = {}
    
    def create_technical_features(self, df):
        """Create comprehensive technical indicators."""
        # Price-based features
        df['returns'] = df['close'].pct_change()
        df['log_returns'] = np.log(df['close'] / df['close'].shift(1))
        df['price_change'] = df['close'] - df['open']
        df['price_range'] = df['high'] - df['low']
        df['body_size'] = abs(df['close'] - df['open'])
        
        # Moving averages
        for period in [5, 10, 20, 50]:
            df[f'sma_{period}'] = df['close'].rolling(window=period).mean()
            df[f'ema_{period}'] = df['close'].ewm(span=period).mean()
            df[f'price_to_sma_{period}'] = df['close'] / df[f'sma_{period}']
        
        # Volatility features
        df['volatility_5'] = df['returns'].rolling(window=5).std()
        df['volatility_20'] = df['returns'].rolling(window=20).std()
        
        # RSI
        df['rsi'] = self.calculate_rsi(df['close'])
        
        # MACD
        df['macd'], df['macd_signal'] = self.calculate_macd(df['close'])
        df['macd_histogram'] = df['macd'] - df['macd_signal']
        
        # Bollinger Bands
        df['bb_upper'], df['bb_lower'], df['bb_middle'] = self.calculate_bollinger_bands(df['close'])
        df['bb_position'] = (df['close'] - df['bb_lower']) / (df['bb_upper'] - df['bb_lower'])
        df['bb_width'] = (df['bb_upper'] - df['bb_lower']) / df['bb_middle']
        
        # Volume features (if available)
        if 'volume' in df.columns and df['volume'].sum() > 0:
            df['volume_sma_10'] = df['volume'].rolling(window=10).mean()
            df['volume_ratio'] = df['volume'] / df['volume_sma_10']
            df['price_volume'] = df['close'] * df['volume']
        
        # Momentum features
        for period in [5, 10, 20]:
            df[f'momentum_{period}'] = df['close'] / df['close'].shift(period) - 1
        
        # Support/Resistance levels
        df['support'] = df['low'].rolling(window=20).min()
        df['resistance'] = df['high'].rolling(window=20).max()
        df['support_distance'] = (df['close'] - df['support']) / df['close']
        df['resistance_distance'] = (df['resistance'] - df['close']) / df['close']
        
        return df
    
    def calculate_rsi(self, prices, period=14):
        """Calculate RSI indicator."""
        delta = prices.diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))
        return rsi
    
    def calculate_macd(self, prices, fast=12, slow=26, signal=9):
        """Calculate MACD indicator."""
        ema_fast = prices.ewm(span=fast).mean()
        ema_slow = prices.ewm(span=slow).mean()
        macd = ema_fast - ema_slow
        macd_signal = macd.ewm(span=signal).mean()
        return macd, macd_signal
    
    def calculate_bollinger_bands(self, prices, period=20, std_dev=2):
        """Calculate Bollinger Bands."""
        sma = prices.rolling(window=period).mean()
        std = prices.rolling(window=period).std()
        upper = sma + (std * std_dev)
        lower = sma - (std * std_dev)
        return upper, lower, sma
    
    def prepare_lstm_data(self, df, sequence_length=60, target_col='close'):
        """Prepare data for LSTM training."""
        # Select features for training
        feature_cols = [col for col in df.columns if not col.startswith('date') and col != target_col]
        feature_cols = [col for col in feature_cols if not df[col].isna().all()]
        
        # Fill NaN values
        df_clean = df[feature_cols + [target_col]].fillna(method='ffill').fillna(method='bfill')
        
        # Scale features
        feature_scaler = MinMaxScaler()
        target_scaler = MinMaxScaler()
        
        scaled_features = feature_scaler.fit_transform(df_clean[feature_cols])
        scaled_target = target_scaler.fit_transform(df_clean[[target_col]])
        
        # Store scalers
        self.scalers['features'] = feature_scaler
        self.scalers['target'] = target_scaler
        
        # Create sequences
        X, y = [], []
        for i in range(sequence_length, len(scaled_features)):
            X.append(scaled_features[i-sequence_length:i])
            y.append(scaled_target[i, 0])
        
        return np.array(X), np.array(y), feature_cols

class LSTMStockPredictor:
    """Advanced LSTM-based stock price predictor."""
    
    def __init__(self, sequence_length=60, model_path=None):
        self.sequence_length = sequence_length
        self.model_path = model_path
        self.model = None
        self.feature_engineer = AdvancedFeatureEngineer()
        self.is_trained = False
        
    def build_model(self, input_shape):
        """Build advanced LSTM model architecture."""
        model = Sequential([
            # First LSTM layer with dropout
            LSTM(128, return_sequences=True, input_shape=input_shape),
            Dropout(0.2),
            BatchNormalization(),
            
            # Second LSTM layer
            LSTM(64, return_sequences=True),
            Dropout(0.2),
            BatchNormalization(),
            
            # Third LSTM layer
            LSTM(32, return_sequences=False),
            Dropout(0.2),
            
            # Dense layers
            Dense(25, activation='relu'),
            Dropout(0.1),
            Dense(1, activation='linear')
        ])
        
        # Compile with advanced optimizer
        optimizer = Adam(learning_rate=0.001, beta_1=0.9, beta_2=0.999)
        model.compile(optimizer=optimizer, loss='mse', metrics=['mae'])
        
        return model
    
    def train_model(self, df, epochs=100, batch_size=32, validation_split=0.2):
        """Train the LSTM model."""
        if not DEEP_LEARNING_AVAILABLE:
            print("Deep learning not available, skipping training", file=sys.stderr)
            return None
        
        # Feature engineering
        df_features = self.feature_engineer.create_technical_features(df.copy())
        
        # Prepare LSTM data
        X, y, feature_cols = self.feature_engineer.prepare_lstm_data(df_features, self.sequence_length)
        
        if len(X) < 50:  # Minimum data requirement
            print("Insufficient data for training", file=sys.stderr)
            return None
        
        # Build model
        self.model = self.build_model((X.shape[1], X.shape[2]))
        
        # Callbacks
        early_stopping = EarlyStopping(monitor='val_loss', patience=10, restore_best_weights=True)
        reduce_lr = ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=5, min_lr=0.0001)
        
        # Train model
        history = self.model.fit(
            X, y,
            epochs=epochs,
            batch_size=batch_size,
            validation_split=validation_split,
            callbacks=[early_stopping, reduce_lr],
            verbose=0
        )
        
        self.is_trained = True
        
        # Save model and scalers
        if self.model_path:
            self.save_model()
        
        return history
    
    def predict(self, df):
        """Make prediction using trained model."""
        if not DEEP_LEARNING_AVAILABLE or not self.is_trained:
            return self.fallback_prediction(df)
        
        try:
            # Feature engineering
            df_features = self.feature_engineer.create_technical_features(df.copy())
            
            # Prepare data for prediction
            feature_cols = [col for col in df_features.columns if not col.startswith('date') and col != 'close']
            feature_cols = [col for col in feature_cols if not df_features[col].isna().all()]
            
            df_clean = df_features[feature_cols].fillna(method='ffill').fillna(method='bfill')
            
            # Scale features
            if 'features' in self.feature_engineer.scalers:
                scaled_features = self.feature_engineer.scalers['features'].transform(df_clean.tail(self.sequence_length))
            else:
                # If no scaler available, create one
                scaler = MinMaxScaler()
                scaled_features = scaler.fit_transform(df_clean.tail(self.sequence_length))
            
            # Reshape for LSTM
            X = scaled_features.reshape(1, self.sequence_length, len(feature_cols))
            
            # Make prediction
            scaled_prediction = self.model.predict(X, verbose=0)[0, 0]
            
            # Inverse transform
            if 'target' in self.feature_engineer.scalers:
                prediction = self.feature_engineer.scalers['target'].inverse_transform([[scaled_prediction]])[0, 0]
            else:
                # Fallback: use last price as reference
                prediction = df['close'].iloc[-1] * (1 + scaled_prediction)
            
            return max(0.01, prediction)
            
        except Exception as e:
            print(f"LSTM prediction failed: {e}", file=sys.stderr)
            return self.fallback_prediction(df)
    
    def fallback_prediction(self, df):
        """Fallback prediction using statistical methods."""
        prices = df['close'].values
        
        if len(prices) < 2:
            return prices[-1] * 1.001 if len(prices) > 0 else 100.0
        
        # Enhanced statistical prediction
        # 1. Linear trend
        x = np.arange(len(prices))
        coeffs = np.polyfit(x, prices, 1)
        trend_pred = coeffs[0] * len(prices) + coeffs[1]
        
        # 2. Moving average trend
        if len(prices) >= 5:
            ma_5 = np.mean(prices[-5:])
            ma_10 = np.mean(prices[-10:]) if len(prices) >= 10 else ma_5
            ma_trend = ma_5 + (ma_5 - ma_10) * 0.5
        else:
            ma_trend = np.mean(prices)
        
        # 3. Momentum-based prediction
        if len(prices) >= 3:
            momentum = (prices[-1] - prices[-3]) / prices[-3]
            momentum_pred = prices[-1] * (1 + momentum * 0.5)
        else:
            momentum_pred = prices[-1]
        
        # Ensemble of statistical methods
        ensemble_pred = (trend_pred * 0.4 + ma_trend * 0.4 + momentum_pred * 0.2)
        
        # Apply reasonable bounds
        last_price = prices[-1]
        max_change = 0.1  # 10% max change
        max_price = last_price * (1 + max_change)
        min_price = last_price * (1 - max_change)
        
        return max(min_price, min(max_price, ensemble_pred))
    
    def save_model(self):
        """Save model and scalers."""
        if self.model and self.model_path:
            # Create directory if it doesn't exist
            os.makedirs(os.path.dirname(self.model_path), exist_ok=True)
            
            # Save Keras model
            self.model.save(f"{self.model_path}.h5")
            
            # Save scalers
            joblib.dump(self.feature_engineer.scalers, f"{self.model_path}_scalers.pkl")
            
            print(f"Model saved to {self.model_path}", file=sys.stderr)
    
    def load_model(self):
        """Load pre-trained model and scalers."""
        try:
            if DEEP_LEARNING_AVAILABLE and os.path.exists(f"{self.model_path}.h5"):
                self.model = load_model(f"{self.model_path}.h5")
                self.is_trained = True
                
                # Load scalers
                if os.path.exists(f"{self.model_path}_scalers.pkl"):
                    self.feature_engineer.scalers = joblib.load(f"{self.model_path}_scalers.pkl")
                
                print(f"Model loaded from {self.model_path}", file=sys.stderr)
                return True
        except Exception as e:
            print(f"Failed to load model: {e}", file=sys.stderr)
        
        return False

def main():
    """Main prediction function."""
    if len(sys.argv) != 2:
        print("Usage: python3 lstm_model.py <comma_separated_prices>", file=sys.stderr)
        sys.exit(1)
    
    try:
        # Parse input prices
        price_str = sys.argv[1]
        prices = [float(p.strip()) for p in price_str.split(',')]
        
        if len(prices) == 0:
            print("Error: No prices provided", file=sys.stderr)
            sys.exit(1)
        
        # Create DataFrame
        df = pd.DataFrame({
            'close': prices,
            'open': prices,  # Simplified: use close as open
            'high': [p * 1.01 for p in prices],  # Simplified: add small variation
            'low': [p * 0.99 for p in prices],   # Simplified: add small variation
            'volume': [1000000] * len(prices)    # Dummy volume
        })
        
        # Initialize predictor
        model_path = os.environ.get('ML_MODEL_PATH', '/app/persistent_data/ml_models/lstm_model')
        predictor = LSTMStockPredictor(sequence_length=min(30, len(prices)-1), model_path=model_path)
        
        # Try to load existing model
        if not predictor.load_model():
            # If no pre-trained model, use statistical fallback
            print("No pre-trained model found, using statistical methods", file=sys.stderr)
        
        # Make prediction
        prediction = predictor.predict(df)
        
        # Output prediction
        print(f"{prediction:.2f}")
        
    except ValueError as e:
        print(f"Error parsing prices: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Prediction error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
