#!/usr/bin/env python3
"""
Advanced stock price prediction using full OHLCV data and multiple algorithms.
Supports both simple price input (backward compatibility) and full OHLCV JSON input.
"""

import sys
import json
import math
import statistics
from typing import List, Dict, Tuple, Optional, Union

class OHLCVData:
    """Represents OHLCV (Open, High, Low, Close, Volume) data point."""
    
    def __init__(self, open_price: float, high: float, low: float, close: float, volume: int = 0):
        self.open = open_price
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    
    @classmethod
    def from_close_only(cls, close: float):
        """Create OHLCV data with only close price (for backward compatibility)."""
        return cls(close, close, close, close, 0)
    
    def typical_price(self) -> float:
        """Calculate typical price (HLC/3)."""
        return (self.high + self.low + self.close) / 3
    
    def true_range(self, prev_close: Optional[float] = None) -> float:
        """Calculate True Range."""
        if prev_close is None:
            return self.high - self.low
        
        return max(
            self.high - self.low,
            abs(self.high - prev_close),
            abs(self.low - prev_close)
        )

class AdvancedTechnicalIndicators:
    """Advanced technical indicators using OHLCV data."""
    
    @staticmethod
    def atr(data: List[OHLCVData], period: int = 14) -> List[float]:
        """Average True Range."""
        if len(data) < 2:
            return [0.0] * len(data)
        
        true_ranges = [data[0].high - data[0].low]  # First TR
        
        for i in range(1, len(data)):
            tr = data[i].true_range(data[i-1].close)
            true_ranges.append(tr)
        
        # Calculate ATR using EMA
        atr_values = [true_ranges[0]]
        multiplier = 2 / (period + 1)
        
        for i in range(1, len(true_ranges)):
            atr_val = (true_ranges[i] * multiplier) + (atr_values[-1] * (1 - multiplier))
            atr_values.append(atr_val)
        
        return atr_values
    
    @staticmethod
    def volume_weighted_average_price(data: List[OHLCVData]) -> List[float]:
        """Volume Weighted Average Price."""
        vwap_values = []
        cumulative_volume = 0
        cumulative_pv = 0
        
        for candle in data:
            if candle.volume > 0:
                typical = candle.typical_price()
                cumulative_pv += typical * candle.volume
                cumulative_volume += candle.volume
                vwap = cumulative_pv / cumulative_volume if cumulative_volume > 0 else candle.close
            else:
                vwap = candle.close
            
            vwap_values.append(vwap)
        
        return vwap_values
    
    @staticmethod
    def stochastic_oscillator(data: List[OHLCVData], k_period: int = 14, d_period: int = 3) -> Tuple[List[float], List[float]]:
        """Stochastic Oscillator (%K and %D)."""
        if len(data) < k_period:
            k_values = [50.0] * len(data)
            d_values = [50.0] * len(data)
            return k_values, d_values
        
        k_values = []
        
        for i in range(len(data)):
            if i < k_period - 1:
                k_values.append(50.0)  # Default neutral value
            else:
                # Get highest high and lowest low in the period
                period_data = data[i-k_period+1:i+1]
                highest_high = max(candle.high for candle in period_data)
                lowest_low = min(candle.low for candle in period_data)
                
                if highest_high == lowest_low:
                    k_val = 50.0
                else:
                    k_val = ((data[i].close - lowest_low) / (highest_high - lowest_low)) * 100
                
                k_values.append(k_val)
        
        # Calculate %D (SMA of %K)
        d_values = []
        for i in range(len(k_values)):
            if i < d_period - 1:
                d_values.append(sum(k_values[:i+1]) / (i+1))
            else:
                d_values.append(sum(k_values[i-d_period+1:i+1]) / d_period)
        
        return k_values, d_values
    
    @staticmethod
    def on_balance_volume(data: List[OHLCVData]) -> List[float]:
        """On Balance Volume."""
        if not data:
            return []
        
        obv_values = [0.0]  # Start with 0
        
        for i in range(1, len(data)):
            if data[i].close > data[i-1].close:
                obv_val = obv_values[-1] + data[i].volume
            elif data[i].close < data[i-1].close:
                obv_val = obv_values[-1] - data[i].volume
            else:
                obv_val = obv_values[-1]
            
            obv_values.append(obv_val)
        
        return obv_values

class AdvancedPredictor:
    """Advanced prediction using full OHLCV data and multiple sophisticated algorithms."""
    
    def __init__(self):
        self.indicators = AdvancedTechnicalIndicators()
    
    def support_resistance_prediction(self, data: List[OHLCVData]) -> float:
        """Prediction based on support and resistance levels."""
        if len(data) < 5:
            return data[-1].close * 1.001
        
        closes = [candle.close for candle in data]
        highs = [candle.high for candle in data]
        lows = [candle.low for candle in data]
        
        current_price = closes[-1]
        
        # Find recent support and resistance levels
        resistance_levels = self._find_resistance_levels(highs, closes)
        support_levels = self._find_support_levels(lows, closes)
        
        # Determine prediction based on proximity to levels
        nearest_resistance = min(resistance_levels, key=lambda x: abs(x - current_price)) if resistance_levels else current_price * 1.05
        nearest_support = min(support_levels, key=lambda x: abs(x - current_price)) if support_levels else current_price * 0.95
        
        # Calculate prediction based on position relative to support/resistance
        if current_price > nearest_resistance * 0.98:  # Near resistance
            prediction = current_price + (nearest_support - current_price) * 0.2  # Pull toward support
        elif current_price < nearest_support * 1.02:  # Near support
            prediction = current_price + (nearest_resistance - current_price) * 0.2  # Push toward resistance
        else:  # Between levels
            # Trend continuation with mean reversion bias
            recent_trend = (current_price - closes[-3]) / closes[-3] if len(closes) >= 3 else 0
            prediction = current_price * (1 + recent_trend * 0.3)
        
        return max(0.01, prediction)
    
    def volume_price_prediction(self, data: List[OHLCVData]) -> float:
        """Prediction based on volume-price analysis."""
        if len(data) < 3:
            return data[-1].close * 1.001
        
        current = data[-1]
        
        # Calculate volume trend
        recent_volumes = [candle.volume for candle in data[-5:] if candle.volume > 0]
        if len(recent_volumes) < 2:
            return current.close * 1.001
        
        avg_volume = sum(recent_volumes) / len(recent_volumes)
        volume_ratio = current.volume / avg_volume if avg_volume > 0 else 1.0
        
        # Calculate price change
        price_change = (current.close - data[-2].close) / data[-2].close
        
        # Volume-confirmed moves are more likely to continue
        if volume_ratio > 1.5 and abs(price_change) > 0.01:  # High volume with significant price move
            prediction = current.close * (1 + price_change * 0.5)  # Continuation
        elif volume_ratio < 0.5:  # Low volume
            # Mean reversion tendency
            sma_5 = sum(candle.close for candle in data[-5:]) / min(5, len(data))
            prediction = current.close + (sma_5 - current.close) * 0.3
        else:  # Normal volume
            # Moderate trend continuation
            prediction = current.close * (1 + price_change * 0.2)
        
        return max(0.01, prediction)
    
    def volatility_breakout_prediction(self, data: List[OHLCVData]) -> float:
        """Prediction based on volatility and breakout patterns."""
        if len(data) < 10:
            return data[-1].close * 1.001
        
        # Calculate ATR for volatility
        atr_values = self.indicators.atr(data)
        current_atr = atr_values[-1]
        avg_atr = sum(atr_values[-5:]) / min(5, len(atr_values))
        
        current = data[-1]
        
        # Detect breakout conditions
        recent_range = max(candle.high for candle in data[-5:]) - min(candle.low for candle in data[-5:])
        
        if current_atr > avg_atr * 1.5:  # High volatility
            # Expect continuation of breakout
            if current.close > current.open:  # Bullish breakout
                prediction = current.close + (current_atr * 0.5)
            else:  # Bearish breakout
                prediction = current.close - (current_atr * 0.5)
        else:  # Low volatility
            # Expect compression before breakout
            sma_10 = sum(candle.close for candle in data[-10:]) / 10
            prediction = current.close + (sma_10 - current.close) * 0.2  # Move toward mean
        
        return max(0.01, prediction)
    
    def multi_timeframe_prediction(self, data: List[OHLCVData]) -> float:
        """Prediction using multiple timeframe analysis."""
        if len(data) < 5:
            return data[-1].close * 1.001
        
        closes = [candle.close for candle in data]
        current_price = closes[-1]
        
        # Short-term trend (last 3 periods)
        short_trend = (closes[-1] - closes[-3]) / closes[-3] if len(closes) >= 3 else 0
        
        # Medium-term trend (last 7 periods)
        medium_trend = (closes[-1] - closes[-7]) / closes[-7] if len(closes) >= 7 else 0
        
        # Long-term trend (all available data)
        long_trend = (closes[-1] - closes[0]) / closes[0] if len(closes) >= 2 else 0
        
        # Weight trends based on alignment
        if (short_trend > 0 and medium_trend > 0 and long_trend > 0) or \
           (short_trend < 0 and medium_trend < 0 and long_trend < 0):
            # All trends aligned - strong signal
            trend_weight = 0.7
            combined_trend = (short_trend * 0.5 + medium_trend * 0.3 + long_trend * 0.2)
        else:
            # Mixed signals - reduce confidence
            trend_weight = 0.3
            combined_trend = short_trend * 0.6 + medium_trend * 0.4  # Focus on shorter term
        
        prediction = current_price * (1 + combined_trend * trend_weight)
        return max(0.01, prediction)
    
    def ensemble_ohlcv_prediction(self, data: List[OHLCVData]) -> Dict:
        """Advanced ensemble prediction using all OHLCV data."""
        if len(data) < 2:
            simple_pred = data[-1].close * 1.001 if data else 100.0
            return {
                'prediction': simple_pred,
                'method': 'fallback',
                'confidence_factors': {'data_insufficient': True}
            }
        
        # Get predictions from different methods
        sr_pred = self.support_resistance_prediction(data)
        vp_pred = self.volume_price_prediction(data)
        vb_pred = self.volatility_breakout_prediction(data)
        mt_pred = self.multi_timeframe_prediction(data)
        
        # Calculate method weights based on market conditions
        weights = self._calculate_ohlcv_weights(data)
        
        # Weighted ensemble
        ensemble_pred = (
            sr_pred * weights['support_resistance'] +
            vp_pred * weights['volume_price'] +
            vb_pred * weights['volatility_breakout'] +
            mt_pred * weights['multi_timeframe']
        )
        
        # Apply dynamic bounds based on ATR
        atr_values = self.indicators.atr(data)
        current_atr = atr_values[-1] if atr_values else 0.02
        current_price = data[-1].close
        
        # Use ATR for dynamic bounds
        max_change = min(0.15, current_atr / current_price * 2)
        max_price = current_price * (1 + max_change)
        min_price = current_price * (1 - max_change)
        
        final_prediction = max(min_price, min(max_price, ensemble_pred))
        
        return {
            'prediction': final_prediction,
            'method': 'advanced_ensemble',
            'individual_predictions': {
                'support_resistance': sr_pred,
                'volume_price': vp_pred,
                'volatility_breakout': vb_pred,
                'multi_timeframe': mt_pred
            },
            'weights': weights,
            'confidence_factors': {
                'atr': current_atr,
                'data_points': len(data),
                'volume_available': any(candle.volume > 0 for candle in data),
                'price_range': max(candle.high for candle in data) - min(candle.low for candle in data)
            }
        }
    
    def _calculate_ohlcv_weights(self, data: List[OHLCVData]) -> Dict[str, float]:
        """Calculate weights for OHLCV-based prediction methods."""
        n = len(data)
        
        # Base weights
        weights = {
            'support_resistance': 0.30,
            'volume_price': 0.25,
            'volatility_breakout': 0.25,
            'multi_timeframe': 0.20
        }
        
        # Adjust based on data availability
        has_volume = any(candle.volume > 0 for candle in data)
        if not has_volume:
            # Redistribute volume_price weight
            weights['volume_price'] = 0.05
            weights['support_resistance'] += 0.10
            weights['volatility_breakout'] += 0.05
            weights['multi_timeframe'] += 0.05
        
        # Adjust based on data length
        if n < 10:
            weights['support_resistance'] = 0.20
            weights['multi_timeframe'] = 0.40
        elif n > 20:
            weights['support_resistance'] = 0.35
            weights['volatility_breakout'] = 0.30
        
        # Normalize weights
        total = sum(weights.values())
        if total > 0:
            weights = {k: v/total for k, v in weights.items()}
        
        return weights
    
    def _find_resistance_levels(self, highs: List[float], closes: List[float]) -> List[float]:
        """Find resistance levels from price data."""
        if len(highs) < 3:
            return []
        
        resistance_levels = []
        
        # Find local maxima
        for i in range(1, len(highs) - 1):
            if highs[i] > highs[i-1] and highs[i] > highs[i+1]:
                resistance_levels.append(highs[i])
        
        # Add recent high
        if highs:
            resistance_levels.append(max(highs[-5:]))
        
        return list(set(resistance_levels))  # Remove duplicates
    
    def _find_support_levels(self, lows: List[float], closes: List[float]) -> List[float]:
        """Find support levels from price data."""
        if len(lows) < 3:
            return []
        
        support_levels = []
        
        # Find local minima
        for i in range(1, len(lows) - 1):
            if lows[i] < lows[i-1] and lows[i] < lows[i+1]:
                support_levels.append(lows[i])
        
        # Add recent low
        if lows:
            support_levels.append(min(lows[-5:]))
        
        return list(set(support_levels))  # Remove duplicates

def parse_input(input_str: str) -> List[OHLCVData]:
    """Parse input - either simple prices or JSON OHLCV data."""
    try:
        # Try to parse as JSON first (advanced mode)
        json_data = json.loads(input_str)
        
        if isinstance(json_data, list) and len(json_data) > 0:
            if isinstance(json_data[0], dict):
                # OHLCV JSON format
                ohlcv_data = []
                for item in json_data:
                    ohlcv_data.append(OHLCVData(
                        open_price=item.get('open', item.get('close', 0)),
                        high=item.get('high', item.get('close', 0)),
                        low=item.get('low', item.get('close', 0)),
                        close=item.get('close', 0),
                        volume=item.get('volume', 0)
                    ))
                return ohlcv_data
    except (json.JSONDecodeError, KeyError):
        pass
    
    # Fallback to simple comma-separated prices (backward compatibility)
    prices = [float(p.strip()) for p in input_str.split(',')]
    return [OHLCVData.from_close_only(price) for price in prices]

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 advanced_predict.py <comma_separated_prices_or_json>", file=sys.stderr)
        sys.exit(1)
    
    try:
        # Parse input data
        input_str = sys.argv[1]
        ohlcv_data = parse_input(input_str)
        
        if len(ohlcv_data) == 0:
            print("Error: No data provided", file=sys.stderr)
            sys.exit(1)
        
        # Validate data
        for i, candle in enumerate(ohlcv_data):
            if candle.close <= 0:
                print(f"Error: Invalid price at position {i}: {candle.close}", file=sys.stderr)
                sys.exit(1)
        
        # Create predictor and make prediction
        predictor = AdvancedPredictor()
        result = predictor.ensemble_ohlcv_prediction(ohlcv_data)
        
        # Output just the prediction (for compatibility with existing Go service)
        print(f"{result['prediction']:.2f}")
        
        # Optionally output detailed results to stderr for debugging
        # print(f"DEBUG: {json.dumps(result, indent=2)}", file=sys.stderr)
        
    except ValueError as e:
        print(f"Error parsing input: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Prediction error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
