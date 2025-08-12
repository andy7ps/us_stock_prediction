#!/usr/bin/env python3
"""
Ensemble Stock Prediction Model
Combines multiple ML approaches for improved accuracy and robustness.
"""

import sys
import os
import json
import numpy as np
import pandas as pd
from typing import List, Dict, Tuple
import warnings
warnings.filterwarnings('ignore')

# Import our custom models
from lstm_model import LSTMStockPredictor
from enhanced_predict import EnhancedPredictor

# Try to import advanced ML libraries
try:
    from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
    from sklearn.linear_model import LinearRegression, Ridge
    from sklearn.preprocessing import StandardScaler
    from sklearn.model_selection import cross_val_score
    import joblib
    SKLEARN_AVAILABLE = True
except ImportError:
    SKLEARN_AVAILABLE = False

class EnsemblePredictor:
    """Advanced ensemble predictor combining multiple ML approaches."""
    
    def __init__(self, model_dir=None):
        self.model_dir = model_dir or '/app/persistent_data/ml_models'
        self.models = {}
        self.weights = {}
        self.feature_scaler = None
        self.ensemble_trained = False
        
        # Initialize individual predictors
        self.lstm_predictor = LSTMStockPredictor(model_path=os.path.join(self.model_dir, 'ensemble_lstm'))
        self.enhanced_predictor = EnhancedPredictor()
        
        # Initialize sklearn models if available
        if SKLEARN_AVAILABLE:
            self.sklearn_models = {
                'random_forest': RandomForestRegressor(n_estimators=100, random_state=42),
                'gradient_boost': GradientBoostingRegressor(n_estimators=100, random_state=42),
                'linear_ridge': Ridge(alpha=1.0)
            }
        else:
            self.sklearn_models = {}
    
    def create_ensemble_features(self, df):
        """Create comprehensive features for ensemble learning."""
        features = {}
        
        # Basic price features
        prices = df['close'].values
        features['current_price'] = prices[-1]
        features['price_change_1d'] = (prices[-1] - prices[-2]) / prices[-2] if len(prices) > 1 else 0
        features['price_change_5d'] = (prices[-1] - prices[-6]) / prices[-6] if len(prices) > 5 else 0
        features['price_change_10d'] = (prices[-1] - prices[-11]) / prices[-11] if len(prices) > 10 else 0
        
        # Volatility features
        if len(prices) > 5:
            returns = np.diff(prices) / prices[:-1]
            features['volatility_5d'] = np.std(returns[-5:]) if len(returns) >= 5 else 0
            features['volatility_10d'] = np.std(returns[-10:]) if len(returns) >= 10 else 0
        else:
            features['volatility_5d'] = 0
            features['volatility_10d'] = 0
        
        # Moving average features
        for period in [5, 10, 20]:
            if len(prices) >= period:
                ma = np.mean(prices[-period:])
                features[f'ma_{period}'] = ma
                features[f'price_to_ma_{period}'] = prices[-1] / ma - 1
            else:
                features[f'ma_{period}'] = prices[-1]
                features[f'price_to_ma_{period}'] = 0
        
        # Trend features
        if len(prices) > 10:
            x = np.arange(len(prices[-10:]))
            coeffs = np.polyfit(x, prices[-10:], 1)
            features['trend_slope'] = coeffs[0] / prices[-1]  # Normalized slope
            features['trend_r2'] = self._calculate_r_squared(prices[-10:], x, coeffs[0], coeffs[1])
        else:
            features['trend_slope'] = 0
            features['trend_r2'] = 0
        
        # Technical indicators
        if len(prices) > 14:
            features['rsi'] = self._calculate_rsi(prices)
            features['bb_position'] = self._calculate_bb_position(prices)
        else:
            features['rsi'] = 50  # Neutral
            features['bb_position'] = 0.5  # Middle
        
        return features
    
    def _calculate_rsi(self, prices, period=14):
        """Calculate RSI."""
        if len(prices) < period + 1:
            return 50
        
        deltas = np.diff(prices)
        gains = np.where(deltas > 0, deltas, 0)
        losses = np.where(deltas < 0, -deltas, 0)
        
        avg_gain = np.mean(gains[-period:])
        avg_loss = np.mean(losses[-period:])
        
        if avg_loss == 0:
            return 100
        
        rs = avg_gain / avg_loss
        rsi = 100 - (100 / (1 + rs))
        return rsi
    
    def _calculate_bb_position(self, prices, period=20, std_dev=2):
        """Calculate position within Bollinger Bands."""
        if len(prices) < period:
            return 0.5
        
        recent_prices = prices[-period:]
        sma = np.mean(recent_prices)
        std = np.std(recent_prices)
        
        upper = sma + (std_dev * std)
        lower = sma - (std_dev * std)
        
        if upper == lower:
            return 0.5
        
        position = (prices[-1] - lower) / (upper - lower)
        return max(0, min(1, position))
    
    def _calculate_r_squared(self, y_values, x_values, slope, intercept):
        """Calculate R-squared."""
        y_mean = np.mean(y_values)
        ss_tot = np.sum((y_values - y_mean) ** 2)
        ss_res = np.sum((y_values - (slope * x_values + intercept)) ** 2)
        
        if ss_tot == 0:
            return 0
        
        return max(0, min(1, 1 - (ss_res / ss_tot)))
    
    def get_individual_predictions(self, df):
        """Get predictions from all individual models."""
        predictions = {}
        confidences = {}
        
        # LSTM prediction
        try:
            lstm_pred = self.lstm_predictor.predict(df)
            predictions['lstm'] = lstm_pred
            confidences['lstm'] = 0.8 if self.lstm_predictor.is_trained else 0.3
        except Exception as e:
            print(f"LSTM prediction failed: {e}", file=sys.stderr)
            predictions['lstm'] = df['close'].iloc[-1] * 1.001
            confidences['lstm'] = 0.1
        
        # Enhanced statistical prediction
        try:
            enhanced_result = self.enhanced_predictor.ensemble_prediction(df['close'].values)
            predictions['enhanced'] = enhanced_result['prediction']
            confidences['enhanced'] = 0.6
        except Exception as e:
            print(f"Enhanced prediction failed: {e}", file=sys.stderr)
            predictions['enhanced'] = df['close'].iloc[-1] * 1.001
            confidences['enhanced'] = 0.1
        
        # Sklearn models (if available and trained)
        if SKLEARN_AVAILABLE and self.ensemble_trained:
            features = self.create_ensemble_features(df)
            feature_vector = np.array(list(features.values())).reshape(1, -1)
            
            if self.feature_scaler:
                feature_vector = self.feature_scaler.transform(feature_vector)
            
            for name, model in self.sklearn_models.items():
                try:
                    pred = model.predict(feature_vector)[0]
                    predictions[f'sklearn_{name}'] = pred
                    confidences[f'sklearn_{name}'] = 0.7
                except Exception as e:
                    print(f"Sklearn {name} prediction failed: {e}", file=sys.stderr)
        
        return predictions, confidences
    
    def calculate_dynamic_weights(self, predictions, confidences, df):
        """Calculate dynamic weights based on market conditions and model confidence."""
        weights = {}
        
        # Base weights from confidence scores
        total_confidence = sum(confidences.values())
        if total_confidence > 0:
            for model, conf in confidences.items():
                weights[model] = conf / total_confidence
        else:
            # Equal weights if no confidence info
            n_models = len(predictions)
            for model in predictions:
                weights[model] = 1.0 / n_models
        
        # Adjust weights based on market conditions
        prices = df['close'].values
        
        # High volatility: favor LSTM and ensemble methods
        if len(prices) > 5:
            recent_volatility = np.std(np.diff(prices[-5:]) / prices[-5:-1])
            if recent_volatility > 0.03:  # High volatility
                if 'lstm' in weights:
                    weights['lstm'] *= 1.2
                if 'enhanced' in weights:
                    weights['enhanced'] *= 1.1
        
        # Strong trend: favor trend-following models
        if len(prices) > 10:
            trend_strength = abs(np.corrcoef(np.arange(10), prices[-10:])[0, 1])
            if trend_strength > 0.7:  # Strong trend
                for model in weights:
                    if 'sklearn' in model:
                        weights[model] *= 1.1
        
        # Normalize weights
        total_weight = sum(weights.values())
        if total_weight > 0:
            weights = {k: v / total_weight for k, v in weights.items()}
        
        return weights
    
    def ensemble_predict(self, df):
        """Make ensemble prediction combining all models."""
        # Get individual predictions
        predictions, confidences = self.get_individual_predictions(df)
        
        if not predictions:
            # Fallback to simple prediction
            return df['close'].iloc[-1] * 1.001
        
        # Calculate dynamic weights
        weights = self.calculate_dynamic_weights(predictions, confidences, df)
        
        # Weighted ensemble prediction
        ensemble_pred = sum(pred * weights.get(model, 0) for model, pred in predictions.items())
        
        # Apply bounds based on historical volatility
        current_price = df['close'].iloc[-1]
        if len(df) > 20:
            returns = np.diff(df['close'].values) / df['close'].values[:-1]
            volatility = np.std(returns)
            max_change = min(0.15, volatility * 3)  # Dynamic bounds
        else:
            max_change = 0.1  # 10% default
        
        max_price = current_price * (1 + max_change)
        min_price = current_price * (1 - max_change)
        
        final_prediction = max(min_price, min(max_price, ensemble_pred))
        
        return {
            'prediction': final_prediction,
            'individual_predictions': predictions,
            'weights': weights,
            'confidence_score': sum(conf * weights.get(model, 0) for model, conf in confidences.items()),
            'method': 'ensemble'
        }
    
    def train_ensemble(self, training_data):
        """Train the ensemble meta-model using historical data."""
        if not SKLEARN_AVAILABLE:
            print("Sklearn not available, skipping ensemble training", file=sys.stderr)
            return False
        
        print("Training ensemble meta-model...", file=sys.stderr)
        
        # Prepare training data
        X_train = []
        y_train = []
        
        # Use sliding window approach
        window_size = 60
        for i in range(window_size, len(training_data) - 1):
            # Get historical window
            window_data = training_data.iloc[i-window_size:i]
            
            # Create features
            features = self.create_ensemble_features(window_data)
            X_train.append(list(features.values()))
            
            # Target is next day's price
            y_train.append(training_data.iloc[i+1]['close'])
        
        if len(X_train) < 50:
            print("Insufficient training data for ensemble", file=sys.stderr)
            return False
        
        X_train = np.array(X_train)
        y_train = np.array(y_train)
        
        # Scale features
        self.feature_scaler = StandardScaler()
        X_train_scaled = self.feature_scaler.fit_transform(X_train)
        
        # Train sklearn models
        for name, model in self.sklearn_models.items():
            try:
                model.fit(X_train_scaled, y_train)
                print(f"Trained {name} model", file=sys.stderr)
            except Exception as e:
                print(f"Failed to train {name}: {e}", file=sys.stderr)
        
        self.ensemble_trained = True
        
        # Save ensemble model
        self.save_ensemble()
        
        return True
    
    def save_ensemble(self):
        """Save ensemble model components."""
        if not SKLEARN_AVAILABLE:
            return
        
        ensemble_path = os.path.join(self.model_dir, 'ensemble_models.pkl')
        scaler_path = os.path.join(self.model_dir, 'ensemble_scaler.pkl')
        
        try:
            os.makedirs(self.model_dir, exist_ok=True)
            
            # Save sklearn models
            joblib.dump(self.sklearn_models, ensemble_path)
            
            # Save scaler
            if self.feature_scaler:
                joblib.dump(self.feature_scaler, scaler_path)
            
            print(f"Ensemble models saved to {self.model_dir}", file=sys.stderr)
        except Exception as e:
            print(f"Failed to save ensemble: {e}", file=sys.stderr)
    
    def load_ensemble(self):
        """Load pre-trained ensemble models."""
        if not SKLEARN_AVAILABLE:
            return False
        
        ensemble_path = os.path.join(self.model_dir, 'ensemble_models.pkl')
        scaler_path = os.path.join(self.model_dir, 'ensemble_scaler.pkl')
        
        try:
            if os.path.exists(ensemble_path):
                self.sklearn_models = joblib.load(ensemble_path)
                self.ensemble_trained = True
                print("Loaded ensemble models", file=sys.stderr)
            
            if os.path.exists(scaler_path):
                self.feature_scaler = joblib.load(scaler_path)
                print("Loaded feature scaler", file=sys.stderr)
            
            return self.ensemble_trained
        except Exception as e:
            print(f"Failed to load ensemble: {e}", file=sys.stderr)
            return False

def main():
    """Main prediction function."""
    if len(sys.argv) != 2:
        print("Usage: python3 ensemble_predict.py <comma_separated_prices>", file=sys.stderr)
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
            'open': prices,  # Simplified
            'high': [p * 1.01 for p in prices],
            'low': [p * 0.99 for p in prices],
            'volume': [1000000] * len(prices)
        })
        
        # Initialize ensemble predictor
        model_dir = os.environ.get('ML_MODEL_PATH', '/app/persistent_data/ml_models')
        predictor = EnsemblePredictor(model_dir=os.path.dirname(model_dir))
        
        # Try to load pre-trained models
        predictor.load_ensemble()
        predictor.lstm_predictor.load_model()
        
        # Make ensemble prediction
        result = predictor.ensemble_predict(df)
        
        # Output prediction (for compatibility with Go service)
        if isinstance(result, dict):
            print(f"{result['prediction']:.2f}")
            # Optionally output detailed results to stderr for debugging
            # print(f"DEBUG: {json.dumps(result, indent=2, default=str)}", file=sys.stderr)
        else:
            print(f"{result:.2f}")
        
    except ValueError as e:
        print(f"Error parsing prices: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Prediction error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
