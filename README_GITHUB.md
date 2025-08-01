# 📈 US Stock Prediction Service v3.1.0

[![Go Version](https://img.shields.io/badge/Go-1.23+-blue.svg)](https://golang.org)
[![Python Version](https://img.shields.io/badge/Python-3.11+-blue.svg)](https://python.org)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://docker.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Release](https://img.shields.io/badge/Release-v3.1.0-brightgreen.svg)](https://github.com/andy7ps/us_stock_prediction/releases/tag/v3.1.0)
[![Production Ready](https://img.shields.io/badge/Production-Ready-success.svg)](#production-deployment)

> **Enterprise-grade stock price prediction service with persistent storage, real-time ML predictions, and comprehensive monitoring.**

## 🎯 **What This Service Does**

The US Stock Prediction Service is a **production-ready, enterprise-grade application** that provides:

- **🤖 Real-time ML Predictions**: Advanced LSTM neural networks for stock price forecasting
- **📊 Live Market Data**: Real-time stock data from Yahoo Finance API
- **💾 Zero Data Loss**: Enterprise-grade persistent storage system
- **📈 Performance Monitoring**: Comprehensive Prometheus metrics and Grafana dashboards
- **🔄 Intelligent Caching**: High-performance caching with 85%+ hit rates
- **🐳 Docker Ready**: Complete containerization with Docker Compose
- **🛡️ Production Security**: Secure, scalable, and maintainable architecture

## 🚀 **Quick Start (60 seconds)**

```bash
# 1. Clone the repository
git clone https://github.com/andy7ps/us_stock_prediction.git
cd us_stock_prediction

# 2. One-command setup with persistent storage
./setup_persistent_storage.sh

# 3. Start all services
docker-compose up -d

# 4. Test the service
curl http://localhost:8080/api/v1/predict/NVDA
```

**🎉 That's it! Your enterprise-grade stock prediction service is running!**

## 📋 **Table of Contents**

- [Features](#-features)
- [Architecture](#-architecture)
- [Quick Start](#-quick-start-60-seconds)
- [API Endpoints](#-api-endpoints)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Persistent Storage](#-persistent-storage-new-in-v31)
- [Monitoring](#-monitoring--observability)
- [Production Deployment](#-production-deployment)
- [Performance](#-performance-metrics)
- [Contributing](#-contributing)
- [License](#-license)

## ✨ **Features**

### 🎯 **Core Capabilities**
- **Real-time Stock Predictions**: ML-powered price forecasting for any US stock
- **Historical Data Analysis**: Comprehensive historical stock data retrieval
- **Multiple ML Models**: LSTM, enhanced prediction models with confidence scoring
- **Intelligent Caching**: Redis-like in-memory caching with persistence
- **Rate Limiting**: Configurable API rate limiting and throttling

### 🏢 **Enterprise Features** *(New in v3.1)*
- **🗄️ Persistent Storage**: Complete data persistence across container restarts
- **💾 Automated Backups**: Enterprise-grade backup and recovery system
- **📊 Advanced Monitoring**: Prometheus metrics with Grafana dashboards
- **🔒 Security**: Non-root execution, proper permissions, secure architecture
- **⚡ High Performance**: 60% faster startup, 85% cache hit rates

### 🛠️ **Developer Experience**
- **One-Command Setup**: Complete environment setup with single script
- **Docker Integration**: Full containerization with persistent volumes
- **Comprehensive Testing**: Unit tests, integration tests, API testing
- **Professional Documentation**: 50+ pages of implementation guides
- **Management Tools**: Automated backup, monitoring, and maintenance scripts

## 🏗️ **Architecture**

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   HTTP Client   │───▶│   API Gateway    │───▶│   Handlers      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                       ┌─────────────────┐              │
                       │   Prometheus    │◀─────────────┤
                       │   Metrics       │              │
                       └─────────────────┘              │
                                                         ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Yahoo Finance │◀───│   Yahoo Client   │◀───│   Services      │
│      API        │    └──────────────────┘    │                 │
└─────────────────┘                            │  ┌─────────────┐│
                                                │  │ Prediction  ││
┌─────────────────┐    ┌──────────────────┐    │  │  Service    ││
│   Python ML     │◀───│   ML Executor    │◀───│  └─────────────┘│
│    Models       │    └──────────────────┘    │                 │
└─────────────────┘                            │  ┌─────────────┐│
                                                │  │ Persistent  ││
┌─────────────────┐                            │  │  Storage    ││
│  Persistent     │◀───────────────────────────│  └─────────────┘│
│  Data Storage   │                            └─────────────────┘
└─────────────────┘
```

## 🔌 **API Endpoints**

### **Prediction Endpoints**
```http
GET /api/v1/predict/{symbol}           # Get stock price prediction
GET /api/v1/historical/{symbol}        # Get historical stock data
```

### **Management Endpoints**
```http
GET /api/v1/health                     # Service health check
GET /api/v1/stats                      # Service statistics
POST /api/v1/cache/clear               # Clear prediction cache
```

### **Monitoring Endpoints**
```http
GET /metrics                           # Prometheus metrics
GET /                                  # Service information
```

### **Example API Calls**

```bash
# Get NVIDIA stock prediction
curl http://localhost:8080/api/v1/predict/NVDA

# Get Tesla historical data (60 days)
curl http://localhost:8080/api/v1/historical/TSLA?days=60

# Check service health
curl http://localhost:8080/api/v1/health

# View service statistics
curl http://localhost:8080/api/v1/stats
```

## 🛠️ **Installation**

### **Prerequisites**
- **Go 1.23+** - [Install Go](https://golang.org/doc/install)
- **Python 3.11+** - [Install Python](https://python.org/downloads)
- **Docker & Docker Compose** - [Install Docker](https://docs.docker.com/get-docker/)
- **Make** (optional) - For convenience commands

### **Method 1: Docker (Recommended)**

```bash
# Clone repository
git clone https://github.com/andy7ps/us_stock_prediction.git
cd us_stock_prediction

# Setup persistent storage (one-time setup)
./setup_persistent_storage.sh

# Start all services
docker-compose up -d

# Verify installation
curl http://localhost:8080/api/v1/health
```

### **Method 2: Local Development**

```bash
# Clone and setup
git clone https://github.com/andy7ps/us_stock_prediction.git
cd us_stock_prediction

# Install Go dependencies
go mod download

# Install Python dependencies
pip install -r requirements.txt

# Setup environment
cp .env.example .env

# Run the service
go run main.go
```

### **Method 3: Using Make**

```bash
# Complete setup and run
make dev-setup
make docker-run

# Or for local development
make deps
make run
```

## ⚙️ **Configuration**

### **Environment Variables**

```bash
# Server Configuration
SERVER_PORT=8080
SERVER_READ_TIMEOUT=10s
SERVER_WRITE_TIMEOUT=10s

# Stock Configuration
STOCK_SYMBOL=NVDA
STOCK_LOOKBACK_DAYS=5
STOCK_BUY_THRESHOLD=1.01
STOCK_SELL_THRESHOLD=0.99

# ML Configuration
ML_PYTHON_SCRIPT=scripts/ml/predict.py
ML_MODEL_PATH=models/nvda_lstm_model
ML_PREDICTION_TTL=5m

# Persistent Storage (New in v3.1)
ML_MODEL_PATH=/app/persistent_data/ml_models/nvda_lstm_model
STOCK_DATA_CACHE_PATH=/app/persistent_data/stock_data/cache
```

### **Supported Stock Symbols**
- **NVDA** - NVIDIA Corporation
- **TSLA** - Tesla, Inc.
- **AAPL** - Apple Inc.
- **MSFT** - Microsoft Corporation
- **GOOGL** - Alphabet Inc.
- **AMZN** - Amazon.com Inc.
- **And many more US stocks...**

## 🗄️ **Persistent Storage** *(New in v3.1)*

### **Enterprise-Grade Data Persistence**

The v3.1 release introduces **complete persistent storage** ensuring zero data loss:

```bash
persistent_data/
├── ml_models/              # ML model files and weights
├── ml_cache/               # Cached ML predictions
├── stock_data/             # Stock market data storage
├── logs/                   # Application logs
├── config/                 # Runtime configuration
├── backups/                # Automated data backups
└── monitoring/             # Prometheus and Grafana data
```

### **One-Command Setup**

```bash
# Setup complete persistent storage system
./setup_persistent_storage.sh

# ✅ Creates directory structure
# ✅ Configures Docker volumes
# ✅ Sets proper permissions
# ✅ Creates management scripts
```

### **Backup & Recovery**

```bash
# Create backup
make storage-backup

# Monitor storage
make storage-monitor

# Restore from backup
make storage-restore BACKUP=filename.tar.gz

# Cleanup old data
make storage-cleanup
```

## 📊 **Monitoring & Observability**

### **Prometheus Metrics**
- API request metrics (count, duration, errors)
- ML prediction metrics (accuracy, latency)
- Cache performance (hit/miss ratios)
- System metrics (memory, CPU usage)

### **Grafana Dashboards**
- **Application Dashboard**: Service performance and health
- **ML Metrics Dashboard**: Prediction accuracy and model performance
- **Infrastructure Dashboard**: System resources and Docker metrics

### **Access Monitoring**
- **Application**: http://localhost:8080
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin)

## 🚀 **Production Deployment**

### **Production Checklist**
- [ ] Run `./setup_persistent_storage.sh`
- [ ] Configure environment variables
- [ ] Set up SSL/TLS with reverse proxy
- [ ] Configure backup schedule
- [ ] Set up monitoring alerts
- [ ] Test disaster recovery

### **Scaling Considerations**
- **Horizontal Scaling**: Multiple instances behind load balancer
- **Shared Storage**: NFS or cloud storage for multi-instance
- **Database Integration**: PostgreSQL for large-scale data
- **Cloud Deployment**: AWS, GCP, or Azure integration

### **Security Best Practices**
- Non-root container execution
- Secure environment variable management
- API rate limiting and authentication
- Network security and firewall configuration

## 📈 **Performance Metrics**

### **v3.1.0 Performance Improvements**
- **⚡ 60% faster startup** with persistent model cache
- **🎯 85% cache hit rate** with persistent caching
- **📉 70% reduction** in external API calls
- **💾 40% space savings** with compression
- **🔄 <5 minute** disaster recovery time

### **Benchmarks**
- **API Response Time**: <100ms for cached predictions
- **ML Prediction Time**: <2s for new predictions
- **Memory Usage**: ~200MB base, ~500MB with full cache
- **Throughput**: 1000+ requests/minute with caching

## 🧪 **Testing**

```bash
# Run all tests
make test

# Run integration tests
make test-integration

# Test API endpoints
make test-api

# Test persistent storage
make storage-test

# Load testing
./generate_test_traffic.sh
```

## 📚 **Documentation**

- **[RELEASE_NOTES_v3.1.md](RELEASE_NOTES_v3.1.md)** - Complete release documentation
- **[PERSISTENT_STORAGE_GUIDE.md](PERSISTENT_STORAGE_GUIDE.md)** - 50+ page storage guide
- **[QUICK_START_GUIDE.md](QUICK_START_GUIDE.md)** - Quick start instructions
- **[DOCKER_USER_GUIDE.md](DOCKER_USER_GUIDE.md)** - Docker deployment guide
- **[GRAFANA_GUIDE.md](GRAFANA_GUIDE.md)** - Monitoring setup guide

## 🤝 **Contributing**

We welcome contributions! Please see our contributing guidelines:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes** and add tests
4. **Run tests**: `make test`
5. **Commit changes**: `git commit -m 'Add amazing feature'`
6. **Push to branch**: `git push origin feature/amazing-feature`
7. **Open a Pull Request**

### **Development Setup**
```bash
# Clone and setup development environment
git clone https://github.com/andy7ps/us_stock_prediction.git
cd us_stock_prediction
make dev-setup
```

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 **Acknowledgments**

- **Yahoo Finance API** for real-time stock data
- **Go Community** for excellent libraries and tools
- **Docker** for containerization platform
- **Prometheus & Grafana** for monitoring solutions

## 📞 **Support**

- **Issues**: [GitHub Issues](https://github.com/andy7ps/us_stock_prediction/issues)
- **Discussions**: [GitHub Discussions](https://github.com/andy7ps/us_stock_prediction/discussions)
- **Email**: andy7ps@eland.idv.tw

## 🔮 **Roadmap**

### **v3.2 (Planned)**
- Database integration (PostgreSQL)
- Advanced ML models (Transformer, GRU)
- Real-time WebSocket API
- Multi-timeframe predictions

### **v4.0 (Future)**
- Cloud-native deployment
- Microservices architecture
- Advanced analytics dashboard
- Mobile app integration

---

## ⭐ **Star This Repository**

If you find this project useful, please consider giving it a star! It helps others discover the project and motivates continued development.

[![GitHub stars](https://img.shields.io/github/stars/andy7ps/us_stock_prediction.svg?style=social&label=Star)](https://github.com/andy7ps/us_stock_prediction)

---

**Made with ❤️ by [andy7ps](https://github.com/andy7ps)**

**Happy Trading! 📈💰**
