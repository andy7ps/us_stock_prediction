# 📋 Persistent Data Integration - Summary for Future Reference

## 🎯 **CRITICAL SYSTEM REQUIREMENT**

**As of v3.4.0, ALL deployments and ML training MUST use the `persistent_data/` directory structure. This is mandatory for data integrity and system reliability.**

---

## 🔥 **Key Requirements (NEVER FORGET)**

### **1. Directory Structure - MANDATORY**
```
persistent_data/                    # 🚨 NEVER DELETE THIS
├── ml_models/                     # All trained ML models
├── ml_cache/                      # ML prediction cache  
├── scalers/                       # Data preprocessing scalers
├── stock_data/                    # Stock market data
├── logs/                          # ALL application logs
├── config/                        # Configuration files
├── backups/                       # System backups
├── redis/                         # Redis persistent data
├── prometheus/                    # Prometheus metrics
├── grafana/                       # Grafana dashboards
└── frontend/                      # Frontend logs/cache
```

### **2. Docker Deployment - MANDATORY**
```bash
# ✅ ALWAYS USE THIS
docker-compose -f docker-compose-persistent.yml up -d

# ❌ NEVER USE THESE (will lose data)
# docker-compose up -d
# docker-compose -f docker-compose-complete.yml up -d
```

### **3. Setup Before Deployment - MANDATORY**
```bash
# MUST run before any deployment
./setup_persistent_data.sh
```

### **4. Environment Variables - MANDATORY**
```bash
# ALL paths MUST point to persistent_data
ML_MODEL_PATH=/app/persistent_data/ml_models/
STOCK_DATA_CACHE_PATH=/app/persistent_data/stock_data/cache
LOG_PATH=/app/persistent_data/logs
```

---

## 🚀 **Deployment Process**

### **Step-by-Step (ALWAYS FOLLOW)**

1. **Setup Structure**:
   ```bash
   ./setup_persistent_data.sh
   ```

2. **Deploy System**:
   ```bash
   ./deploy_with_persistent_data.sh
   # OR manually:
   docker-compose -f docker-compose-persistent.yml up -d
   ```

3. **Verify Persistence**:
   ```bash
   # Check data mounting
   docker exec stock-prediction ls /app/persistent_data/
   
   # Test restart persistence
   docker-compose -f docker-compose-persistent.yml restart
   curl http://localhost:8081/api/v1/health  # Should still work
   ```

---

## 🧠 **ML Training Requirements**

### **Model Storage - MANDATORY**
```python
# ✅ CORRECT: Save to persistent_data
model_path = "/app/persistent_data/ml_models/"
model.save(f"{model_path}{symbol}_lstm_model.h5")

# ✅ CORRECT: Save scalers to persistent_data  
scaler_path = "/app/persistent_data/scalers/"
joblib.dump(scaler, f"{scaler_path}{symbol}_scaler.pkl")
```

### **Training Commands**
```bash
# All training automatically uses persistent_data
./manage_ml_models.sh train NVDA TSLA AAPL
./enhanced_training.sh
```

---

## 📊 **Volume Mounts - MANDATORY**

### **Backend Service**
```yaml
volumes:
  - ./persistent_data:/app/persistent_data
  - ./persistent_data/logs:/app/logs
  - ./persistent_data/config:/app/config
```

### **Redis Service**
```yaml
volumes:
  - ./persistent_data/redis:/data
```

### **Prometheus Service**
```yaml
volumes:
  - ./persistent_data/prometheus:/prometheus
  - ./persistent_data/logs/prometheus:/var/log/prometheus
```

### **Grafana Service**
```yaml
volumes:
  - ./persistent_data/grafana:/var/lib/grafana
  - ./persistent_data/logs/grafana:/var/log/grafana
```

---

## 💾 **Backup and Recovery**

### **Complete System Backup**
```bash
# Backup everything (models, data, configs, logs)
./persistent_data/backup_data.sh

# Restore from backup
./persistent_data/restore_data.sh backup_file.tar.gz
```

### **What Gets Backed Up**
- ✅ All trained ML models (.h5, .pkl files)
- ✅ All cached predictions and data
- ✅ All configuration files
- ✅ All logs and metrics
- ✅ All Grafana dashboards
- ✅ All Prometheus historical data

---

## 🔒 **Critical Warnings**

### **NEVER DO THESE:**
- ❌ Delete `persistent_data/` directory
- ❌ Use non-persistent docker-compose files
- ❌ Skip `setup_persistent_data.sh`
- ❌ Save models outside persistent_data
- ❌ Ignore backup procedures

### **ALWAYS DO THESE:**
- ✅ Use `docker-compose-persistent.yml`
- ✅ Run `setup_persistent_data.sh` first
- ✅ Save all data to persistent_data
- ✅ Regular backups
- ✅ Monitor disk usage

---

## 🧪 **Testing Persistence**

### **Verification Steps**
```bash
# 1. Deploy system
./deploy_with_persistent_data.sh

# 2. Make prediction (creates cache)
curl http://localhost:8081/api/v1/predict/NVDA

# 3. Check data created
ls persistent_data/ml_cache/
ls persistent_data/logs/

# 4. Restart containers
docker-compose -f docker-compose-persistent.yml restart

# 5. Verify data persisted
curl http://localhost:8081/api/v1/predict/NVDA  # Should work
ls persistent_data/ml_cache/  # Should still have files
```

---

## 📚 **Documentation Files**

### **Key Documents**
- **RELEASE_NOTES_PERSISTENT_DATA.md** - Complete release notes
- **README_PERSISTENT_DATA.md** - Updated README with requirements
- **docker-compose-persistent.yml** - Persistent deployment config
- **setup_persistent_data.sh** - Setup script
- **deploy_with_persistent_data.sh** - Deployment script
- **persistent_data/README.md** - Directory documentation

---

## 🎯 **Benefits of Persistent Data**

### **Data Security**
- ✅ **Zero Data Loss**: Models survive any restart
- ✅ **Complete Backup**: Single directory backup
- ✅ **Easy Migration**: Copy persistent_data folder
- ✅ **Audit Trail**: Complete log history

### **Operational Benefits**
- ✅ **Fast Recovery**: Instant restore capability
- ✅ **Easy Debugging**: All logs centralized
- ✅ **Performance**: Persistent cache improves speed
- ✅ **Monitoring**: Historical metrics maintained

### **Development Benefits**
- ✅ **Consistent Environment**: Same structure everywhere
- ✅ **Easy Testing**: Persistent test data
- ✅ **Team Collaboration**: Shared data structure
- ✅ **Version Control**: Track model evolution

---

## 🚨 **Emergency Procedures**

### **If Data is Lost**
1. **Stop all services immediately**
2. **Check if backup exists**: `ls persistent_data/backups/`
3. **Restore from backup**: `./persistent_data/restore_data.sh`
4. **If no backup**: Retrain all models using training scripts

### **If Deployment Fails**
1. **Check persistent_data structure**: `ls persistent_data/`
2. **Run setup script**: `./setup_persistent_data.sh`
3. **Check permissions**: `ls -la persistent_data/`
4. **Redeploy**: `./deploy_with_persistent_data.sh`

---

## 🎉 **Summary for Future Reference**

**REMEMBER THESE KEY POINTS:**

1. **🔥 MANDATORY**: All deployments use persistent_data structure
2. **🔥 MANDATORY**: Use docker-compose-persistent.yml only
3. **🔥 MANDATORY**: Run setup_persistent_data.sh before deployment
4. **🔥 MANDATORY**: All ML models save to persistent_data/ml_models/
5. **🔥 MANDATORY**: All logs write to persistent_data/logs/
6. **🔥 MANDATORY**: Regular backups of persistent_data/
7. **🔥 MANDATORY**: Never delete persistent_data directory

**This ensures:**
- Zero data loss
- Complete system persistence
- Easy backup and recovery
- Enterprise-grade reliability
- Production-ready deployment

---

**🎯 For future deployments: ALWAYS use persistent data structure. This is now a fundamental system requirement that ensures data integrity and operational excellence.**
