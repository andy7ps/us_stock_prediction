# 📈 US Stock Prediction Service v3.3.1 - Persistent Data Edition

[![Go Version](https://img.shields.io/badge/Go-1.23+-blue.svg)](https://golang.org)
[![Python Version](https://img.shields.io/badge/Python-3.11+-blue.svg)](https://python.org)
[![Angular Version](https://img.shields.io/badge/Angular-20+-red.svg)](https://angular.io)
[![Bootstrap Version](https://img.shields.io/badge/Bootstrap-5.3.3-purple.svg)](https://getbootstrap.com)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://docker.com)
[![Persistent Data](https://img.shields.io/badge/Persistent_Data-Required-critical.svg)](#persistent-data)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

> **🚨 CRITICAL UPDATE v3.3.1: ALL deployments now require persistent data structure. This ensures zero data loss and complete system persistence.**

## 🎯 **What This Service Does**

The US Stock Prediction Service is a **production-ready, full-stack enterprise-grade application** with **mandatory persistent data integration** that provides:

- **🗄️ Complete Data Persistence**: ALL data stored in `persistent_data/` directory
- **🧠 Persistent ML Models**: Trained models never lost across deployments
- **📊 Persistent Monitoring**: Metrics and logs maintained permanently
- **🔄 Zero Data Loss**: Survive container restarts, rebuilds, and migrations
- **💾 Enterprise Backup**: Complete system backup and recovery

---

## 🚨 **MANDATORY: Persistent Data Structure**

### **⚠️ CRITICAL REQUIREMENT**

**ALL Docker deployments and ML training MUST use the persistent data structure:**

```
persistent_data/                    # 🔥 NEVER DELETE THIS DIRECTORY
├── ml_models/                     # 🧠 Your trained ML models
├── ml_cache/                      # 🔄 ML prediction cache
├── scalers/                       # 📊 Data preprocessing scalers
├── stock_data/                    # 📈 Stock market data
├── logs/                          # 📝 ALL application logs
├── config/                        # ⚙️ Configuration files
├── backups/                       # 💾 System backups
├── redis/                         # 🗄️ Redis persistent data
├── prometheus/                    # 📊 Prometheus metrics
├── grafana/                       # 📈 Grafana dashboards
└── frontend/                      # 🎨 Frontend logs/cache
```

---

## 🚀 **Quick Start with Persistent Data (90 seconds)**

```bash
# 1. Clone the repository
git clone https://github.com/andy7ps/us_stock_prediction.git
cd us_stock_prediction

# 2. MANDATORY: Setup persistent data structure
./setup_persistent_data.sh

# 3. Deploy with persistent data integration
docker-compose -f docker-compose-persistent.yml up -d

# 4. Verify all services are using persistent data
curl http://localhost:8081/api/v1/health
curl http://localhost:8080/  # Frontend
curl http://localhost:3000/api/health  # Grafana
```

**🎉 Your system is now running with complete data persistence!**

---

## 🐳 **Docker Deployment - Persistent Data Required**

### **ONLY Use Persistent Configuration**

```bash
# ✅ CORRECT: Use persistent data configuration
docker-compose -f docker-compose-persistent.yml up -d

# ❌ WRONG: Don't use non-persistent configurations
# docker-compose up -d  # This will lose your data!
```

### **Persistent Volume Mounts**

**Every service mounts from `persistent_data/`:**

- **Backend**: `./persistent_data:/app/persistent_data`
- **Redis**: `./persistent_data/redis:/data`
- **Prometheus**: `./persistent_data/prometheus:/prometheus`
- **Grafana**: `./persistent_data/grafana:/var/lib/grafana`
- **Frontend**: `./persistent_data/frontend/logs:/var/log/nginx`

---

## 🧠 **ML Model Training with Persistence**

### **All Models Stored in persistent_data/**

```bash
# Train models (automatically uses persistent storage)
./manage_ml_models.sh train NVDA TSLA AAPL MSFT GOOGL

# Models saved to: persistent_data/ml_models/
# Scalers saved to: persistent_data/scalers/
# Cache saved to: persistent_data/ml_cache/
```

### **Supported Stock Symbols** *(All models persist)*
- **Tech Giants**: NVDA, TSLA, AAPL, MSFT, GOOGL, AMZN
- **Growth Stocks**: AUR, PLTR, SMCI
- **International**: TSM (Taiwan Semiconductor)
- **Materials**: MP (MP Materials)
- **Energy**: SMR (NuScale Power)
- **ETF**: SPY (S&P 500 ETF)

---

## 📊 **Monitoring with Persistent Data**

### **All Metrics and Logs Persist**

- **Prometheus**: Metrics stored in `persistent_data/prometheus/`
- **Grafana**: Dashboards in `persistent_data/grafana/`
- **Application Logs**: `persistent_data/logs/application/`
- **Service Logs**: `persistent_data/logs/[service]/`

### **Access Monitoring**
- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Logs**: `tail -f persistent_data/logs/application/stock-prediction.log`

---

## 💾 **Backup and Recovery**

### **Complete System Backup**

```bash
# Backup entire system (includes all models, data, configs)
./persistent_data/backup_data.sh

# Restore from backup
./persistent_data/restore_data.sh backup_20250813.tar.gz

# Monitor data usage
./persistent_data/monitor_data.sh
```

### **What Gets Backed Up**
- ✅ All trained ML models
- ✅ All cached predictions
- ✅ All configuration files
- ✅ All logs and metrics
- ✅ All Grafana dashboards
- ✅ All Prometheus data

---

## 🔧 **Environment Variables - Persistent Paths**

### **All Paths Point to persistent_data/**

```bash
# ML Configuration
ML_MODEL_PATH=/app/persistent_data/ml_models/nvda_lstm_model
STOCK_DATA_CACHE_PATH=/app/persistent_data/stock_data/cache
ML_CACHE_PATH=/app/persistent_data/ml_cache
SCALERS_PATH=/app/persistent_data/scalers

# Logging
LOG_PATH=/app/persistent_data/logs
LOG_FILE=/app/persistent_data/logs/stock-prediction.log

# Data Storage
BACKUP_PATH=/app/persistent_data/backups
CONFIG_PATH=/app/persistent_data/config
```

---

## 🧪 **Testing Persistent Data**

### **Verify Data Persistence**

```bash
# 1. Make a prediction (creates cache)
curl http://localhost:8081/api/v1/predict/NVDA

# 2. Restart all containers
docker-compose -f docker-compose-persistent.yml restart

# 3. Verify data persisted
curl http://localhost:8081/api/v1/predict/NVDA  # Should be faster (cached)
ls persistent_data/ml_cache/  # Should contain cache files
```

---

## ⚠️ **Critical Warnings**

### **DO NOT:**
- ❌ **Delete persistent_data/**: You'll lose all trained models
- ❌ **Use non-persistent docker-compose**: Data will be lost
- ❌ **Skip setup_persistent_data.sh**: Directory structure incomplete
- ❌ **Ignore backup**: No recovery without backups

### **ALWAYS:**
- ✅ **Run setup_persistent_data.sh** before deployment
- ✅ **Use docker-compose-persistent.yml** for deployments
- ✅ **Backup persistent_data/** regularly
- ✅ **Monitor disk usage** in persistent_data/

---

## 📚 **Documentation**

### **Persistent Data Documentation**
- **[RELEASE_NOTES_PERSISTENT_DATA.md](RELEASE_NOTES_PERSISTENT_DATA.md)** - Complete persistent data guide
- **[persistent_data/README.md](persistent_data/README.md)** - Directory structure guide
- **[PERSISTENT_STORAGE_GUIDE.md](PERSISTENT_STORAGE_GUIDE.md)** - 50+ page storage guide

### **Setup and Deployment**
- **[setup_persistent_data.sh](setup_persistent_data.sh)** - Automated setup script
- **[docker-compose-persistent.yml](docker-compose-persistent.yml)** - Persistent deployment config

---

## 🎯 **Key Benefits of Persistent Data**

### **Data Security**
- ✅ **Zero Data Loss**: Models survive container restarts
- ✅ **Complete Backup**: Single directory backup
- ✅ **Easy Migration**: Copy persistent_data folder
- ✅ **Audit Trail**: Complete log history

### **Operational Benefits**
- ✅ **Fast Recovery**: Instant restore from backup
- ✅ **Easy Debugging**: All logs in one place
- ✅ **Performance**: Persistent cache improves speed
- ✅ **Monitoring**: Historical metrics maintained

### **Development Benefits**
- ✅ **Consistent Environment**: Same data everywhere
- ✅ **Easy Testing**: Persistent test data
- ✅ **Team Collaboration**: Shared data structure
- ✅ **Version Control**: Track model versions

---

## 🚀 **Production Deployment Checklist**

- [ ] **Run setup_persistent_data.sh**
- [ ] **Verify persistent_data/ structure exists**
- [ ] **Use docker-compose-persistent.yml**
- [ ] **Test data persistence after restart**
- [ ] **Setup backup schedule**
- [ ] **Monitor disk usage**
- [ ] **Verify all logs writing to persistent_data/logs/**

---

## 🎉 **Summary**

**v3.3.1 introduces mandatory persistent data integration ensuring:**

- **🔒 Data Security**: Never lose trained models or configurations
- **📊 Complete Monitoring**: All metrics and logs persist
- **💾 Easy Backup**: Single directory contains everything
- **🚀 Production Ready**: Enterprise-grade data persistence
- **🔄 Zero Downtime**: Survive any container restart or rebuild

**🎯 Remember: ALL deployments must use persistent_data structure. This is now a fundamental system requirement for data integrity and operational excellence.**

---

**Made with ❤️ and persistent data by [andy7ps](https://github.com/andy7ps)**

**Happy Trading with Persistent Data! 📈💾**
