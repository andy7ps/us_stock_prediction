#!/bin/bash

# 🚀 Quick ML Environment Setup
# Fast setup using requirements file

set -e

ML_ENV_DIR="ml_env"
REQUIREMENTS_FILE="requirements_ml_env_simple.txt"

echo "🚀 Quick ML Environment Setup"
echo "============================="

# Check if requirements file exists
if [ ! -f "$REQUIREMENTS_FILE" ]; then
    echo "❌ Requirements file not found: $REQUIREMENTS_FILE"
    echo "💡 Use setup_ml_env.sh for complete setup"
    exit 1
fi

# Remove existing environment
if [ -d "$ML_ENV_DIR" ]; then
    echo "🗑️ Removing existing ml_env..."
    rm -rf "$ML_ENV_DIR"
fi

# Create virtual environment
echo "🐍 Creating virtual environment..."
python3 -m venv "$ML_ENV_DIR"

# Activate and install packages
echo "📦 Installing packages from requirements..."
source "$ML_ENV_DIR/bin/activate"

# Upgrade pip first
pip install --upgrade pip

# Install from requirements
pip install -r "$REQUIREMENTS_FILE"

# Verify installation
echo "🔍 Verifying installation..."
python3 -c "
import tensorflow as tf
import yfinance as yf
import sklearn
import pandas as pd
import numpy as np
print('✅ All packages installed successfully!')
print(f'TensorFlow: {tf.__version__}')
print(f'Pandas: {pd.__version__}')
print(f'NumPy: {np.__version__}')
"

deactivate

echo ""
echo "🎉 Quick setup complete!"
echo "📁 Environment: $ML_ENV_DIR"
echo "🚀 Usage: source $ML_ENV_DIR/bin/activate"
