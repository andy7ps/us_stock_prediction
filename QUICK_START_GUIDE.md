# Stock Prediction Service v3.0 - Quick Start Guide

**Get up and running in 5 minutes! 🚀**

---

## 📋 Prerequisites

Before starting, ensure you have:
- **Go 1.23+** installed
- **Python 3.11+** installed
- **Docker & Docker Compose** (for containerized deployment)
- **Make** (optional, for convenience commands)

---

## 🚀 Method 1: Quick Local Start (Recommended for Development)

### Step 1: Setup Environment
```bash
# Navigate to the project directory
cd ~/andy_misc/golang/ml/stock_prediction/v3

# Setup development environment (creates .env, models/, logs/ directories)
make dev-setup
# OR manually:
# cp .env.example .env
# mkdir -p models logs
```

### Step 2: Install Dependencies
```bash
# Install Go dependencies
make deps
# OR manually:
# go mod download && go mod tidy
```

### Step 3: Start the Service
```bash
# Start the service locally
make run
# OR manually:
# go run main.go
```

**Expected Output:**
```json
{"level":"info","msg":"Starting Stock Prediction Service v3.0","time":"2025-07-25T18:55:53+08:00"}
{"level":"info","msg":"Starting HTTP server","port":8080,"time":"2025-07-25T18:55:53+08:00"}
```

✅ **Service is now running on http://localhost:8080**

---

## 🐳 Method 2: Docker Deployment (Recommended for Production)

### Step 1: Start with Docker Compose
```bash
# Start the complete stack (app + monitoring)
make docker-run
# OR manually:
# docker-compose up -d
```

### Step 2: Verify Services
```bash
# Check service status
docker-compose ps

# View logs
make docker-logs
# OR manually:
# docker-compose logs -f stock-prediction
```

**Expected Services:**
- **Stock Prediction API**: http://localhost:8080
- **Prometheus Metrics**: http://localhost:9090
- **Grafana Dashboard**: http://localhost:3000 (admin/admin)

---

## 📊 Performing Stock Predictions

### 1. Basic Stock Prediction

**Get prediction for NVIDIA (NVDA):**
```bash
curl -X GET "http://localhost:8080/api/v1/predict/NVDA"
```

**Response:**
```json
{
  "symbol": "NVDA",
  "current_price": 875.50,
  "predicted_price": 882.15,
  "trading_signal": "BUY",
  "confidence": 0.78,
  "prediction_time": "2025-07-25T18:55:53Z",
  "model_version": "v3.0"
}
```

### 2. Prediction with Custom Lookback Period

**Get prediction with 10-day lookback:**
```bash
curl -X GET "http://localhost:8080/api/v1/predict/AAPL?days=10"
```

### 3. Multiple Stock Predictions

**Predict different stocks:**
```bash
# Apple
curl -X GET "http://localhost:8080/api/v1/predict/AAPL"

# Tesla  
curl -X GET "http://localhost:8080/api/v1/predict/TSLA"

# Microsoft
curl -X GET "http://localhost:8080/api/v1/predict/MSFT"

# Google
curl -X GET "http://localhost:8080/api/v1/predict/GOOGL"
```

### 4. Get Historical Data

**Fetch 30 days of historical data:**
```bash
curl -X GET "http://localhost:8080/api/v1/historical/NVDA?days=30"
```

**Response:**
```json
{
  "symbol": "NVDA",
  "days": 30,
  "count": 30,
  "data": [
    {
      "symbol": "NVDA",
      "timestamp": "2025-07-24T00:00:00Z",
      "open": 870.25,
      "high": 878.90,
      "low": 865.10,
      "close": 875.50,
      "volume": 45678900
    }
    // ... more data points
  ]
}
```

---

## 🔍 System Health & Monitoring

### 1. Check Service Health
```bash
curl -X GET "http://localhost:8080/api/v1/health"
```

**Healthy Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-07-25T18:55:53Z",
  "version": "v3.0",
  "services": {
    "yahoo_api": "healthy",
    "prediction_service": "healthy"
  }
}
```

### 2. View Service Statistics
```bash
curl -X GET "http://localhost:8080/api/v1/stats"
```

**Response:**
```json
{
  "cache": {
    "size": 12,
    "default_ttl": "5m0s",
    "expired_entries": 0
  },
  "model": {
    "model_path": "models/nvda_lstm_model",
    "python_script": "scripts/ml/predict.py",
    "version": "v3.0"
  },
  "system": {
    "goroutines": 15,
    "memory_alloc": 15728640,
    "memory_sys": 25165824,
    "gc_runs": 3
  }
}
```

### 3. View Prometheus Metrics
```bash
curl -X GET "http://localhost:8080/metrics"
```

---

## 🎯 Trading Signal Interpretation

### Signal Types
- **BUY**: Predicted price > current price × buy_threshold (default: 1.01)
- **SELL**: Predicted price < current price × sell_threshold (default: 0.99)
- **HOLD**: Predicted price within neutral range

### Confidence Levels
- **High (0.8-1.0)**: Strong prediction confidence
- **Medium (0.5-0.8)**: Moderate prediction confidence  
- **Low (0.0-0.5)**: Weak prediction confidence

### Example Trading Decision
```json
{
  "symbol": "NVDA",
  "current_price": 875.50,
  "predicted_price": 882.15,
  "trading_signal": "BUY",      // ← Action recommendation
  "confidence": 0.78            // ← 78% confidence
}
```
**Interpretation**: Strong BUY signal with 78% confidence - predicted 0.76% price increase.

---

## 🛠️ Advanced Usage

### 1. Clear Prediction Cache
```bash
curl -X POST "http://localhost:8080/api/v1/cache/clear"
```

### 2. Batch Predictions (Shell Script)
```bash
#!/bin/bash
# batch_predict.sh
symbols=("AAPL" "NVDA" "TSLA" "MSFT" "GOOGL")

for symbol in "${symbols[@]}"; do
    echo "Predicting $symbol..."
    curl -s "http://localhost:8080/api/v1/predict/$symbol" | jq .
    echo "---"
done
```

### 3. Continuous Monitoring
```bash
# Monitor predictions every 30 seconds
watch -n 30 'curl -s http://localhost:8080/api/v1/predict/NVDA | jq .'
```

### 4. Custom Configuration
```bash
# Set custom environment variables
export STOCK_LOOKBACK_DAYS=10
export STOCK_BUY_THRESHOLD=1.02
export STOCK_SELL_THRESHOLD=0.98
export LOG_LEVEL=debug

# Restart service with new config
make run
```

---

## 📱 Web Interface Usage

### 1. Service Information
Visit: http://localhost:8080

**Response:**
```json
{
  "service": "Stock Prediction API",
  "version": "v3.0",
  "status": "running",
  "endpoints": {
    "predict": "/api/v1/predict/{symbol}",
    "historical": "/api/v1/historical/{symbol}",
    "health": "/api/v1/health",
    "stats": "/api/v1/stats",
    "clear_cache": "/api/v1/cache/clear",
    "metrics": "/metrics"
  }
}
```

### 2. Monitoring Dashboards

**Prometheus (Metrics):**
- URL: http://localhost:9090
- Query examples:
  - `api_requests_total` - Total API requests
  - `prediction_latency_seconds` - Prediction latency
  - `cache_hits_total` - Cache performance

**Grafana (Visualization):**
- URL: http://localhost:3000
- Login: admin/admin
- Pre-configured dashboards for service monitoring

---

## 🔧 Troubleshooting

### Common Issues & Solutions

#### 1. Service Won't Start
```bash
# Check if port 8080 is in use
lsof -i :8080

# Use different port
export SERVER_PORT=8081
make run
```

#### 2. Python Script Errors
```bash
# Test Python script manually
python3 scripts/ml/predict.py "100.0,101.0,102.0,103.0,104.0"

# Expected output: A predicted price (e.g., 106.19)
```

#### 3. Yahoo Finance API Errors
```bash
# Check health endpoint
curl http://localhost:8080/api/v1/health

# If yahoo_api shows "unhealthy", check network connectivity
ping query1.finance.yahoo.com
```

#### 4. High Memory Usage
```bash
# Check stats
curl http://localhost:8080/api/v1/stats

# Clear cache if needed
curl -X POST http://localhost:8080/api/v1/cache/clear
```

### Debug Mode
```bash
# Enable debug logging
export LOG_LEVEL=debug
make run

# View detailed logs
tail -f logs/app.log
```

---

## 🎯 Quick Testing Commands

### Test All Endpoints
```bash
make test-api
# OR manually:
echo "Testing Health..."
curl -s http://localhost:8080/api/v1/health | jq .

echo "Testing Prediction..."
curl -s http://localhost:8080/api/v1/predict/NVDA | jq .

echo "Testing Stats..."
curl -s http://localhost:8080/api/v1/stats | jq .
```

### Performance Test
```bash
# Simple load test (requires 'ab' - Apache Bench)
ab -n 100 -c 10 http://localhost:8080/api/v1/predict/AAPL
```

---

## 🚀 Production Deployment Checklist

### Before Going Live:
- [ ] Configure environment variables for production
- [ ] Set up external monitoring (Prometheus/Grafana)
- [ ] Configure log aggregation
- [ ] Set up SSL/TLS termination
- [ ] Configure rate limiting
- [ ] Set up backup and recovery
- [ ] Test failover scenarios
- [ ] Configure alerts and notifications

### Production Environment Variables:
```bash
# Production settings
export SERVER_PORT=8080
export LOG_LEVEL=info
export LOG_FORMAT=json
export STOCK_MAX_RETRIES=5
export STOCK_REQUESTS_PER_SEC=50
export ML_PREDICTION_TTL=10m
```

---

## 📞 Getting Help

### Documentation
- **Full Documentation**: [README.md](README.md)
- **API Reference**: See endpoint documentation above
- **Configuration**: [.env.example](.env.example)

### Support Commands
```bash
# Show all available commands
make help

# Run tests
make test

# Check service status
curl http://localhost:8080/api/v1/health

# View logs
docker-compose logs -f stock-prediction
```

### Common URLs
- **API Base**: http://localhost:8080/api/v1/
- **Health Check**: http://localhost:8080/api/v1/health
- **Metrics**: http://localhost:8080/metrics
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000

---

## 🎉 You're Ready!

**Congratulations!** Your Stock Prediction Service is now running. Start making predictions and monitoring your trading signals!

### Next Steps:
1. **Explore the API** with different stock symbols
2. **Monitor performance** via Grafana dashboards  
3. **Integrate** with your trading applications
4. **Scale** as needed for production workloads

**Happy Trading! 📈**
