#!/usr/bin/env python3
"""
Model Training Script for Stock Prediction
Downloads real stock data and trains LSTM models for multiple symbols.
"""

import sys
import os
import pandas as pd
import numpy as np
import yfinance as yf
from datetime import datetime, timedelta
import argparse
import json
from lstm_model import LSTMStockPredictor, AdvancedFeatureEngineer

def download_stock_data(symbol, period='2y'):
    """Download stock data using yfinance."""
    try:
        ticker = yf.Ticker(symbol)
        data = ticker.history(period=period)
        
        if data.empty:
            print(f"No data found for symbol {symbol}")
            return None
        
        # Rename columns to lowercase
        data.columns = [col.lower() for col in data.columns]
        data.reset_index(inplace=True)
        
        return data
    
    except Exception as e:
        print(f"Error downloading data for {symbol}: {e}")
        return None

def evaluate_model(predictor, test_data, symbol):
    """Evaluate model performance."""
    predictions = []
    actuals = []
    
    # Use sliding window for evaluation
    window_size = predictor.sequence_length
    
    for i in range(window_size, len(test_data)):
        # Get historical data up to current point
        hist_data = test_data.iloc[:i]
        
        # Make prediction
        pred = predictor.predict(hist_data)
        actual = test_data.iloc[i]['close']
        
        predictions.append(pred)
        actuals.append(actual)
    
    if len(predictions) == 0:
        return None
    
    # Calculate metrics
    predictions = np.array(predictions)
    actuals = np.array(actuals)
    
    mse = np.mean((predictions - actuals) ** 2)
    mae = np.mean(np.abs(predictions - actuals))
    mape = np.mean(np.abs((predictions - actuals) / actuals)) * 100
    
    # Direction accuracy
    pred_direction = np.diff(predictions) > 0
    actual_direction = np.diff(actuals) > 0
    direction_accuracy = np.mean(pred_direction == actual_direction) * 100
    
    return {
        'symbol': symbol,
        'mse': float(mse),
        'mae': float(mae),
        'mape': float(mape),
        'direction_accuracy': float(direction_accuracy),
        'predictions_count': len(predictions)
    }

def train_single_model(symbol, model_dir, test_split=0.2, epochs=50):
    """Train model for a single stock symbol."""
    print(f"\n=== Training model for {symbol} ===")
    
    # Download data
    print(f"Downloading data for {symbol}...")
    data = download_stock_data(symbol, period='2y')
    
    if data is None or len(data) < 100:
        print(f"Insufficient data for {symbol}, skipping...")
        return None
    
    print(f"Downloaded {len(data)} data points for {symbol}")
    
    # Split data
    split_idx = int(len(data) * (1 - test_split))
    train_data = data.iloc[:split_idx].copy()
    test_data = data.iloc[split_idx:].copy()
    
    print(f"Training data: {len(train_data)} points")
    print(f"Test data: {len(test_data)} points")
    
    # Initialize predictor
    model_path = os.path.join(model_dir, f"{symbol.lower()}_lstm_model")
    predictor = LSTMStockPredictor(sequence_length=60, model_path=model_path)
    
    # Train model
    print("Training LSTM model...")
    history = predictor.train_model(train_data, epochs=epochs, batch_size=32)
    
    if history is None:
        print("Training failed, using statistical fallback")
        return None
    
    # Evaluate model
    print("Evaluating model...")
    evaluation = evaluate_model(predictor, test_data, symbol)
    
    if evaluation:
        print(f"Evaluation Results for {symbol}:")
        print(f"  MSE: {evaluation['mse']:.4f}")
        print(f"  MAE: {evaluation['mae']:.4f}")
        print(f"  MAPE: {evaluation['mape']:.2f}%")
        print(f"  Direction Accuracy: {evaluation['direction_accuracy']:.2f}%")
    
    return evaluation

def train_multiple_models(symbols, model_dir, epochs=50):
    """Train models for multiple symbols."""
    results = []
    
    # Create model directory
    os.makedirs(model_dir, exist_ok=True)
    
    for symbol in symbols:
        try:
            result = train_single_model(symbol, model_dir, epochs=epochs)
            if result:
                results.append(result)
        except Exception as e:
            print(f"Error training model for {symbol}: {e}")
            continue
    
    return results

def save_training_results(results, output_file):
    """Save training results to JSON file."""
    summary = {
        'training_date': datetime.now().isoformat(),
        'models_trained': len(results),
        'results': results
    }
    
    if results:
        # Calculate average metrics
        avg_metrics = {
            'avg_mse': np.mean([r['mse'] for r in results]),
            'avg_mae': np.mean([r['mae'] for r in results]),
            'avg_mape': np.mean([r['mape'] for r in results]),
            'avg_direction_accuracy': np.mean([r['direction_accuracy'] for r in results])
        }
        summary['average_metrics'] = avg_metrics
    
    with open(output_file, 'w') as f:
        json.dump(summary, f, indent=2)
    
    print(f"\nTraining results saved to {output_file}")

def main():
    parser = argparse.ArgumentParser(description='Train LSTM models for stock prediction')
    parser.add_argument('--symbols', nargs='+', default=['NVDA', 'TSLA', 'AAPL', 'MSFT', 'GOOGL'],
                        help='Stock symbols to train models for')
    parser.add_argument('--model-dir', default='/app/persistent_data/ml_models',
                        help='Directory to save trained models')
    parser.add_argument('--epochs', type=int, default=50,
                        help='Number of training epochs')
    parser.add_argument('--output', default='training_results.json',
                        help='Output file for training results')
    
    args = parser.parse_args()
    
    print("=== Stock Prediction Model Training ===")
    print(f"Symbols: {args.symbols}")
    print(f"Model directory: {args.model_dir}")
    print(f"Epochs: {args.epochs}")
    
    # Check if required packages are available
    try:
        import tensorflow as tf
        print(f"TensorFlow version: {tf.__version__}")
    except ImportError:
        print("Warning: TensorFlow not available, training will be limited")
    
    try:
        import yfinance as yf
        print(f"yfinance available")
    except ImportError:
        print("Error: yfinance not available, cannot download data")
        print("Install with: pip install yfinance")
        sys.exit(1)
    
    # Train models
    results = train_multiple_models(args.symbols, args.model_dir, args.epochs)
    
    # Save results
    save_training_results(results, args.output)
    
    # Print summary
    if results:
        print(f"\n=== Training Summary ===")
        print(f"Successfully trained {len(results)} models")
        avg_direction_acc = np.mean([r['direction_accuracy'] for r in results])
        print(f"Average direction accuracy: {avg_direction_acc:.2f}%")
        
        # Best performing model
        best_model = max(results, key=lambda x: x['direction_accuracy'])
        print(f"Best performing model: {best_model['symbol']} ({best_model['direction_accuracy']:.2f}% direction accuracy)")
    else:
        print("No models were successfully trained")

if __name__ == "__main__":
    main()
