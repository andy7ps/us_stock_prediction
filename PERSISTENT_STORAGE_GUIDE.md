# Persistent Storage Guide - Stock Prediction Service

## 🎯 Overview

This guide covers the comprehensive persistent storage solution for the Stock Prediction Service. The persistent storage system ensures that ML models, stock data, predictions, and system logs survive container restarts, updates, and system reboots.

## 🗄️ Problem Solved

**Before Persistent Storage:**
- ❌ ML model data lost on container restart
- ❌ Stock price history cache cleared on restart
- ❌ Prediction results not preserved
- ❌ System logs lost on container updates
- ❌ Configuration changes not persistent

**After Persistent Storage:**
- ✅ ML models and cache persist across restarts
- ✅ Stock data history maintained long-term
- ✅ Prediction results stored for analysis
- ✅ Complete log history preserved
- ✅ Configuration changes survive updates

## 📁 Directory Structure

```
persistent_data/
├── ml_models/              # ML model files and weights
│   ├── nvda_lstm_model     # LSTM model for NVDA predictions
│   ├── model_weights.h5    # Neural network weights
│   └── model_config.json   # Model configuration
├── ml_cache/               # Cached ML predictions for performance
│   ├── predictions_cache/  # Recent prediction cache
│   └── model_cache/        # Model inference cache
├── scalers/                # Data preprocessing scalers
│   ├── scaler.pkl          # Price data scaler
│   └── feature_scalers/    # Feature-specific scalers
├── stock_data/             # Stock market data storage
│   ├── historical/         # Historical stock price data
│   │   ├── NVDA/          # NVDA historical data
│   │   ├── TSLA/          # TSLA historical data
│   │   └── AAPL/          # AAPL historical data
│   ├── cache/             # Cached stock data for quick access
│   │   ├── daily_cache/   # Daily price cache
│   │   └── intraday_cache/ # Intraday price cache
│   └── predictions/       # Stored prediction results
│       ├── daily/         # Daily predictions
│       └── analysis/      # Prediction analysis results
├── logs/                  # Application logs and audit trails
│   ├── application.log    # Main application logs
│   ├── prediction.log     # ML prediction logs
│   ├── api.log           # API request logs
│   └── error.log         # Error logs
├── config/               # Runtime configuration files
│   ├── persistent.env    # Persistent storage configuration
│   ├── ml_config.json    # ML model configuration
│   └── api_config.json   # API configuration
├── backups/              # Automated data backups
│   ├── stock_prediction_backup_20250801_120000.tar.gz
│   └── backup_schedule.log
└── monitoring/           # Prometheus and Grafana data
    ├── prometheus/       # Prometheus time-series data
    └── grafana/         # Grafana dashboard data
```

## 🚀 Quick Start

### 1. Setup Persistent Storage

```bash
# One-command setup
./setup_persistent_storage.sh

# Or using Makefile
make storage-setup
```

### 2. Start Services with Persistent Storage

```bash
# Start with persistent volumes
docker-compose up -d

# Verify persistent storage is working
make storage-test
```

### 3. Verify Data Persistence

```bash
# Generate some data
curl http://localhost:8080/api/v1/predict/NVDA
curl http://localhost:8080/api/v1/predict/TSLA

# Stop services
docker-compose down

# Start again - data should persist
docker-compose up -d

# Verify data is still there
curl http://localhost:8080/api/v1/stats
make storage-monitor
```

## 🔧 Configuration

### Environment Variables

The following environment variables are automatically configured for persistent storage:

```bash
# ML Model Paths
ML_MODEL_PATH=/app/persistent_data/ml_models/nvda_lstm_model
ML_SCALER_PATH=/app/persistent_data/scalers/scaler.pkl
ML_CACHE_PATH=/app/persistent_data/ml_cache

# Stock Data Paths
STOCK_DATA_CACHE_PATH=/app/persistent_data/stock_data/cache
STOCK_HISTORICAL_PATH=/app/persistent_data/stock_data/historical
PREDICTION_CACHE_PATH=/app/persistent_data/stock_data/predictions

# Application Paths
LOG_PATH=/app/persistent_data/logs
CONFIG_PATH=/app/persistent_data/config
BACKUP_PATH=/app/persistent_data/backups

# Cache Settings for Persistence
ML_PREDICTION_TTL=1h
STOCK_DATA_TTL=30m
CACHE_CLEANUP_INTERVAL=6h
```

### Docker Compose Configuration

The `docker-compose.yml` is automatically configured with persistent volume mounts:

```yaml
services:
  stock-prediction:
    volumes:
      # Main persistent data volume
      - ./persistent_data:/app/persistent_data
      # Individual service volumes
      - ./persistent_data/ml_models:/app/models
      - ./persistent_data/logs:/app/logs
      - ./persistent_data/config:/app/config
      
  prometheus:
    volumes:
      # Persistent Prometheus data
      - ./persistent_data/prometheus:/prometheus
      
  grafana:
    volumes:
      # Persistent Grafana data
      - ./persistent_data/grafana:/var/lib/grafana
```

## 🛠️ Management Commands

### Makefile Targets

```bash
# Setup and Testing
make storage-setup          # Setup persistent storage
make storage-test           # Test storage functionality

# Data Management
make storage-backup         # Create comprehensive backup
make storage-monitor        # Monitor data usage
make storage-cleanup        # Clean old data files
make storage-restore BACKUP=filename.tar.gz  # Restore from backup
```

### Direct Script Usage

```bash
# Navigate to persistent data directory
cd persistent_data

# Create backup
./backup_data.sh

# Monitor data usage
./monitor_data.sh

# Cleanup old files
./cleanup_data.sh

# Restore from backup
./restore_data.sh backups/backup_filename.tar.gz
```

## 💾 Backup and Restore

### Automated Backup

The backup system creates comprehensive backups including:

- **ML Models**: All model files and weights
- **ML Cache**: Recent prediction cache for performance
- **Scalers**: Data preprocessing components
- **Stock Data**: Historical data and cached information
- **Configuration**: Runtime configuration files
- **Recent Logs**: Last 7 days of logs (to save space)

```bash
# Create backup
make storage-backup

# Backup output example
💾 Creating comprehensive backup: stock_prediction_backup_20250801_120000
🤖 Backing up ML models and cache...
📈 Backing up stock data...
⚙️  Backing up configuration...
📝 Backing up recent logs...
🗜️  Compressing backup...
✅ Backup completed successfully!
   📁 File: backups/stock_prediction_backup_20250801_120000.tar.gz
   📊 Size: 2.3M
   🕐 Time: Fri Aug  1 12:00:00 CST 2025
```

### Backup Management

- **Automatic Cleanup**: Keeps last 10 backups automatically
- **Compression**: All backups are compressed with gzip
- **Metadata**: Each backup includes creation timestamp and contents
- **Incremental**: Only backs up changed files for efficiency

### Restore Process

```bash
# List available backups
make storage-restore

# Restore specific backup
make storage-restore BACKUP=stock_prediction_backup_20250801_120000.tar.gz

# Restore process includes:
# 1. Backup validation
# 2. User confirmation
# 3. Data extraction
# 4. File restoration
# 5. Permission fixing
```

## 📊 Monitoring and Maintenance

### Data Usage Monitoring

```bash
# Get comprehensive data report
make storage-monitor

# Sample output:
📊 Stock Prediction Service - Data Usage Report
==============================================
Generated: Fri Aug  1 17:08:15 CST 2025

💾 Overall Disk Usage:
2.1G    .

📁 Directory Breakdown:
   ml_models: 450M (15 files)
   ml_cache: 120M (1,234 files)
   scalers: 5.2M (8 files)
   stock_data: 1.2G (5,678 files)
   logs: 89M (45 files)
   config: 1.2M (12 files)
   backups: 234M (10 files)

🕐 Recent Activity:
   Last backup: stock_prediction_backup_20250801_120000.tar.gz (2.3M)
   Recent logs: 15 files from last 24h
   Cache files: 1,234 cached items

🏥 Data Health Check:
   ✅ ML models directory exists
   ✅ Stock data directory exists
   ✅ Logs directory exists
   ✅ Backups directory exists
   ✅ 10 backup(s) available
```

### Automated Cleanup

```bash
# Clean old data files
make storage-cleanup

# Cleanup includes:
# - Cache files older than 24 hours
# - Log files older than 30 days
# - Prediction files older than 7 days
# - Temporary files and empty directories
```

### Health Monitoring

The monitoring system checks:
- **Directory Existence**: All required directories present
- **Permissions**: Proper read/write permissions
- **Disk Usage**: Current storage consumption
- **Backup Status**: Recent backup availability
- **File Counts**: Number of files in each category
- **Recent Activity**: Latest data modifications

## 🔒 Security and Permissions

### File Permissions

- **Directory Permissions**: 755 (rwxr-xr-x)
- **File Permissions**: 644 (rw-r--r--)
- **Script Permissions**: 755 (rwxr-xr-x)
- **User/Group**: 1001:1001 (appuser:appgroup)

### Data Security

- **No Sensitive Data**: No API keys or passwords stored
- **Access Control**: Container runs as non-root user
- **Backup Encryption**: Backups can be encrypted (optional)
- **Network Isolation**: Data directories not exposed to network

## 🚀 Performance Optimization

### Cache Strategy

The persistent storage system implements intelligent caching:

```bash
# ML Prediction Cache
- TTL: 1 hour for predictions
- LRU eviction for memory management
- Persistent across restarts

# Stock Data Cache
- TTL: 30 minutes for real-time data
- Daily data cached for 24 hours
- Historical data cached indefinitely

# Model Cache
- Models loaded once and cached
- Scalers cached in memory
- Feature preprocessing cached
```

### Storage Optimization

- **Compression**: Automatic compression for backups
- **Cleanup**: Automated cleanup of old files
- **Deduplication**: Avoid storing duplicate data
- **Efficient Formats**: Use efficient file formats (JSON, pickle)

## 🧪 Testing Data Persistence

### Manual Testing

```bash
# 1. Start services
docker-compose up -d

# 2. Generate test data
curl http://localhost:8080/api/v1/predict/NVDA
curl http://localhost:8080/api/v1/predict/TSLA
curl http://localhost:8080/api/v1/historical/AAPL?days=30

# 3. Check data is created
make storage-monitor

# 4. Stop services
docker-compose down

# 5. Verify data persists
ls -la persistent_data/stock_data/cache/
ls -la persistent_data/logs/

# 6. Restart services
docker-compose up -d

# 7. Verify data is still available
curl http://localhost:8080/api/v1/stats
```

### Automated Testing

```bash
# Run comprehensive storage test
make storage-test

# Test includes:
# - Directory existence verification
# - Permission checking
# - Write/read capability testing
# - Volume mount verification
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Permission Denied Errors

```bash
# Problem: Container cannot write to persistent storage
# Solution: Fix directory permissions
sudo chown -R 1001:1001 persistent_data/
chmod -R 755 persistent_data/
```

#### 2. Volume Mount Issues

```bash
# Problem: Data not persisting across restarts
# Solution: Verify docker-compose.yml volume mounts
docker-compose config | grep volumes

# Check if directories exist
ls -la persistent_data/
```

#### 3. Disk Space Issues

```bash
# Problem: Running out of disk space
# Solution: Clean old data
make storage-cleanup

# Check disk usage
make storage-monitor

# Remove old backups manually if needed
ls -la persistent_data/backups/
```

#### 4. Backup/Restore Failures

```bash
# Problem: Backup creation fails
# Solution: Check permissions and disk space
df -h
ls -la persistent_data/

# Problem: Restore fails
# Solution: Verify backup file integrity
tar -tzf persistent_data/backups/backup_file.tar.gz
```

### Debug Commands

```bash
# Check container volume mounts
docker inspect stock-prediction | grep -A 10 "Mounts"

# Verify data inside container
docker exec -it stock-prediction ls -la /app/persistent_data/

# Check container logs for storage issues
docker logs stock-prediction | grep -i "persistent\|storage\|volume"

# Test file creation inside container
docker exec -it stock-prediction touch /app/persistent_data/test_file
docker exec -it stock-prediction ls -la /app/persistent_data/test_file
```

## 📈 Production Considerations

### Backup Strategy

For production environments:

```bash
# Daily automated backups
0 2 * * * cd /path/to/stock-prediction && make storage-backup

# Weekly full system backup
0 1 * * 0 cd /path/to/stock-prediction && tar -czf weekly_backup.tar.gz persistent_data/

# Monthly archive to external storage
0 0 1 * * rsync -av persistent_data/ backup-server:/backups/stock-prediction/
```

### Monitoring Integration

```bash
# Disk usage alerts
# Add to monitoring system:
# - Alert when disk usage > 80%
# - Alert when backup fails
# - Alert when cleanup fails

# Prometheus metrics for storage
# - persistent_storage_size_bytes
# - persistent_storage_files_total
# - backup_last_success_timestamp
```

### Scaling Considerations

- **Shared Storage**: Use NFS or cloud storage for multi-instance deployments
- **Database Migration**: Consider migrating to PostgreSQL for large datasets
- **Cache Optimization**: Implement Redis for distributed caching
- **Backup Distribution**: Distribute backups across multiple locations

## 🎯 Best Practices

### Data Organization

1. **Separate by Type**: Keep different data types in separate directories
2. **Use Timestamps**: Include timestamps in file names for versioning
3. **Compress Large Files**: Use compression for large datasets
4. **Regular Cleanup**: Implement automated cleanup policies

### Backup Management

1. **Regular Schedule**: Automate daily backups
2. **Multiple Locations**: Store backups in multiple locations
3. **Test Restores**: Regularly test backup restoration
4. **Monitor Size**: Monitor backup sizes and cleanup old backups

### Performance Optimization

1. **Cache Tuning**: Adjust cache TTL based on usage patterns
2. **Cleanup Frequency**: Balance cleanup frequency with performance
3. **Storage Type**: Use SSD storage for better performance
4. **Monitoring**: Monitor storage performance metrics

## 📚 Additional Resources

- **Docker Volumes Documentation**: https://docs.docker.com/storage/volumes/
- **Docker Compose Volumes**: https://docs.docker.com/compose/compose-file/#volumes
- **Production Storage Best Practices**: Internal documentation
- **Backup Strategy Guide**: Internal documentation

---

**🎉 Your stock prediction service now has enterprise-grade persistent storage that ensures data survives any container lifecycle events!**
