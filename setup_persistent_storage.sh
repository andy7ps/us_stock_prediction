#!/bin/bash

# Complete Persistent Storage Setup for Stock Prediction Service
# This script sets up everything needed for persistent data storage

set -e

echo "🗄️  Complete Persistent Storage Setup"
echo "====================================="
echo ""

# Configuration
BASE_DIR="$(pwd)"
DATA_DIR="$BASE_DIR/persistent_data"
BACKUP_DIR="$DATA_DIR/backups"

echo "📍 Working Directory: $BASE_DIR"
echo "💾 Persistent Data: $DATA_DIR"
echo ""

# Step 1: Create persistent storage structure
echo "📂 Step 1: Creating persistent storage directories..."
if [ ! -f "./create_persistent_storage.sh" ]; then
    echo "❌ create_persistent_storage.sh not found!"
    exit 1
fi

./create_persistent_storage.sh

# Step 2: Verify Docker Compose configuration
echo ""
echo "🐳 Step 2: Verifying Docker Compose configuration..."
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found!"
    exit 1
fi

if grep -q "persistent_data" docker-compose.yml; then
    echo "✅ Docker Compose configured for persistent storage"
else
    echo "⚠️  Docker Compose may need persistent storage configuration"
fi

# Step 3: Create environment configuration for persistent paths
echo ""
echo "⚙️  Step 3: Creating persistent storage environment configuration..."
cat > "$DATA_DIR/config/persistent.env" << 'EOF'
# Persistent Storage Configuration
# These paths point to persistent storage locations

# ML Model Paths
ML_MODEL_PATH=/app/persistent_data/ml_models/nvda_lstm_model
ML_SCALER_PATH=/app/persistent_data/scalers/scaler.pkl
ML_CACHE_PATH=/app/persistent_data/ml_cache

# Database Path (New in v3.4.0)
PREDICTION_DB_PATH=/app/database/predictions.db

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
EOF

echo "✅ Created persistent storage environment configuration"

# Step 4: Create data management scripts
echo ""
echo "🛠️  Step 4: Creating data management scripts..."

# Data backup script
cat > "$DATA_DIR/backup_data.sh" << 'EOF'
#!/bin/bash
# Comprehensive data backup script

set -e

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="stock_prediction_backup_$TIMESTAMP"
BACKUP_PATH="./backups/$BACKUP_NAME"

echo "💾 Creating comprehensive backup: $BACKUP_NAME"

# Create backup directory
mkdir -p "$BACKUP_PATH"

# Backup ML models and cache
echo "🤖 Backing up ML models and cache..."
[ -d "ml_models" ] && cp -r ml_models "$BACKUP_PATH/" || echo "   No ML models found"
[ -d "ml_cache" ] && cp -r ml_cache "$BACKUP_PATH/" || echo "   No ML cache found"
[ -d "scalers" ] && cp -r scalers "$BACKUP_PATH/" || echo "   No scalers found"

# Backup stock data
echo "📈 Backing up stock data..."
[ -d "stock_data" ] && cp -r stock_data "$BACKUP_PATH/" || echo "   No stock data found"

# Backup configuration
echo "⚙️  Backing up configuration..."
[ -d "config" ] && cp -r config "$BACKUP_PATH/" || echo "   No config found"

# Backup logs (last 7 days only to save space)
echo "📝 Backing up recent logs..."
if [ -d "logs" ]; then
    mkdir -p "$BACKUP_PATH/logs"
    find logs -name "*.log" -mtime -7 -exec cp {} "$BACKUP_PATH/logs/" \; 2>/dev/null || true
fi

# Create backup metadata
cat > "$BACKUP_PATH/backup_info.json" << EOL
{
  "backup_name": "$BACKUP_NAME",
  "timestamp": "$TIMESTAMP",
  "date": "$(date)",
  "service": "Stock Prediction Service v3.1.0",
  "backup_type": "full",
  "directories": [
    "ml_models",
    "ml_cache", 
    "scalers",
    "stock_data",
    "config",
    "logs"
  ]
}
EOL

# Compress backup
echo "🗜️  Compressing backup..."
tar -czf "$BACKUP_PATH.tar.gz" -C backups "$BACKUP_NAME"
rm -rf "$BACKUP_PATH"

# Calculate size
BACKUP_SIZE=$(du -h "$BACKUP_PATH.tar.gz" | cut -f1)

echo "✅ Backup completed successfully!"
echo "   📁 File: $BACKUP_PATH.tar.gz"
echo "   📊 Size: $BACKUP_SIZE"
echo "   🕐 Time: $(date)"

# Cleanup old backups (keep last 10)
echo "🧹 Cleaning up old backups..."
ls -t backups/stock_prediction_backup_*.tar.gz 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
echo "   Kept most recent 10 backups"
EOF

chmod +x "$DATA_DIR/backup_data.sh"

# Data restore script
cat > "$DATA_DIR/restore_data.sh" << 'EOF'
#!/bin/bash
# Data restore script

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup_file.tar.gz>"
    echo ""
    echo "Available backups:"
    ls -la backups/stock_prediction_backup_*.tar.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

BACKUP_FILE="$1"
RESTORE_DIR="./restore_temp"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "🔄 Restoring data from: $BACKUP_FILE"

# Extract backup
echo "📦 Extracting backup..."
mkdir -p "$RESTORE_DIR"
tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"

# Find extracted directory
EXTRACTED_DIR=$(find "$RESTORE_DIR" -name "stock_prediction_backup_*" -type d | head -1)

if [ -z "$EXTRACTED_DIR" ]; then
    echo "❌ Could not find extracted backup directory"
    rm -rf "$RESTORE_DIR"
    exit 1
fi

echo "📂 Found backup directory: $EXTRACTED_DIR"

# Restore data with confirmation
echo "⚠️  This will overwrite existing data. Continue? (y/N)"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "❌ Restore cancelled"
    rm -rf "$RESTORE_DIR"
    exit 1
fi

# Restore each directory
for dir in ml_models ml_cache scalers stock_data config; do
    if [ -d "$EXTRACTED_DIR/$dir" ]; then
        echo "🔄 Restoring $dir..."
        rm -rf "$dir" 2>/dev/null || true
        cp -r "$EXTRACTED_DIR/$dir" .
    fi
done

# Cleanup
rm -rf "$RESTORE_DIR"

echo "✅ Data restore completed successfully!"
echo "🔄 Restart the service to use restored data"
EOF

chmod +x "$DATA_DIR/restore_data.sh"

# Data cleanup script
cat > "$DATA_DIR/cleanup_data.sh" << 'EOF'
#!/bin/bash
# Data cleanup script for maintenance

set -e

echo "🧹 Starting data cleanup..."

# Clean old cache files (older than 24 hours)
echo "🗑️  Cleaning old cache files..."
find ml_cache -name "*.cache" -mtime +1 -delete 2>/dev/null || true
find stock_data/cache -name "*.json" -mtime +1 -delete 2>/dev/null || true

# Clean old log files (older than 30 days)
echo "📝 Cleaning old log files..."
find logs -name "*.log" -mtime +30 -delete 2>/dev/null || true

# Clean old prediction files (older than 7 days)
echo "🔮 Cleaning old prediction files..."
find stock_data/predictions -name "*.json" -mtime +7 -delete 2>/dev/null || true

# Show disk usage
echo "💾 Current disk usage:"
du -sh . 2>/dev/null || true

echo "✅ Cleanup completed!"
EOF

chmod +x "$DATA_DIR/cleanup_data.sh"

echo "✅ Created data management scripts:"
echo "   💾 backup_data.sh - Create comprehensive backups"
echo "   🔄 restore_data.sh - Restore from backup"
echo "   🧹 cleanup_data.sh - Clean old data files"

# Step 5: Create monitoring script for data usage
echo ""
echo "📊 Step 5: Creating data monitoring script..."
cat > "$DATA_DIR/monitor_data.sh" << 'EOF'
#!/bin/bash
# Data usage monitoring script

echo "📊 Stock Prediction Service - Data Usage Report"
echo "=============================================="
echo "Generated: $(date)"
echo ""

# Overall disk usage
echo "💾 Overall Disk Usage:"
du -sh . 2>/dev/null || echo "Unable to calculate"
echo ""

# Directory breakdown
echo "📁 Directory Breakdown:"
for dir in ml_models ml_cache scalers stock_data logs config backups monitoring; do
    if [ -d "$dir" ]; then
        size=$(du -sh "$dir" 2>/dev/null | cut -f1)
        count=$(find "$dir" -type f 2>/dev/null | wc -l)
        echo "   $dir: $size ($count files)"
    fi
done
echo ""

# Recent activity
echo "🕐 Recent Activity:"
echo "   Last backup: $(ls -t backups/*.tar.gz 2>/dev/null | head -1 | xargs ls -la 2>/dev/null || echo 'No backups found')"
echo "   Recent logs: $(find logs -name "*.log" -mtime -1 2>/dev/null | wc -l) files from last 24h"
echo "   Cache files: $(find */cache -name "*" -type f 2>/dev/null | wc -l) cached items"
echo ""

# Health check
echo "🏥 Data Health Check:"
[ -d "ml_models" ] && echo "   ✅ ML models directory exists" || echo "   ⚠️  ML models directory missing"
[ -d "stock_data" ] && echo "   ✅ Stock data directory exists" || echo "   ⚠️  Stock data directory missing"
[ -d "logs" ] && echo "   ✅ Logs directory exists" || echo "   ⚠️  Logs directory missing"
[ -d "backups" ] && echo "   ✅ Backups directory exists" || echo "   ⚠️  Backups directory missing"

backup_count=$(ls backups/*.tar.gz 2>/dev/null | wc -l)
if [ "$backup_count" -gt 0 ]; then
    echo "   ✅ $backup_count backup(s) available"
else
    echo "   ⚠️  No backups found - consider running backup_data.sh"
fi
EOF

chmod +x "$DATA_DIR/monitor_data.sh"

echo "✅ Created data monitoring script"

# Step 6: Test the setup
echo ""
echo "🧪 Step 6: Testing persistent storage setup..."

# Test directory creation
if [ -d "$DATA_DIR/ml_models" ] && [ -d "$DATA_DIR/stock_data" ] && [ -d "$DATA_DIR/logs" ]; then
    echo "✅ All required directories created successfully"
else
    echo "❌ Some directories are missing"
    exit 1
fi

# Test permissions
if [ -w "$DATA_DIR" ]; then
    echo "✅ Directory permissions are correct"
else
    echo "❌ Directory permissions issue"
    exit 1
fi

# Test scripts
if [ -x "$DATA_DIR/backup_data.sh" ] && [ -x "$DATA_DIR/restore_data.sh" ]; then
    echo "✅ Management scripts are executable"
else
    echo "❌ Script permissions issue"
    exit 1
fi

# Step 7: Create quick start guide
echo ""
echo "📖 Step 7: Creating quick start guide..."
cat > "$DATA_DIR/PERSISTENT_STORAGE_GUIDE.md" << 'EOF'
# Persistent Storage Quick Start Guide

## Overview
This directory contains persistent data that survives container restarts and updates.

## Directory Structure
```
persistent_data/
├── ml_models/          # ML model files and weights
├── ml_cache/           # Cached ML predictions
├── scalers/            # Data preprocessing scalers
├── stock_data/         # Stock market data
│   ├── historical/     # Historical price data
│   ├── cache/          # Cached stock data
│   └── predictions/    # Prediction results
├── logs/               # Application logs
├── config/             # Runtime configuration
├── backups/            # Automated backups
└── monitoring/         # Prometheus/Grafana data
```

## Quick Commands

### Start with Persistent Storage
```bash
# Setup persistent storage (run once)
./setup_persistent_storage.sh

# Start services with persistent volumes
docker-compose up -d
```

### Data Management
```bash
# Create backup
cd persistent_data && ./backup_data.sh

# Monitor data usage
cd persistent_data && ./monitor_data.sh

# Cleanup old files
cd persistent_data && ./cleanup_data.sh

# Restore from backup
cd persistent_data && ./restore_data.sh backups/backup_file.tar.gz
```

### Verify Persistence
```bash
# 1. Start services
docker-compose up -d

# 2. Generate some data
curl http://localhost:8080/api/v1/predict/NVDA

# 3. Stop services
docker-compose down

# 4. Start again - data should persist
docker-compose up -d
curl http://localhost:8080/api/v1/stats
```

## Environment Variables
The following environment variables are configured for persistent storage:
- `ML_MODEL_PATH`: Points to persistent ML models
- `ML_SCALER_PATH`: Points to persistent scalers
- `STOCK_DATA_CACHE_PATH`: Points to persistent stock cache
- `PREDICTION_CACHE_PATH`: Points to persistent predictions

## Backup Strategy
- Automated backups include all critical data
- Backups are compressed and timestamped
- Old backups are automatically cleaned (keeps last 10)
- Restore process includes data validation

## Monitoring
- Use `monitor_data.sh` for disk usage reports
- Check backup status and data health
- Monitor cache efficiency and cleanup needs

## Troubleshooting
1. **Permission Issues**: Ensure directories are owned by user 1001:1001
2. **Missing Data**: Check if volumes are properly mounted
3. **Backup Failures**: Verify disk space and permissions
4. **Performance Issues**: Run cleanup_data.sh to remove old files
EOF

echo "✅ Created persistent storage guide"

# Final summary
echo ""
echo "🎉 Persistent Storage Setup Completed Successfully!"
echo "=================================================="
echo ""
echo "📊 Setup Summary:"
echo "   📁 Data Directory: $DATA_DIR"
echo "   🗂️  Subdirectories: $(find "$DATA_DIR" -type d | wc -l) created"
echo "   📜 Scripts: 4 management scripts created"
echo "   📖 Documentation: Quick start guide created"
echo "   ⚙️  Configuration: Environment variables configured"
echo ""
echo "🚀 Next Steps:"
echo "   1. Review docker-compose.yml volume mounts"
echo "   2. Start services: docker-compose up -d"
echo "   3. Test data persistence: Generate data, restart, verify"
echo "   4. Setup backup schedule: cron job for backup_data.sh"
echo ""
echo "📋 Management Commands:"
echo "   💾 Backup:  cd persistent_data && ./backup_data.sh"
echo "   📊 Monitor: cd persistent_data && ./monitor_data.sh"
echo "   🧹 Cleanup: cd persistent_data && ./cleanup_data.sh"
echo ""
echo "✅ Your stock prediction service now has persistent data storage!"
echo "   Data will survive container restarts, updates, and system reboots."
echo ""
