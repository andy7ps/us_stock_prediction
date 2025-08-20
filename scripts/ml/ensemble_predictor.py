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
                    self.models['symbol_specific'] = load_model(model_path, compile=False)
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
                self.models['general_lstm'] = load_model(model_path, compile=False)
                self.scalers['general_lstm'] = joblib.load(scaler_path)
                return True
        except Exception as e:
            print(f"Error loading general model: {e}")
        
        return False
    
    def create_traditional_models(self, X_train, y_train):
        """Create traditional ML models using current features only (not sequences)"""
        try:
            # Use only the latest features from each sequence (not the full sequence)
            # X_train shape is (samples, timesteps, features) - we want (samples, features)
            X_train_flat = X_train[:, -1, :]  # Take only the last timestep features
            
            print(f"Training traditional models with shape: {X_train_flat.shape}")
            
            # Random Forest
            rf_model = RandomForestRegressor(
                n_estimators=100,
                max_depth=10,
                random_state=42,
                n_jobs=-1
            )
            rf_model.fit(X_train_flat, y_train)
            self.models['random_forest'] = rf_model
            
            # Gradient Boosting
            gb_model = GradientBoostingRegressor(
                n_estimators=100,
                max_depth=6,
                learning_rate=0.1,
                random_state=42
            )
            gb_model.fit(X_train_flat, y_train)
            self.models['gradient_boosting'] = gb_model
            
            # Linear Regression (for trend)
            lr_model = LinearRegression()
            lr_model.fit(X_train_flat, y_train)
            self.models['linear_regression'] = lr_model
            
            return True
        except Exception as e:
            print(f"Error creating traditional models: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    def get_features(self, data):
        """Extract features from stock data - matches training script exactly"""
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
    
    def prepare_data(self, data, lookback_days=60):
        """Prepare data for prediction - matches training script exactly"""
        feature_data = self.get_features(data)
        
        # Use symbol-specific features if available
        if self.feature_columns:
            try:
                # Ensure all required features are available
                missing_features = [col for col in self.feature_columns if col not in feature_data.columns]
                if missing_features:
                    print(f"Warning: Missing features {missing_features}, regenerating feature set")
                    # Fallback to standard feature selection
                    feature_cols = [col for col in feature_data.columns 
                                   if col not in ['Open', 'High', 'Low', 'Close', 'Volume', 'Adj Close']]
                    features = feature_data[feature_cols].values
                else:
                    # Use exact feature columns from training
                    features = feature_data[self.feature_columns].values
            except KeyError as e:
                print(f"KeyError with feature columns: {e}")
                # Fallback to standard feature selection
                feature_cols = [col for col in feature_data.columns 
                               if col not in ['Open', 'High', 'Low', 'Close', 'Volume', 'Adj Close']]
                features = feature_data[feature_cols].values
        else:
            # Standard feature selection (exclude basic OHLCV)
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
        
        print(f"Prepared data shapes - LSTM: {X_lstm.shape}, Flat: {X_flat.shape}")
        if self.feature_columns:
            print(f"Using {len(self.feature_columns)} symbol-specific features")
        else:
            print(f"Using {features.shape[1]} standard features")
        
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
        
        # For traditional models, we need just the current features (not sequences)
        if latest_lstm is not None:
            latest_features = latest_lstm[0, -1, :]  # Last timestep of the sequence
            latest_features = latest_features.reshape(1, -1)
        else:
            latest_features = latest_flat
        
        predictions = {}
        
        # LSTM models predictions
        for model_name, model in self.models.items():
            try:
                if model_name in ['symbol_specific', 'general_lstm'] and latest_lstm is not None:
                    # Scale data if scaler available
                    if model_name in self.scalers:
                        scaler = self.scalers[model_name]
                        # For LSTM, we need to scale the entire sequence properly
                        # Reshape to 2D for scaling, then back to 3D
                        original_shape = latest_lstm.shape
                        reshaped_data = latest_lstm.reshape(-1, latest_lstm.shape[-1])
                        scaled_data = scaler.transform(reshaped_data)
                        scaled_lstm = scaled_data.reshape(original_shape)
                        
                        print(f"Scaled data shape for {model_name}: {scaled_lstm.shape}")
                        pred = model.predict(scaled_lstm, verbose=0)[0][0]
                    else:
                        print(f"No scaler found for {model_name}, using raw data")
                        pred = model.predict(latest_lstm, verbose=0)[0][0]
                    
                    predictions[model_name] = pred
                    print(f"{model_name} prediction: {pred}")
                    
                elif model_name in ['random_forest', 'gradient_boosting', 'linear_regression'] and latest_features is not None:
                    pred = model.predict(latest_features)[0]
                    predictions[model_name] = pred
                    print(f"{model_name} prediction: {pred}")
                    
            except Exception as e:
                print(f"Error with {model_name}: {e}")
                import traceback
                traceback.print_exc()
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
        
        # Handle MultiIndex columns from yf.download()
        if isinstance(stock_data.columns, pd.MultiIndex):
            stock_data.columns = stock_data.columns.get_level_values(0)
        
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
        
        # Handle MultiIndex columns from yf.download()
        if isinstance(stock_data.columns, pd.MultiIndex):
            stock_data.columns = stock_data.columns.get_level_values(0)
        
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
