#!/usr/bin/env python3
"""
Model Training Script for Stock Prediction - Persistent Data Edition
Downloads real stock data and trains LSTM models for multiple symbols.
ALL data stored in persistent_data/ directory structure.
"""

import sys
import os
import pandas as pd
import numpy as np
import yfinance as yf
from datetime import datetime, timedelta
import argparse
import json
import joblib
from pathlib import Path
from lstm_model import LSTMStockPredictor, AdvancedFeatureEngineer

# PERSISTENT DATA PATHS - MANDATORY
PERSISTENT_DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), 'persistent_data')
DEFAULT_MODEL_DIR = os.path.join(PERSISTENT_DATA_DIR, 'ml_models')
DEFAULT_SCALERS_DIR = os.path.join(PERSISTENT_DATA_DIR, 'scalers')
DEFAULT_CACHE_DIR = os.path.join(PERSISTENT_DATA_DIR, 'ml_cache')
DEFAULT_DATA_DIR = os.path.join(PERSISTENT_DATA_DIR, 'stock_data')
DEFAULT_LOG_DIR = os.path.join(PERSISTENT_DATA_DIR, 'logs', 'training')

def ensure_persistent_data_structure():
    """Ensure persistent data directory structure exists."""
    if not os.path.exists(PERSISTENT_DATA_DIR):
        raise RuntimeError(f"Persistent data directory not found: {PERSISTENT_DATA_DIR}")
    
    # Create required directories
    for directory in [DEFAULT_MODEL_DIR, DEFAULT_SCALERS_DIR, DEFAULT_CACHE_DIR, DEFAULT_DATA_DIR, DEFAULT_LOG_DIR]:
        os.makedirs(directory, exist_ok=True)
    
    print(f"✅ Persistent data structure verified: {PERSISTENT_DATA_DIR}")

def log_training_info(message, log_dir=DEFAULT_LOG_DIR):
    """Log training information to persistent storage."""
    log_file = os.path.join(log_dir, 'training.log')
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    with open(log_file, 'a') as f:
        f.write(f"[{timestamp}] {message}\n")
    print(f"[{timestamp}] {message}")

def download_stock_data(symbol, period='2y', cache_dir=DEFAULT_CACHE_DIR):
    """Download stock data using yfinance with persistent caching."""
    try:
        # Check cache first
        cache_file = os.path.join(cache_dir, f"{symbol.lower()}_data.pkl")
        
        if os.path.exists(cache_file):
            # Check if cache is recent (less than 1 day old)
            cache_age = datetime.now() - datetime.fromtimestamp(os.path.getmtime(cache_file))
            if cache_age.days < 1:
                log_training_info(f"Loading cached data for {symbol}")
                return pd.read_pickle(cache_file)
        
        log_training_info(f"Downloading fresh data for {symbol}")
        ticker = yf.Ticker(symbol)
        data = ticker.history(period=period)
        
        if data.empty:
            log_training_info(f"No data found for symbol {symbol}")
            return None
        
        # Rename columns to lowercase
        data.columns = [col.lower() for col in data.columns]
        data.reset_index(inplace=True)
        
        # Cache the data
        data.to_pickle(cache_file)
        log_training_info(f"Data cached for {symbol}: {cache_file}")
        
        return data
        
    except Exception as e:
        log_training_info(f"Error downloading data for {symbol}: {str(e)}")
        return None

def train_model_for_symbol(symbol, model_dir=DEFAULT_MODEL_DIR, scalers_dir=DEFAULT_SCALERS_DIR, 
                          cache_dir=DEFAULT_CACHE_DIR, data_dir=DEFAULT_DATA_DIR, 
                          log_dir=DEFAULT_LOG_DIR, epochs=50, quick=False):
    """Train LSTM model for a specific symbol with persistent data storage."""
    
    log_training_info(f"=== Training model for {symbol} ===")
    log_training_info(f"Model directory: {model_dir}")
    log_training_info(f"Scalers directory: {scalers_dir}")
    log_training_info(f"Cache directory: {cache_dir}")
    
    # Download data
    data = download_stock_data(symbol, cache_dir=cache_dir)
    if data is None:
        log_training_info(f"Failed to download data for {symbol}")
        return False
    
    log_training_info(f"Downloaded {len(data)} data points for {symbol}")
    
    # Feature engineering
    feature_engineer = AdvancedFeatureEngineer()
    enhanced_data = feature_engineer.create_features(data)
    
    if enhanced_data is None or len(enhanced_data) < 100:
        log_training_info(f"Insufficient data for {symbol} after feature engineering")
        return False
    
    log_training_info(f"Created {enhanced_data.shape[1]} features for {symbol}")
    
    # Initialize predictor
    predictor = LSTMStockPredictor(
        sequence_length=60,
        epochs=10 if quick else epochs,
        batch_size=32,
        validation_split=0.2
    )
    
    try:
        # Train model
        log_training_info(f"Training LSTM model for {symbol} ({'quick' if quick else 'full'} training)")
        history = predictor.train(enhanced_data)
        
        # Save model to persistent storage
        model_file = os.path.join(model_dir, f"{symbol.lower()}_lstm_model.h5")
        predictor.model.save(model_file)
        log_training_info(f"Model saved: {model_file}")
        
        # Save scalers to persistent storage
        scaler_file = os.path.join(scalers_dir, f"{symbol.lower()}_lstm_model_scalers.pkl")
        joblib.dump(predictor.scalers, scaler_file)
        log_training_info(f"Scalers saved: {scaler_file}")
        
        # Save training metadata
        metadata = {
            'symbol': symbol,
            'training_date': datetime.now().isoformat(),
            'data_points': len(enhanced_data),
            'features': enhanced_data.shape[1],
            'epochs': predictor.epochs,
            'sequence_length': predictor.sequence_length,
            'model_file': model_file,
            'scaler_file': scaler_file,
            'training_type': 'quick' if quick else 'full'
        }
        
        metadata_file = os.path.join(log_dir, f"{symbol.lower()}_training_metadata.json")
        with open(metadata_file, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        log_training_info(f"Training completed successfully for {symbol}")
        log_training_info(f"Metadata saved: {metadata_file}")
        
        return True
        
    except Exception as e:
        log_training_info(f"Error training model for {symbol}: {str(e)}")
        return False

def main():
    parser = argparse.ArgumentParser(description='Train LSTM models for stock prediction - Persistent Data Edition')
    parser.add_argument('--symbols', nargs='+', default=['NVDA'], 
                       help='Stock symbols to train (default: NVDA)')
    parser.add_argument('--model-dir', default=DEFAULT_MODEL_DIR,
                       help=f'Directory to save models (default: {DEFAULT_MODEL_DIR})')
    parser.add_argument('--scalers-dir', default=DEFAULT_SCALERS_DIR,
                       help=f'Directory to save scalers (default: {DEFAULT_SCALERS_DIR})')
    parser.add_argument('--cache-dir', default=DEFAULT_CACHE_DIR,
                       help=f'Directory for data cache (default: {DEFAULT_CACHE_DIR})')
    parser.add_argument('--data-dir', default=DEFAULT_DATA_DIR,
                       help=f'Directory for stock data (default: {DEFAULT_DATA_DIR})')
    parser.add_argument('--log-dir', default=DEFAULT_LOG_DIR,
                       help=f'Directory for logs (default: {DEFAULT_LOG_DIR})')
    parser.add_argument('--epochs', type=int, default=50,
                       help='Number of training epochs (default: 50)')
    parser.add_argument('--quick', action='store_true',
                       help='Quick training with 10 epochs')
    
    args = parser.parse_args()
    
    # Ensure persistent data structure
    try:
        ensure_persistent_data_structure()
    except RuntimeError as e:
        print(f"❌ {e}")
        print("Run: ./setup_persistent_data.sh")
        sys.exit(1)
    
    log_training_info("=== ML Model Training - Persistent Data Edition ===")
    log_training_info(f"Persistent data directory: {PERSISTENT_DATA_DIR}")
    log_training_info(f"Symbols to train: {args.symbols}")
    log_training_info(f"Model directory: {args.model_dir}")
    log_training_info(f"Scalers directory: {args.scalers_dir}")
    log_training_info(f"Epochs: {args.epochs}")
    log_training_info(f"Quick training: {args.quick}")
    
    # Train models for each symbol
    successful_trainings = 0
    failed_trainings = 0
    
    for symbol in args.symbols:
        symbol = symbol.upper()
        log_training_info(f"Starting training for {symbol}")
        
        success = train_model_for_symbol(
            symbol=symbol,
            model_dir=args.model_dir,
            scalers_dir=args.scalers_dir,
            cache_dir=args.cache_dir,
            data_dir=args.data_dir,
            log_dir=args.log_dir,
            epochs=args.epochs,
            quick=args.quick
        )
        
        if success:
            successful_trainings += 1
            log_training_info(f"✅ Successfully trained model for {symbol}")
        else:
            failed_trainings += 1
            log_training_info(f"❌ Failed to train model for {symbol}")
    
    # Summary
    log_training_info("=== Training Summary ===")
    log_training_info(f"Successful trainings: {successful_trainings}")
    log_training_info(f"Failed trainings: {failed_trainings}")
    log_training_info(f"Total symbols processed: {len(args.symbols)}")
    log_training_info(f"All data stored in: {PERSISTENT_DATA_DIR}")
    
    if failed_trainings > 0:
        sys.exit(1)
    else:
        log_training_info("🎉 All training completed successfully!")

if __name__ == "__main__":
    main()
