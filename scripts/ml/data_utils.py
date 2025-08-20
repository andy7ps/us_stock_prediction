#!/usr/bin/env python3
"""
Common data utilities for stock prediction models
Handles yfinance compatibility and data preprocessing
"""

import pandas as pd
import yfinance as yf
from datetime import datetime, timedelta
import warnings
warnings.filterwarnings('ignore')

def download_stock_data(symbol, days=730, end_date=None):
    """
    Download stock data with automatic MultiIndex column fixing
    
    Args:
        symbol (str): Stock symbol to download
        days (int): Number of days of historical data (default: 730 = 2 years)
        end_date (datetime): End date for data (default: now)
    
    Returns:
        pd.DataFrame: Stock data with fixed column names
    """
    if end_date is None:
        end_date = datetime.now()
    
    start_date = end_date - timedelta(days=days)
    
    print(f"Downloading data for {symbol}...")
    stock_data = yf.download(symbol, start=start_date, end=end_date)
    
    # Fix MultiIndex columns issue (yfinance compatibility)
    if isinstance(stock_data.columns, pd.MultiIndex):
        stock_data.columns = stock_data.columns.get_level_values(0)
        print(f"  ✅ Fixed MultiIndex columns for {symbol}")
    
    if stock_data.empty:
        raise ValueError(f"No data available for {symbol}")
    
    print(f"Downloaded {len(stock_data)} days of data for {symbol}")
    return stock_data

def validate_stock_data(stock_data, required_columns=None):
    """
    Validate stock data has required columns and sufficient data
    
    Args:
        stock_data (pd.DataFrame): Stock data to validate
        required_columns (list): List of required column names
    
    Returns:
        bool: True if data is valid
    """
    if required_columns is None:
        required_columns = ['Open', 'High', 'Low', 'Close', 'Volume']
    
    # Check if all required columns exist
    missing_columns = [col for col in required_columns if col not in stock_data.columns]
    if missing_columns:
        raise ValueError(f"Missing required columns: {missing_columns}")
    
    # Check for sufficient data
    if len(stock_data) < 100:
        raise ValueError(f"Insufficient data: only {len(stock_data)} rows available")
    
    # Check for excessive NaN values
    nan_percentage = stock_data.isnull().sum().max() / len(stock_data)
    if nan_percentage > 0.1:  # More than 10% NaN values
        raise ValueError(f"Too many NaN values: {nan_percentage:.1%}")
    
    return True

def clean_stock_data(stock_data):
    """
    Clean stock data by handling NaN values and outliers
    
    Args:
        stock_data (pd.DataFrame): Raw stock data
    
    Returns:
        pd.DataFrame: Cleaned stock data
    """
    # Forward fill NaN values
    stock_data = stock_data.fillna(method='ffill')
    
    # Backward fill any remaining NaN values
    stock_data = stock_data.fillna(method='bfill')
    
    # Remove any remaining rows with NaN values
    stock_data = stock_data.dropna()
    
    # Basic outlier detection for volume (remove zero volume days)
    if 'Volume' in stock_data.columns:
        stock_data = stock_data[stock_data['Volume'] > 0]
    
    return stock_data

def get_recent_data(symbol, days=100):
    """
    Get recent stock data for predictions
    
    Args:
        symbol (str): Stock symbol
        days (int): Number of recent days to get
    
    Returns:
        pd.DataFrame: Recent stock data
    """
    return download_stock_data(symbol, days=days)

# Backward compatibility functions
def fix_multiindex_columns(stock_data):
    """
    Fix MultiIndex columns (backward compatibility)
    
    Args:
        stock_data (pd.DataFrame): Stock data with potential MultiIndex columns
    
    Returns:
        pd.DataFrame: Stock data with fixed columns
    """
    if isinstance(stock_data.columns, pd.MultiIndex):
        stock_data.columns = stock_data.columns.get_level_values(0)
    return stock_data
