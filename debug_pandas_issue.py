#!/usr/bin/env python3

import yfinance as yf
import pandas as pd
import numpy as np

# Test the pandas DataFrame issue
print("Testing pandas DataFrame operations...")

# Download MP data
ticker = yf.Ticker("MP")
data = ticker.history(period="1y")
print(f"Data shape: {data.shape}")
print(f"Data columns: {data.columns.tolist()}")

# Test Bollinger Bands calculation
df = data.copy()
df['BB_Middle'] = df['Close'].rolling(window=20).mean()
bb_std = df['Close'].rolling(window=20).std()

print(f"BB_Middle type: {type(df['BB_Middle'])}")
print(f"bb_std type: {type(bb_std)}")
print(f"bb_std shape: {bb_std.shape if hasattr(bb_std, 'shape') else 'No shape'}")

# Check if bb_std is a Series or DataFrame
if isinstance(bb_std, pd.DataFrame):
    print("bb_std is a DataFrame - this is the issue!")
    print(f"bb_std columns: {bb_std.columns.tolist()}")
    bb_std = bb_std.iloc[:, 0]  # Take first column
    print("Fixed: converted to Series")
elif isinstance(bb_std, pd.Series):
    print("bb_std is a Series - this is correct")

# Test the calculation
try:
    df['BB_Upper'] = df['BB_Middle'] + (bb_std * 2)
    df['BB_Lower'] = df['BB_Middle'] - (bb_std * 2)
    print("✅ Bollinger Bands calculation successful!")
except Exception as e:
    print(f"❌ Error: {e}")

print(f"Pandas version: {pd.__version__}")
