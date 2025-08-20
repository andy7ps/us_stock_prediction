# 🐍 ML Environment Deployment Guide

**Complete guide for setting up ml_env on other machines**

## 🎯 **Overview**

This guide provides multiple methods to recreate the exact ML environment (`ml_env`) on other machines, ensuring identical training capabilities across different systems.

## 📋 **Prerequisites**

### **System Requirements:**
- **Python 3.11+** (recommended: 3.11 or 3.12)
- **pip** (Python package manager)
- **python3-venv** (virtual environment support)
- **3GB+ free disk space**
- **Internet connection** (for package downloads)

### **Platform Support:**
- ✅ **Linux** (Ubuntu, CentOS, RHEL, etc.)
- ✅ **macOS** (Intel and Apple Silicon)
- ✅ **Windows** (with WSL recommended)

## 🚀 **Setup Methods**

### **Method 1: Comprehensive Setup Script (Recommended)**

**Features:**
- Complete system checks and validation
- Detailed logging and error handling
- Package verification and testing
- Helper scripts creation

```bash
# Download and run comprehensive setup
./setup_ml_env.sh

# Or with specific command
./setup_ml_env.sh setup
```

**What it does:**
1. ✅ Checks system requirements (Python, pip, venv)
2. ✅ Verifies available disk space (3GB+)
3. ✅ Creates clean virtual environment
4. ✅ Installs all ML packages with specific versions
5. ✅ Verifies installation with import tests
6. ✅ Creates activation helper scripts
7. ✅ Generates requirements file for future use

### **Method 2: Quick Setup with Requirements**

**Features:**
- Fast installation using requirements file
- Minimal interaction required
- Good for automated deployments

```bash
# Quick setup using requirements file
./quick_setup_ml_env.sh
```

**Requirements file used:**
```
tensorflow==2.15.0
keras==2.15.0
numpy==1.24.3
pandas==2.0.3
scikit-learn==1.3.0
yfinance==0.2.18
# ... and more
```

### **Method 3: Manual Setup**

**For custom installations or troubleshooting:**

```bash
# Create virtual environment
python3 -m venv ml_env

# Activate environment
source ml_env/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install packages
pip install -r requirements_ml_env_simple.txt

# Or install individually
pip install tensorflow==2.15.0 yfinance==0.2.18 scikit-learn==1.3.0
```

## 📁 **Files Provided**

### **Setup Scripts:**
- **`setup_ml_env.sh`** - Comprehensive setup with full validation
- **`quick_setup_ml_env.sh`** - Fast setup using requirements
- **`activate_ml_env.sh`** - Helper for environment activation

### **Requirements Files:**
- **`requirements_ml_env_simple.txt`** - Essential packages only
- **`requirements_ml_env_exact.txt`** - Exact package versions from working environment

### **Documentation:**
- **`ML_ENV_DEPLOYMENT_GUIDE.md`** - This guide
- **Setup logs** - Generated during installation for troubleshooting

## 🔧 **Usage Instructions**

### **After Setup:**

```bash
# Method 1: Direct activation
source ml_env/bin/activate

# Method 2: Using helper script
./activate_ml_env.sh

# Method 3: Direct script execution (no activation needed)
./ml_env/bin/python3 scripts/ml/train_nvda_model.py
```

### **Training Scripts:**

```bash
# Train individual models
./ml_env/bin/python3 scripts/ml/train_nvda_model.py
./ml_env/bin/python3 scripts/ml/train_tsla_model.py
./ml_env/bin/python3 scripts/ml/train_amzn_model.py

# Train multiple models
./scripts/train_symbol_specific_models.sh
```

### **Deactivation:**

```bash
# When using activated environment
deactivate
```

## 🔍 **Verification**

### **Test Installation:**

```bash
# Verify packages
./setup_ml_env.sh verify

# Manual verification
source ml_env/bin/activate
python3 -c "
import tensorflow as tf
import yfinance as yf
import sklearn
print('✅ All packages working!')
print(f'TensorFlow: {tf.__version__}')
"
```

### **Test Training:**

```bash
# Quick training test
./ml_env/bin/python3 -c "
import yfinance as yf
import pandas as pd
import numpy as np
from sklearn.preprocessing import MinMaxScaler
print('✅ Training environment ready!')
"
```

## 🌍 **Platform-Specific Instructions**

### **Ubuntu/Debian:**

```bash
# Install prerequisites
sudo apt-get update
sudo apt-get install python3 python3-pip python3-venv

# Run setup
./setup_ml_env.sh
```

### **CentOS/RHEL:**

```bash
# Install prerequisites
sudo yum install python3 python3-pip python3-venv

# Run setup
./setup_ml_env.sh
```

### **macOS:**

```bash
# Install Python (if not already installed)
brew install python3

# Run setup
./setup_ml_env.sh
```

### **Windows (WSL):**

```bash
# In WSL terminal
sudo apt-get update
sudo apt-get install python3 python3-pip python3-venv

# Run setup
./setup_ml_env.sh
```

## 🐳 **Docker Alternative**

**Note:** For production deployments, Docker is recommended over virtual environments:

```bash
# Docker provides better isolation and reproducibility
docker-compose up -d
docker-compose exec stock-prediction python3 scripts/ml/train_nvda_model.py
```

**Advantages of Docker:**
- ✅ Complete system isolation
- ✅ No virtual environment needed
- ✅ Identical across all platforms
- ✅ Easier deployment and scaling

## 🔧 **Troubleshooting**

### **Common Issues:**

**1. Python Version Mismatch:**
```bash
# Check Python version
python3 --version

# Should be 3.11+ for best compatibility
```

**2. Virtual Environment Creation Fails:**
```bash
# Install venv module
sudo apt-get install python3-venv  # Ubuntu/Debian
sudo yum install python3-venv      # CentOS/RHEL
```

**3. Package Installation Fails:**
```bash
# Upgrade pip first
source ml_env/bin/activate
pip install --upgrade pip

# Install packages one by one to identify issues
pip install tensorflow==2.15.0
```

**4. TensorFlow Issues:**
```bash
# For older CPUs, use CPU-only version
pip install tensorflow-cpu==2.15.0
```

**5. Memory Issues During Installation:**
```bash
# Install packages with no cache
pip install --no-cache-dir tensorflow==2.15.0
```

### **Getting Help:**

```bash
# View setup log
cat setup_ml_env.log

# Clean and retry
./setup_ml_env.sh clean
./setup_ml_env.sh setup

# Check system resources
df -h          # Disk space
free -h        # Memory
python3 --version  # Python version
```

## 📊 **Environment Specifications**

### **Package Versions (Tested):**
- **TensorFlow:** 2.15.0
- **Keras:** 2.15.0
- **NumPy:** 1.24.3
- **Pandas:** 2.0.3
- **Scikit-learn:** 1.3.0
- **yfinance:** 0.2.18

### **Environment Size:**
- **Disk Space:** ~2.4GB
- **Installation Time:** 10-15 minutes
- **Memory Usage:** ~500MB during training

### **Compatibility:**
- ✅ **Phase 2 Tested:** All 5 symbols trained successfully
- ✅ **Cross-Platform:** Linux, macOS, Windows (WSL)
- ✅ **Python 3.11+:** Recommended version
- ✅ **CPU/GPU:** Works with both (GPU optional)

## 🎯 **Best Practices**

### **For Development:**
1. **Use virtual environment** for local development
2. **Test on similar hardware** as production
3. **Keep requirements files updated**
4. **Document any custom modifications**

### **For Production:**
1. **Use Docker containers** for deployment
2. **Implement automated testing** of environment
3. **Monitor resource usage** during training
4. **Backup trained models** regularly

### **For Team Deployment:**
1. **Share setup scripts** with team members
2. **Document platform-specific requirements**
3. **Test on multiple environments** before deployment
4. **Maintain version consistency** across team

## 🚀 **Quick Start Checklist**

- [ ] **Download setup scripts** to target machine
- [ ] **Check Python 3.11+** is installed
- [ ] **Verify 3GB+ disk space** available
- [ ] **Run setup script:** `./setup_ml_env.sh`
- [ ] **Test installation:** `./setup_ml_env.sh verify`
- [ ] **Copy training scripts** to `scripts/ml/`
- [ ] **Run test training:** `./ml_env/bin/python3 scripts/ml/train_nvda_model.py`
- [ ] **Verify model output** in `persistent_data/ml_models/`

## 🎉 **Success Indicators**

✅ **Setup Complete When:**
- Virtual environment created in `ml_env/`
- All packages import without errors
- Training scripts execute successfully
- Models save to `persistent_data/ml_models/`
- Helper scripts created and functional

**Your ML environment is ready for Phase 2+ training! 🏆**

---

## 📞 **Support**

If you encounter issues:
1. **Check setup log:** `setup_ml_env.log`
2. **Verify system requirements** match prerequisites
3. **Try Docker alternative** for complex environments
4. **Review troubleshooting section** above

**The setup scripts provide comprehensive error handling and logging to help diagnose any issues! 🔧**
