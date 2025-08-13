#!/bin/bash

# Setup Persistent Data Structure for Stock Prediction System
# This script ensures all required directories exist for Docker deployment

set -e

echo "🔧 Setting up Persistent Data Structure"
echo "======================================="

BASE_DIR="./persistent_data"

# Create all required directories
echo "📁 Creating directory structure..."

# ML Model and Training Data
mkdir -p "$BASE_DIR/ml_models"
mkdir -p "$BASE_DIR/ml_cache"
mkdir -p "$BASE_DIR/scalers"

# Stock Data Storage
mkdir -p "$BASE_DIR/stock_data/historical"
mkdir -p "$BASE_DIR/stock_data/cache"
mkdir -p "$BASE_DIR/stock_data/predictions"

# Application Logs
mkdir -p "$BASE_DIR/logs/application"
mkdir -p "$BASE_DIR/logs/prometheus"
mkdir -p "$BASE_DIR/logs/grafana"

# Configuration Files
mkdir -p "$BASE_DIR/config"

# Backup Storage
mkdir -p "$BASE_DIR/backups"

# Docker Service Data
mkdir -p "$BASE_DIR/redis"
mkdir -p "$BASE_DIR/prometheus"
mkdir -p "$BASE_DIR/grafana"

# Frontend Data
mkdir -p "$BASE_DIR/frontend/logs"
mkdir -p "$BASE_DIR/frontend/cache"

# Set proper permissions
echo "🔐 Setting permissions..."

# Make directories writable for Docker containers
chmod -R 755 "$BASE_DIR"

# Specific permissions for service users
chmod -R 777 "$BASE_DIR/redis"           # Redis user
chmod -R 777 "$BASE_DIR/prometheus"      # Prometheus user  
chmod -R 777 "$BASE_DIR/grafana"         # Grafana user (472:472)
chmod -R 777 "$BASE_DIR/logs"            # Log directories
chmod -R 777 "$BASE_DIR/frontend"        # Nginx user

# Create configuration files if they don't exist
echo "📝 Creating configuration files..."

# Redis configuration
if [ ! -f "$BASE_DIR/config/redis.conf" ]; then
    cat > "$BASE_DIR/config/redis.conf" << 'EOF'
# Redis Configuration for Stock Prediction System
appendonly yes
appendfsync everysec
maxmemory 512mb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
EOF
fi

# ML Configuration
if [ ! -f "$BASE_DIR/ml_config.json" ]; then
    cat > "$BASE_DIR/ml_config.json" << 'EOF'
{
  "model_path": "/app/persistent_data/ml_models",
  "cache_path": "/app/persistent_data/ml_cache",
  "scalers_path": "/app/persistent_data/scalers",
  "stock_data_path": "/app/persistent_data/stock_data",
  "log_path": "/app/persistent_data/logs",
  "backup_path": "/app/persistent_data/backups",
  "supported_symbols": ["NVDA", "TSLA", "AAPL", "MSFT", "GOOGL", "AMZN", "AUR", "PLTR", "SMCI", "TSM", "MP", "SMR", "SPY"],
  "training_config": {
    "epochs": 50,
    "batch_size": 32,
    "validation_split": 0.2,
    "early_stopping_patience": 10
  }
}
EOF
fi

# Create README for persistent_data
cat > "$BASE_DIR/README.md" << 'EOF'
# Persistent Data Directory

This directory contains ALL persistent data for the Stock Prediction System.

## Directory Structure

```
persistent_data/
├── ml_models/          # Trained ML models (.h5, .pkl files)
├── ml_cache/           # ML prediction cache
├── scalers/            # Data scalers for ML models
├── stock_data/         # Stock market data
│   ├── historical/     # Historical stock data
│   ├── cache/          # Cached stock data
│   └── predictions/    # Prediction results
├── logs/               # Application logs
│   ├── application/    # Backend application logs
│   ├── prometheus/     # Prometheus logs
│   └── grafana/        # Grafana logs
├── config/             # Configuration files
├── backups/            # Data backups
├── redis/              # Redis persistent data
├── prometheus/         # Prometheus metrics data
├── grafana/            # Grafana dashboards and settings
└── frontend/           # Frontend logs and cache
    ├── logs/           # Nginx logs
    └── cache/          # Nginx cache
```

## Docker Integration

All Docker containers mount data from this directory:
- Backend: `/app/persistent_data` -> `./persistent_data`
- Redis: `/data` -> `./persistent_data/redis`
- Prometheus: `/prometheus` -> `./persistent_data/prometheus`
- Grafana: `/var/lib/grafana` -> `./persistent_data/grafana`

## Backup and Restore

Use the provided scripts:
- `backup_data.sh` - Create backups
- `restore_data.sh` - Restore from backups
- `monitor_data.sh` - Monitor data usage

## Important Notes

- Never delete this directory - it contains all your trained models
- Regular backups are recommended
- All Docker deployments depend on this structure
- Permissions are set for Docker container access
EOF

# Create .gitignore for persistent_data
cat > "$BASE_DIR/.gitignore" << 'EOF'
# Ignore large data files but keep structure
*.h5
*.pkl
*.log
*.db
*.sqlite
redis/
prometheus/
grafana/
logs/
cache/
*.tmp
*.temp

# Keep important files
!README.md
!ml_config.json
!config/
!.gitignore
EOF

echo "✅ Persistent data structure created successfully!"
echo ""
echo "📊 Directory Summary:"
find "$BASE_DIR" -type d | sort

echo ""
echo "🎯 Key Features:"
echo "   📁 Complete directory structure for all services"
echo "   🔐 Proper permissions for Docker containers"
echo "   📝 Configuration files created"
echo "   📚 Documentation included"
echo "   🔄 Ready for Docker deployment"
echo ""
echo "🚀 You can now run: docker-compose -f docker-compose-persistent.yml up -d"
