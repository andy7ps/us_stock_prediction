#!/usr/bin/env python3
"""
Enhanced stock price prediction with multiple algorithms and technical indicators.
Uses only Python standard library for maximum compatibility.
"""

import sys
import json
import math
import statistics
from typing import List, Dict, Tuple, Optional

class TechnicalIndicators:
    """Calculate technical indicators using only standard library."""
    
    @staticmethod
    def sma(prices: List[float], period: int) -> List[float]:
        """Simple Moving Average."""
        if len(prices) < period:
            return [prices[-1]] * len(prices)
        
        sma_values = []
        for i in range(len(prices)):
            if i < period - 1:
                sma_values.append(sum(prices[:i+1]) / (i+1))
            else:
                sma_values.append(sum(prices[i-period+1:i+1]) / period)
        return sma_values
    
    @staticmethod
    def ema(prices: List[float], period: int) -> List[float]:
        """Exponential Moving Average."""
        if not prices:
            return []
        
        multiplier = 2 / (period + 1)
        ema_values = [prices[0]]
        
        for i in range(1, len(prices)):
            ema_val = (prices[i] * multiplier) + (ema_values[-1] * (1 - multiplier))
            ema_values.append(ema_val)
        
        return ema_values
    
    @staticmethod
    def rsi(prices: List[float], period: int = 14) -> List[float]:
        """Relative Strength Index."""
        if len(prices) < period + 1:
            return [50.0] * len(prices)  # Neutral RSI
        
        changes = [prices[i] - prices[i-1] for i in range(1, len(prices))]
        gains = [max(0, change) for change in changes]
        losses = [max(0, -change) for change in changes]
        
        rsi_values = [50.0]  # Start with neutral
        
        # Calculate initial average gain and loss
        avg_gain = sum(gains[:period]) / period
        avg_loss = sum(losses[:period]) / period
        
        for i in range(period, len(changes)):
            avg_gain = (avg_gain * (period - 1) + gains[i]) / period
            avg_loss = (avg_loss * (period - 1) + losses[i]) / period
            
            if avg_loss == 0:
                rsi_values.append(100.0)
            else:
                rs = avg_gain / avg_loss
                rsi = 100 - (100 / (1 + rs))
                rsi_values.append(rsi)
        
        # Fill remaining values
        while len(rsi_values) < len(prices):
            rsi_values.append(rsi_values[-1])
        
        return rsi_values
    
    @staticmethod
    def bollinger_bands(prices: List[float], period: int = 20, std_dev: float = 2) -> Tuple[List[float], List[float], List[float]]:
        """Bollinger Bands (Middle, Upper, Lower)."""
        sma_values = TechnicalIndicators.sma(prices, period)
        
        upper_bands = []
        lower_bands = []
        
        for i in range(len(prices)):
            if i < period - 1:
                # Use available data
                subset = prices[:i+1]
            else:
                subset = prices[i-period+1:i+1]
            
            if len(subset) > 1:
                std = statistics.stdev(subset)
            else:
                std = 0
            
            upper_bands.append(sma_values[i] + (std_dev * std))
            lower_bands.append(sma_values[i] - (std_dev * std))
        
        return sma_values, upper_bands, lower_bands
    
    @staticmethod
    def macd(prices: List[float], fast: int = 12, slow: int = 26, signal: int = 9) -> Tuple[List[float], List[float]]:
        """MACD and Signal Line."""
        ema_fast = TechnicalIndicators.ema(prices, fast)
        ema_slow = TechnicalIndicators.ema(prices, slow)
        
        macd_line = [fast_val - slow_val for fast_val, slow_val in zip(ema_fast, ema_slow)]
        signal_line = TechnicalIndicators.ema(macd_line, signal)
        
        return macd_line, signal_line

class EnhancedPredictor:
    """Enhanced prediction with multiple algorithms."""
    
    def __init__(self):
        self.indicators = TechnicalIndicators()
    
    def linear_regression_prediction(self, prices: List[float]) -> float:
        """Enhanced linear regression with trend analysis."""
        if len(prices) < 2:
            return prices[-1] * 1.001 if prices else 100.0
        
        n = len(prices)
        x_values = list(range(n))
        
        # Calculate linear regression
        x_mean = sum(x_values) / n
        y_mean = sum(prices) / n
        
        numerator = sum((x_values[i] - x_mean) * (prices[i] - y_mean) for i in range(n))
        denominator = sum((x_values[i] - x_mean) ** 2 for i in range(n))
        
        if denominator == 0:
            slope = 0
        else:
            slope = numerator / denominator
        
        intercept = y_mean - slope * x_mean
        
        # Predict next value
        next_x = n
        prediction = slope * next_x + intercept
        
        # Add trend strength factor
        r_squared = self._calculate_r_squared(prices, x_values, slope, intercept)
        trend_confidence = r_squared
        
        # Adjust prediction based on trend strength
        last_price = prices[-1]
        trend_adjustment = (prediction - last_price) * trend_confidence
        adjusted_prediction = last_price + trend_adjustment
        
        return max(0.01, adjusted_prediction)
    
    def moving_average_prediction(self, prices: List[float]) -> float:
        """Prediction based on multiple moving averages."""
        if len(prices) < 3:
            return prices[-1] * 1.001 if prices else 100.0
        
        # Calculate different period moving averages
        sma_5 = self.indicators.sma(prices, min(5, len(prices)))[-1]
        sma_10 = self.indicators.sma(prices, min(10, len(prices)))[-1]
        sma_20 = self.indicators.sma(prices, min(20, len(prices)))[-1]
        
        # Weight based on trend alignment
        current_price = prices[-1]
        
        # Determine trend direction
        if sma_5 > sma_10 > sma_20:
            # Strong uptrend
            prediction = current_price + (sma_5 - current_price) * 0.5
        elif sma_5 < sma_10 < sma_20:
            # Strong downtrend
            prediction = current_price + (sma_5 - current_price) * 0.5
        else:
            # Mixed signals, use weighted average
            prediction = (sma_5 * 0.5 + sma_10 * 0.3 + sma_20 * 0.2)
        
        return max(0.01, prediction)
    
    def momentum_prediction(self, prices: List[float]) -> float:
        """Prediction based on price momentum and RSI."""
        if len(prices) < 5:
            return prices[-1] * 1.001 if prices else 100.0
        
        current_price = prices[-1]
        
        # Calculate momentum
        momentum_3 = (current_price - prices[-4]) / prices[-4] if len(prices) >= 4 else 0
        momentum_5 = (current_price - prices[-6]) / prices[-6] if len(prices) >= 6 else 0
        
        # Calculate RSI
        rsi_values = self.indicators.rsi(prices)
        current_rsi = rsi_values[-1]
        
        # RSI-based adjustment
        if current_rsi > 70:  # Overbought
            rsi_factor = -0.02
        elif current_rsi < 30:  # Oversold
            rsi_factor = 0.02
        else:  # Neutral
            rsi_factor = 0
        
        # Combine momentum and RSI
        momentum_avg = (momentum_3 + momentum_5) / 2
        predicted_change = momentum_avg * 0.7 + rsi_factor
        
        prediction = current_price * (1 + predicted_change)
        return max(0.01, prediction)
    
    def bollinger_prediction(self, prices: List[float]) -> float:
        """Prediction based on Bollinger Bands."""
        if len(prices) < 10:
            return prices[-1] * 1.001 if prices else 100.0
        
        middle, upper, lower = self.indicators.bollinger_bands(prices)
        current_price = prices[-1]
        
        # Determine position within bands
        band_width = upper[-1] - lower[-1]
        if band_width == 0:
            return current_price * 1.001
        
        position = (current_price - lower[-1]) / band_width
        
        # Mean reversion logic
        if position > 0.8:  # Near upper band
            prediction = current_price + (middle[-1] - current_price) * 0.3
        elif position < 0.2:  # Near lower band
            prediction = current_price + (middle[-1] - current_price) * 0.3
        else:  # Middle range
            # Trend continuation
            recent_trend = (current_price - prices[-3]) / prices[-3] if len(prices) >= 3 else 0
            prediction = current_price * (1 + recent_trend * 0.5)
        
        return max(0.01, prediction)
    
    def ensemble_prediction(self, prices: List[float]) -> Dict:
        """Combine multiple prediction methods."""
        if len(prices) < 2:
            simple_pred = prices[-1] * 1.001 if prices else 100.0
            return {
                'prediction': simple_pred,
                'method': 'fallback',
                'confidence_factors': {'data_insufficient': True}
            }
        
        # Get predictions from different methods
        linear_pred = self.linear_regression_prediction(prices)
        ma_pred = self.moving_average_prediction(prices)
        momentum_pred = self.momentum_prediction(prices)
        bollinger_pred = self.bollinger_prediction(prices)
        
        # Calculate weights based on data quality and market conditions
        weights = self._calculate_method_weights(prices)
        
        # Weighted ensemble
        ensemble_pred = (
            linear_pred * weights['linear'] +
            ma_pred * weights['moving_average'] +
            momentum_pred * weights['momentum'] +
            bollinger_pred * weights['bollinger']
        )
        
        # Apply volatility-based bounds
        volatility = self._calculate_volatility(prices)
        max_change = min(0.15, volatility * 3)  # Dynamic max change based on volatility
        
        current_price = prices[-1]
        max_price = current_price * (1 + max_change)
        min_price = current_price * (1 - max_change)
        
        final_prediction = max(min_price, min(max_price, ensemble_pred))
        
        return {
            'prediction': final_prediction,
            'method': 'ensemble',
            'individual_predictions': {
                'linear': linear_pred,
                'moving_average': ma_pred,
                'momentum': momentum_pred,
                'bollinger': bollinger_pred
            },
            'weights': weights,
            'confidence_factors': {
                'volatility': volatility,
                'data_points': len(prices),
                'trend_strength': self._calculate_trend_strength(prices)
            }
        }
    
    def _calculate_method_weights(self, prices: List[float]) -> Dict[str, float]:
        """Calculate weights for different prediction methods."""
        n = len(prices)
        
        # Base weights
        weights = {
            'linear': 0.25,
            'moving_average': 0.30,
            'momentum': 0.25,
            'bollinger': 0.20
        }
        
        # Adjust based on data length
        if n < 5:
            weights['linear'] = 0.6
            weights['moving_average'] = 0.4
            weights['momentum'] = 0.0
            weights['bollinger'] = 0.0
        elif n < 10:
            weights['linear'] = 0.4
            weights['moving_average'] = 0.4
            weights['momentum'] = 0.2
            weights['bollinger'] = 0.0
        elif n < 20:
            weights['linear'] = 0.3
            weights['moving_average'] = 0.35
            weights['momentum'] = 0.25
            weights['bollinger'] = 0.1
        
        # Adjust based on volatility
        volatility = self._calculate_volatility(prices)
        if volatility > 0.05:  # High volatility
            weights['momentum'] *= 0.7  # Reduce momentum weight
            weights['bollinger'] *= 1.3  # Increase mean reversion weight
        
        # Normalize weights
        total = sum(weights.values())
        if total > 0:
            weights = {k: v/total for k, v in weights.items()}
        
        return weights
    
    def _calculate_volatility(self, prices: List[float]) -> float:
        """Calculate price volatility."""
        if len(prices) < 2:
            return 0.02  # Default volatility
        
        returns = [(prices[i] - prices[i-1]) / prices[i-1] for i in range(1, len(prices))]
        
        if len(returns) <= 1:
            return 0.02
        
        return statistics.stdev(returns)
    
    def _calculate_trend_strength(self, prices: List[float]) -> float:
        """Calculate trend strength (0-1)."""
        if len(prices) < 3:
            return 0.5
        
        # Calculate R-squared for linear trend
        n = len(prices)
        x_values = list(range(n))
        
        x_mean = sum(x_values) / n
        y_mean = sum(prices) / n
        
        numerator = sum((x_values[i] - x_mean) * (prices[i] - y_mean) for i in range(n))
        denominator = sum((x_values[i] - x_mean) ** 2 for i in range(n))
        
        if denominator == 0:
            return 0.5
        
        slope = numerator / denominator
        intercept = y_mean - slope * x_mean
        
        return self._calculate_r_squared(prices, x_values, slope, intercept)
    
    def _calculate_r_squared(self, y_values: List[float], x_values: List[float], slope: float, intercept: float) -> float:
        """Calculate R-squared value."""
        y_mean = sum(y_values) / len(y_values)
        
        ss_tot = sum((y - y_mean) ** 2 for y in y_values)
        ss_res = sum((y_values[i] - (slope * x_values[i] + intercept)) ** 2 for i in range(len(y_values)))
        
        if ss_tot == 0:
            return 0.0
        
        r_squared = 1 - (ss_res / ss_tot)
        return max(0.0, min(1.0, r_squared))

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 enhanced_predict.py <comma_separated_prices>", file=sys.stderr)
        sys.exit(1)
    
    try:
        # Parse input prices
        price_str = sys.argv[1]
        prices = [float(p.strip()) for p in price_str.split(',')]
        
        if len(prices) == 0:
            print("Error: No prices provided", file=sys.stderr)
            sys.exit(1)
        
        # Validate prices
        for i, price in enumerate(prices):
            if price <= 0:
                print(f"Error: Invalid price at position {i}: {price}", file=sys.stderr)
                sys.exit(1)
        
        # Create predictor and make prediction
        predictor = EnhancedPredictor()
        result = predictor.ensemble_prediction(prices)
        
        # Output just the prediction (for compatibility with existing Go service)
        print(f"{result['prediction']:.2f}")
        
        # Optionally output detailed results to stderr for debugging
        # print(f"DEBUG: {json.dumps(result, indent=2)}", file=sys.stderr)
        
    except ValueError as e:
        print(f"Error parsing prices: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Prediction error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
