# 🤖 Automatic ML Training & Monitoring Guide

## 📋 **Overview**

This guide covers the comprehensive automatic training and performance monitoring system for the Stock Prediction Service. The system now supports **13 popular stock symbols** with intelligent retraining based on model age and performance metrics.

## 🎯 **Supported Stock Symbols**

The system now supports the following **13 symbols**:

| Symbol | Company | Sector |
|--------|---------|---------|
| **NVDA** | NVIDIA Corporation | Technology (Semiconductors) |
| **TSLA** | Tesla, Inc. | Automotive (Electric Vehicles) |
| **AAPL** | Apple Inc. | Technology (Consumer Electronics) |
| **MSFT** | Microsoft Corporation | Technology (Software) |
| **GOOGL** | Alphabet Inc. | Technology (Internet Services) |
| **AMZN** | Amazon.com Inc. | Consumer Discretionary (E-commerce) |
| **AUR** | Aurora Innovation | Technology (Autonomous Vehicles) |
| **PLTR** | Palantir Technologies | Technology (Data Analytics) |
| **SMCI** | Super Micro Computer | Technology (Hardware) |
| **TSM** | Taiwan Semiconductor | Technology (Semiconductors) |
| **MP** | MP Materials Corp | Materials (Rare Earth Elements) |
| **SMR** | NuScale Power | Energy (Nuclear) |
| **SPY** | SPDR S&P 500 ETF | ETF (Market Index) |

## 🚀 **Quick Start**

### 1. **Setup Automatic Training**
```bash
# Setup cron jobs for automatic training and monitoring
./setup_cron_jobs.sh

# Or setup systemd services (alternative)
./setup_cron_jobs.sh --systemd
```

### 2. **Train Models for All Symbols**
```bash
# Train all supported symbols
./manage_ml_models.sh train-all

# Or train specific symbols
./manage_ml_models.sh train NVDA TSLA AAPL MSFT
```

### 3. **Start Performance Monitoring**
```bash
# One-time performance check
./monitor_performance.sh

# Continuous monitoring (daemon mode)
./monitor_performance.sh --continuous
```

## 📅 **Automatic Schedules**

### **Default Cron Schedule**
- **🔄 Weekly Training**: Sundays at 2:00 AM
- **📊 Performance Monitoring**: Every 6 hours (6 AM, 12 PM, 6 PM) on weekdays
- **🔄 Monthly Comprehensive Training**: 1st of each month at 1:00 AM
- **🧹 Daily Cleanup**: Every day at 3:00 AM

### **Schedule Details**
```bash
# Weekly training (all symbols that need it)
0 2 * * 0 cd /path/to/project && ./enhanced_training.sh

# Performance monitoring (weekdays only)
0 6,12,18 * * 1-5 cd /path/to/project && ./monitor_performance.sh

# Monthly comprehensive training (force all symbols)
0 1 1 * * cd /path/to/project && ./enhanced_training.sh --force

# Daily cleanup (remove old files)
0 3 * * * cd /path/to/project && ./manage_ml_models.sh clean
```

## 🧠 **Intelligent Training Logic**

### **When Models Are Retrained**

#### **1. Age-Based Retraining**
- Models older than **7 days** are automatically retrained
- Monthly comprehensive retraining regardless of age

#### **2. Performance-Based Retraining**
- **Direction Accuracy** drops below 45%
- **MAPE** (Mean Absolute Percentage Error) exceeds 5%
- **Confidence Scores** consistently below 60%
- **API Response Failures** for specific symbols

#### **3. Market Event-Based Retraining**
- After major market volatility
- Following earnings seasons
- When new market data significantly changes patterns

### **Training Prioritization**
1. **High Priority**: NVDA, TSLA, AAPL (most volatile/popular)
2. **Medium Priority**: MSFT, GOOGL, AMZN (stable large caps)
3. **Low Priority**: ETFs and specialized stocks (SPY, SMR, etc.)

## 🛠️ **Management Commands**

### **Enhanced Management Script**
```bash
# Basic commands
./manage_ml_models.sh train [symbols...]     # Train specific symbols
./manage_ml_models.sh evaluate [symbols...]  # Evaluate performance
./manage_ml_models.sh status                 # Show model status
./manage_ml_models.sh test-symbol NVDA       # Test API for symbol

# New enhanced commands
./manage_ml_models.sh train-all              # Train all 13 symbols
./manage_ml_models.sh quick-train [symbols]  # Fast training (10 epochs)
./manage_ml_models.sh performance            # Run performance check
./manage_ml_models.sh auto-train [options]   # Intelligent auto-training
./manage_ml_models.sh backup                 # Backup current models
./manage_ml_models.sh clean                  # Clean old files
```

### **Enhanced Training Script**
```bash
# Automatic training with intelligence
./enhanced_training.sh                       # Smart training (age/performance based)
./enhanced_training.sh --force               # Force train all symbols
./enhanced_training.sh --skip-market-hours   # Skip market hours check

# Examples
./enhanced_training.sh --force               # Monthly comprehensive training
./enhanced_training.sh                       # Weekly smart training
```

### **Performance Monitoring**
```bash
# Performance monitoring options
./monitor_performance.sh                     # One-time check
./monitor_performance.sh --continuous        # Daemon mode
./monitor_performance.sh --report            # Generate report only
./monitor_performance.sh --symbols "NVDA TSLA AAPL"  # Monitor specific symbols
```

## 📊 **Performance Thresholds**

### **Retraining Triggers**
| Metric | Threshold | Action |
|--------|-----------|---------|
| Model Age | > 7 days | Automatic retraining |
| Direction Accuracy | < 45% | Performance-based retraining |
| MAPE | > 5% | Performance-based retraining |
| Confidence Score | < 60% | Performance-based retraining |
| API Failures | > 3 consecutive | Emergency retraining |

### **System Health Monitoring**
| Resource | Warning | Critical |
|----------|---------|----------|
| CPU Usage | > 80% | > 95% |
| Memory Usage | > 80% | > 95% |
| Disk Usage | > 80% | > 90% |
| Response Time | > 5s | > 10s |

## 📈 **Expected Performance**

### **Model Performance by Symbol Type**
| Symbol Type | Expected Accuracy | Expected MAPE | Training Time |
|-------------|------------------|---------------|---------------|
| **Tech Stocks** (NVDA, TSLA) | 45-55% | 2-4% | 30-45s |
| **Large Caps** (AAPL, MSFT) | 50-60% | 1.5-3% | 25-35s |
| **ETFs** (SPY) | 55-65% | 1-2% | 20-30s |
| **Specialized** (AUR, PLTR) | 40-50% | 3-6% | 35-50s |

### **System Performance**
- **API Response Time**: 2-4 seconds per prediction
- **Training Time**: 20-50 seconds per symbol
- **Memory Usage**: ~500MB during training, ~200MB idle
- **Disk Usage**: ~2MB per trained model

## 🔧 **Configuration**

### **Environment Variables**
```bash
# ML Configuration
ML_PYTHON_SCRIPT=scripts/ml/ensemble_predict.py
ML_MODEL_VERSION=v3.3.0
ML_PREDICTION_TTL=5m

# Training Configuration
ML_EPOCHS=50                    # Default training epochs
ML_BATCH_SIZE=32               # Training batch size
ML_SEQUENCE_LENGTH=60          # LSTM sequence length
ML_VALIDATION_SPLIT=0.2        # Validation data split

# Performance Thresholds
MIN_ACCURACY=45.0              # Minimum direction accuracy
MAX_MAPE=5.0                   # Maximum MAPE error
MIN_CONFIDENCE=60.0            # Minimum confidence score
MAX_MODEL_AGE_DAYS=7           # Maximum model age before retraining
```

### **ML Configuration File**
```json
{
    "model_version": "v3.3.0",
    "supported_symbols": ["NVDA", "TSLA", "AAPL", "MSFT", "GOOGL", "AMZN", "AUR", "PLTR", "SMCI", "TSM", "MP", "SMR", "SPY"],
    "models": {
        "lstm": {
            "enabled": true,
            "sequence_length": 60,
            "features": ["close", "volume", "technical_indicators"]
        },
        "ensemble": {
            "enabled": true,
            "methods": ["lstm", "enhanced", "sklearn"],
            "dynamic_weighting": true
        }
    },
    "training": {
        "default_epochs": 50,
        "batch_size": 32,
        "validation_split": 0.2,
        "early_stopping": true
    },
    "monitoring": {
        "min_accuracy": 45.0,
        "max_mape": 5.0,
        "min_confidence": 60.0,
        "max_model_age_days": 7
    }
}
```

## 📁 **File Structure**

```
stock_prediction/
├── enhanced_training.sh           # Intelligent automatic training
├── monitor_performance.sh         # Performance monitoring
├── setup_cron_jobs.sh            # Cron job setup
├── manage_ml_models.sh            # Enhanced model management
├── dashboard.sh                   # Monitoring dashboard
├── persistent_data/
│   ├── ml_models/                 # Trained model files
│   │   ├── nvda_lstm_model.h5     # NVIDIA model
│   │   ├── tsla_lstm_model.h5     # Tesla model
│   │   ├── aapl_lstm_model.h5     # Apple model
│   │   ├── msft_lstm_model.h5     # Microsoft model
│   │   ├── googl_lstm_model.h5    # Google model
│   │   ├── amzn_lstm_model.h5     # Amazon model
│   │   ├── aur_lstm_model.h5      # Aurora model
│   │   ├── pltr_lstm_model.h5     # Palantir model
│   │   ├── smci_lstm_model.h5     # Super Micro model
│   │   ├── tsm_lstm_model.h5      # Taiwan Semi model
│   │   ├── mp_lstm_model.h5       # MP Materials model
│   │   ├── smr_lstm_model.h5      # NuScale model
│   │   └── spy_lstm_model.h5      # S&P 500 ETF model
│   └── ml_config.json             # ML configuration
├── logs/
│   ├── training/                  # Training logs
│   ├── monitoring/                # Performance monitoring logs
│   └── cron/                      # Cron job logs
└── evaluation_results/            # Model evaluation reports
```

## 🚨 **Monitoring & Alerts**

### **Log Files**
- **Training Logs**: `logs/training/training.log`
- **Performance Logs**: `logs/monitoring/monitoring.log`
- **Cron Logs**: `logs/training/cron.log`, `logs/monitoring/cron.log`
- **Performance History**: `logs/monitoring/performance_history.jsonl`

### **Dashboard**
```bash
# View monitoring dashboard
./dashboard.sh

# Example output:
=== ML Stock Prediction Dashboard ===
Generated: 2025-08-13 12:00:00

=== Model Status ===
✅ NVDA: 1.9MB (Aug 13 11:35)
✅ TSLA: 1.9MB (Aug 13 11:36)
✅ AAPL: 1.9MB (Aug 13 11:36)
❌ MSFT: Not trained
...

=== Recent Performance ===
2025-08-13T11:38:37+08:00 NVDA: 0.72 confidence
2025-08-13T11:38:53+08:00 TSLA: 0.70 confidence
2025-08-13T11:38:55+08:00 AAPL: 0.63 confidence
```

## 🔄 **Backup & Recovery**

### **Automatic Backups**
- Models are automatically backed up before retraining
- Backup location: `persistent_data/ml_models/backup_YYYYMMDD_HHMMSS/`
- Old backups are cleaned up after 30 days

### **Manual Backup**
```bash
# Create manual backup
./manage_ml_models.sh backup

# Restore from backup (manual process)
cp persistent_data/ml_models/backup_20250813_120000/* persistent_data/ml_models/
```

## 🚀 **Production Deployment**

### **1. Initial Setup**
```bash
# 1. Setup automatic training and monitoring
./setup_cron_jobs.sh

# 2. Train initial models for all symbols
./manage_ml_models.sh train-all

# 3. Verify setup
./dashboard.sh
```

### **2. Monitoring Setup**
```bash
# Setup continuous monitoring (optional)
nohup ./monitor_performance.sh --continuous > logs/monitoring/daemon.log 2>&1 &

# Or rely on cron jobs for periodic monitoring
```

### **3. Health Checks**
```bash
# Daily health check script
#!/bin/bash
echo "=== Daily Health Check ===" >> logs/health_check.log
./manage_ml_models.sh status >> logs/health_check.log
./monitor_performance.sh --report >> logs/health_check.log
echo "===========================================" >> logs/health_check.log
```

## 🎯 **Best Practices**

### **Training Schedule**
1. **Weekly Training**: Let the system automatically retrain models older than 7 days
2. **Monthly Comprehensive**: Force retrain all models monthly for consistency
3. **Performance-Based**: Allow automatic retraining when performance degrades

### **Monitoring**
1. **Regular Checks**: Monitor performance every 6 hours during market days
2. **Alert Thresholds**: Set up notifications for critical performance degradation
3. **Resource Monitoring**: Keep an eye on system resources during training

### **Maintenance**
1. **Log Rotation**: Automatically clean old logs to save disk space
2. **Model Cleanup**: Remove very old model files (30+ days)
3. **Backup Management**: Keep recent backups, clean old ones

## 🔧 **Troubleshooting**

### **Common Issues**

#### **Training Failures**
```bash
# Check training logs
tail -f logs/training/training.log

# Test individual symbol
./manage_ml_models.sh train NVDA

# Check Python environment
source venv/bin/activate && python3 -c "import tensorflow; print('OK')"
```

#### **Performance Issues**
```bash
# Check API health
curl http://localhost:8081/api/v1/health

# Test specific symbol
./manage_ml_models.sh test-symbol NVDA

# Check system resources
./monitor_performance.sh --report
```

#### **Cron Job Issues**
```bash
# Check cron logs
tail -f logs/training/cron.log
tail -f logs/monitoring/cron.log

# Verify cron jobs are installed
crontab -l | grep enhanced_training

# Test cron job manually
cd /path/to/project && ./enhanced_training.sh
```

## 📞 **Support**

For issues or questions:
1. Check the logs in `logs/` directory
2. Run `./dashboard.sh` for current status
3. Test individual components manually
4. Review this guide for configuration options

---

**🎉 Your ML system now supports 13 popular stock symbols with intelligent automatic training and comprehensive performance monitoring!**
