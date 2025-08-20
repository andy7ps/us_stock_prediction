#!/usr/bin/env python3

import yfinance as yf
import pandas as pd

# Test different ways of getting yfinance data
print("Testing yfinance data structures...")

# Method 1: Direct ticker.history()
ticker = yf.Ticker("MP")
data1 = ticker.history(period="1y")
print(f"Method 1 - ticker.history():")
print(f"  Type: {type(data1)}")
print(f"  Shape: {data1.shape}")
print(f"  Columns: {data1.columns.tolist()}")
print(f"  Index: {type(data1.index)}")

# Method 2: yf.download()
data2 = yf.download("MP", period="1y")
print(f"\nMethod 2 - yf.download():")
print(f"  Type: {type(data2)}")
print(f"  Shape: {data2.shape}")
print(f"  Columns: {data2.columns.tolist()}")
print(f"  Index: {type(data2.index)}")

# Check if columns are MultiIndex
if hasattr(data2.columns, 'nlevels'):
    print(f"  Column levels: {data2.columns.nlevels}")
    if data2.columns.nlevels > 1:
        print(f"  MultiIndex columns detected!")
        print(f"  Level 0: {data2.columns.get_level_values(0).tolist()}")
        print(f"  Level 1: {data2.columns.get_level_values(1).tolist()}")

# Test rolling operations on both
print(f"\nTesting rolling operations:")
try:
    std1 = data1['Close'].rolling(window=20).std()
    print(f"Method 1 std type: {type(std1)}")
except Exception as e:
    print(f"Method 1 error: {e}")

try:
    std2 = data2['Close'].rolling(window=20).std()
    print(f"Method 2 std type: {type(std2)}")
except Exception as e:
    print(f"Method 2 error: {e}")
