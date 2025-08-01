#!/bin/bash

# Persistent Storage Setup Script for Stock Prediction Service
# This script creates local directories for persistent data storage

set -e

echo "🗄️  Setting up Persistent Storage for Stock Prediction Service"
echo "=============================================================="

# Configuration
BASE_DIR="$(pwd)"
DATA_DIR="$BASE_DIR/persistent_data"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

echo "📁 Base Directory: $BASE_DIR"
echo "💾 Data Directory: $DATA_DIR"
echo ""

# Create main persistent data directory
echo "📂 Creating persistent data directories..."

# Main data directory
mkdir -p "$DATA_DIR"

# ML Models and Cache
mkdir -p "$DATA_DIR/ml_models"
mkdir -p "$DATA_DIR/ml_cache"
mkdir -p "$DATA_DIR/scalers"

# Stock Data Storage
mkdir -p "$DATA_DIR/stock_data/historical"
mkdir -p "$DATA_DIR/stock_data/cache"
mkdir -p "$DATA_DIR/stock_data/predictions"

# Application Data
mkdir -p "$DATA_DIR/logs"
mkdir -p "$DATA_DIR/config"
mkdir -p "$DATA_DIR/backups"

# Monitoring Data
mkdir -p "$DATA_DIR/prometheus"
mkdir -p "$DATA_DIR/grafana"

echo "✅ Created directory structure:"
echo "   📁 $DATA_DIR/"
echo "   ├── 🤖 ml_models/          # ML model files"
echo "   ├── 🧠 ml_cache/           # ML prediction cache"
echo "   ├── 📊 scalers/            # Data scalers"
echo "   ├── 📈 stock_data/"
echo "   │   ├── historical/        # Historical stock data"
echo "   │   ├── cache/             # Stock data cache"
echo "   │   └── predictions/       # Prediction results"
echo "   ├── 📝 logs/               # Application logs"
echo "   ├── ⚙️  config/            # Configuration files"
echo "   ├── 💾 backups/            # Data backups"
echo "   └── 📊 monitoring/"
echo "       ├── prometheus/        # Prometheus data"
echo "       └── grafana/           # Grafana data"
echo ""

# Set proper permissions
echo "🔐 Setting directory permissions..."
chmod -R 755 "$DATA_DIR"

# Create .gitignore for data directory
echo "📝 Creating .gitignore for persistent data..."
cat > "$DATA_DIR/.gitignore" << 'EOF'
# Ignore all data files but keep directory structure
*
!.gitignore
!README.md

# Keep important directories
!ml_models/
!stock_data/
!logs/
!config/
!backups/
!monitoring/

# But ignore their contents
ml_models/*
stock_data/*
logs/*
config/*
backups/*
monitoring/*

# Keep example files
!*.example
!*.template
EOF

# Create README for data directory
echo "📖 Creating README for persistent data directory..."
cat > "$DATA_DIR/README.md" << 'EOF'
# Persistent Data Directory

This directory contains persistent data for the Stock Prediction Service that survives container restarts.

## Directory Structure

- **ml_models/**: Machine learning model files and weights
- **ml_cache/**: Cached ML predictions for performance
- **scalers/**: Data preprocessing scalers
- **stock_data/**: Stock market data storage
  - **historical/**: Historical stock price data
  - **cache/**: Cached stock data for quick access
  - **predictions/**: Stored prediction results
- **logs/**: Application logs and audit trails
- **config/**: Runtime configuration files
- **backups/**: Automated data backups
- **monitoring/**: Prometheus and Grafana data

## Volume Mounts

These directories are mounted into the Docker container:
- `/app/persistent_data` → Container data directory
- Individual mounts for specific services

## Backup Strategy

Regular backups are created in the `backups/` directory with timestamps.
EOF

# Copy existing models if they exist
if [ -d "models" ]; then
    echo "📦 Copying existing models to persistent storage..."
    cp -r models/* "$DATA_DIR/ml_models/" 2>/dev/null || echo "   No models to copy"
fi

# Copy existing logs if they exist
if [ -d "logs" ]; then
    echo "📋 Copying existing logs to persistent storage..."
    cp -r logs/* "$DATA_DIR/logs/" 2>/dev/null || echo "   No logs to copy"
fi

# Create backup script
echo "💾 Creating backup script..."
cat > "$DATA_DIR/create_backup.sh" << 'EOF'
#!/bin/bash
# Automated backup script for persistent data

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="./backups/backup_$TIMESTAMP"

echo "Creating backup: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Backup ML models and data
cp -r ml_models "$BACKUP_DIR/" 2>/dev/null || echo "No ML models to backup"
cp -r stock_data "$BACKUP_DIR/" 2>/dev/null || echo "No stock data to backup"
cp -r config "$BACKUP_DIR/" 2>/dev/null || echo "No config to backup"

# Create backup info
echo "Backup created: $(date)" > "$BACKUP_DIR/backup_info.txt"
echo "Service version: Stock Prediction v3.1.0" >> "$BACKUP_DIR/backup_info.txt"

# Compress backup
tar -czf "$BACKUP_DIR.tar.gz" -C backups "backup_$TIMESTAMP"
rm -rf "$BACKUP_DIR"

echo "Backup completed: $BACKUP_DIR.tar.gz"
EOF

chmod +x "$DATA_DIR/create_backup.sh"

echo ""
echo "🎉 Persistent storage setup completed!"
echo ""
echo "📊 Storage Summary:"
echo "   📁 Base Path: $DATA_DIR"
echo "   💾 Total Directories: $(find "$DATA_DIR" -type d | wc -l)"
echo "   🔐 Permissions: 755 (read/write/execute for owner)"
echo "   📝 Documentation: README.md created"
echo "   💾 Backup Script: create_backup.sh created"
echo ""
echo "🚀 Next Steps:"
echo "   1. Update docker-compose.yml with volume mounts"
echo "   2. Update Dockerfile for persistent data paths"
echo "   3. Configure application to use persistent storage"
echo "   4. Test container restart data persistence"
echo ""
echo "📋 Usage:"
echo "   docker-compose up -d    # Start with persistent volumes"
echo "   ./create_backup.sh      # Create data backup"
echo ""
