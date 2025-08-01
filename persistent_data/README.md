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
