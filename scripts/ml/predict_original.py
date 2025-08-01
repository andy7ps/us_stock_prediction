#!/usr/bin/env python3
"""
Simple stock price prediction script using basic linear regression.
This version uses only Python standard library to avoid dependency issues.
In production, you would use a more sophisticated ML model like LSTM, GRU, or Transformer.
"""

import sys
import random
import math

def simple_linear_regression(x_values, y_values):
    """
    Simple linear regression implementation using only standard library.
    Returns slope and intercept.
    """
    n = len(x_values)
    if n < 2:
        return 0, y_values[0] if y_values else 0
    
    # Calculate means
    x_mean = sum(x_values) / n
    y_mean = sum(y_values) / n
    
    # Calculate slope
    numerator = sum((x_values[i] - x_mean) * (y_values[i] - y_mean) for i in range(n))
    denominator = sum((x_values[i] - x_mean) ** 2 for i in range(n))
    
    if denominator == 0:
        slope = 0
    else:
        slope = numerator / denominator
    
    # Calculate intercept
    intercept = y_mean - slope * x_mean
    
    return slope, intercept

def predict_price(prices):
    """
    Predict next price using simple linear regression.
    In production, this would load a pre-trained LSTM/GRU model.
    """
    if len(prices) < 2:
        # If insufficient data, return small positive change
        return prices[-1] * 1.001 if prices else 100.0
    
    # Create time series indices
    x_values = list(range(len(prices)))
    y_values = prices
    
    # Fit linear regression
    slope, intercept = simple_linear_regression(x_values, y_values)
    
    # Predict next price
    next_index = len(prices)
    predicted_price = slope * next_index + intercept
    
    # Add some realistic randomness (simulate model uncertainty)
    # In production, this would be actual model uncertainty
    noise_factor = 0.02  # 2% noise
    random.seed(int(sum(prices) * 1000) % 2147483647)  # Deterministic seed for consistency
    noise = random.gauss(0, predicted_price * noise_factor)
    predicted_price += noise
    
    # Ensure prediction is positive and reasonable
    if predicted_price <= 0:
        predicted_price = prices[-1] * 1.001
    
    # Limit extreme predictions (no more than 10% change)
    last_price = prices[-1]
    max_change = 0.10  # 10%
    max_price = last_price * (1 + max_change)
    min_price = last_price * (1 - max_change)
    
    if predicted_price > max_price:
        predicted_price = max_price
    elif predicted_price < min_price:
        predicted_price = min_price
    
    return predicted_price

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 predict.py <comma_separated_prices>", file=sys.stderr)
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
        
        # Make prediction
        predicted_price = predict_price(prices)
        
        # Output prediction (Go service expects just the number)
        print(f"{predicted_price:.2f}")
        
    except ValueError as e:
        print(f"Error parsing prices: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Prediction error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
