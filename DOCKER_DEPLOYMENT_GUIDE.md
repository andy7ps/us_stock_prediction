# 🐳 Docker Deployment Guide - Stock Prediction System v3.2.0

[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://docker.com)
[![Production](https://img.shields.io/badge/Production-Ready-success.svg)](#production-deployment)
[![Bootstrap](https://img.shields.io/badge/Bootstrap-5.3.3-purple.svg)](https://getbootstrap.com)
[![Angular](https://img.shields.io/badge/Angular-20+-red.svg)](https://angular.io)

> **Complete Docker deployment guide for the enterprise-grade stock prediction system with Bootstrap-enhanced frontend, Go backend, and comprehensive monitoring.**

## 🎯 **What This Guide Covers**

This guide provides complete instructions for deploying the Stock Prediction System using Docker containers with:

- **🎨 Bootstrap-Enhanced Frontend**: Angular 20+ with Bootstrap 5.3.3
- **🚀 Go Backend API**: High-performance ML prediction service
- **📊 Monitoring Stack**: Prometheus + Grafana dashboards
- **💾 Redis Caching**: High-performance data caching
- **🔄 Persistent Storage**: Zero data loss across restarts
- **🛡️ Production Security**: Secure, scalable architecture

## 📋 **Table of Contents**

- [Quick Start](#-quick-start)
- [System Architecture](#-system-architecture)
- [Prerequisites](#-prerequisites)
- [Deployment Options](#-deployment-options)
- [Production Deployment](#-production-deployment)
- [Development Deployment](#-development-deployment)
- [Service Management](#-service-management)
- [Monitoring & Observability](#-monitoring--observability)
- [Troubleshooting](#-troubleshooting)
- [Performance Tuning](#-performance-tuning)
- [Security Configuration](#-security-configuration)

## 🚀 **Quick Start**

### **Option 1: Production Deployment (Recommended)**

```bash
# 1. Clone and navigate to project
git clone <repository-url>
cd stock_prediction/v3

# 2. Deploy production system
./deploy_production.sh

# 3. Access services
# Frontend: http://localhost:8080
# Backend:  http://localhost:8081
# Grafana:  http://localhost:3000 (admin/admin)
```

### **Option 2: Development Deployment**

```bash
# 1. Start development environment
./deploy_production.sh --dev

# 2. Or use management script
./manage_system.sh start --dev
```

### **Option 3: Manual Docker Compose**

```bash
# Production
docker-compose -f docker-compose-production.yml up -d

# Development
docker-compose -f docker-compose.yml up -d
```

## 🏗️ **System Architecture**

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Web Browser   │───▶│  Nginx Proxy     │───▶│   Angular       │
│   (Port 80)     │    │  (Port 80)       │    │   Frontend      │
└─────────────────┘    └──────────────────┘    │   (Port 8080)   │
                                                └─────────────────┘
                                                         │
                       ┌─────────────────┐              │
                       │   Prometheus    │◀─────────────┤
                       │   (Port 9090)   │              │
                       └─────────────────┘              │
                                ▲                       ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │    Grafana      │    │   Go Backend    │
                       │   (Port 3000)   │    │   (Port 8081)   │
                       └─────────────────┘    └─────────────────┘
                                                         │
┌─────────────────┐    ┌──────────────────┐              │
│   Yahoo Finance │◀───│   ML Executor    │◀─────────────┤
│      API        │    │   (Python)       │              │
└─────────────────┘    └──────────────────┘              │
                                                         ▼
┌─────────────────┐                            ┌─────────────────┐
│  Persistent     │◀───────────────────────────│  Redis Cache    │
│  Data Storage   │                            │  (Port 6379)    │
└─────────────────┘                            └─────────────────┘
```

## 📦 **Prerequisites**

### **System Requirements**

- **OS**: Linux, macOS, or Windows with WSL2
- **RAM**: Minimum 4GB, Recommended 8GB+
- **Storage**: 10GB+ free space
- **CPU**: 2+ cores recommended

### **Software Requirements**

```bash
# Docker & Docker Compose
docker --version          # >= 20.10.0
docker-compose --version  # >= 1.29.0

# Optional tools
curl --version            # For API testing
jq --version             # For JSON formatting
```

### **Installation Commands**

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install docker.io docker-compose curl jq
sudo usermod -aG docker $USER

# CentOS/RHEL
sudo yum install docker docker-compose curl jq
sudo systemctl start docker
sudo usermod -aG docker $USER

# macOS (with Homebrew)
brew install docker docker-compose curl jq

# Start Docker daemon
sudo systemctl start docker
sudo systemctl enable docker
```

## 🚀 **Deployment Options**

### **1. Production Deployment**

**Features:**
- ✅ All services containerized
- ✅ Persistent data storage
- ✅ Health checks and auto-restart
- ✅ Production-grade security
- ✅ Monitoring and logging
- ✅ Redis caching
- ✅ Nginx reverse proxy (optional)

**Command:**
```bash
./deploy_production.sh
```

**Configuration File:** `docker-compose-production.yml`

### **2. Development Deployment**

**Features:**
- ✅ Hot reloading for development
- ✅ Debug logging enabled
- ✅ Development tools included
- ✅ Simplified configuration

**Command:**
```bash
./deploy_production.sh --dev
```

**Configuration File:** `docker-compose.yml`

### **3. Custom Deployment**

**Manual Docker Compose:**
```bash
# Custom project name
docker-compose -f docker-compose-production.yml -p my-stock-app up -d

# Specific services only
docker-compose -f docker-compose-production.yml up -d frontend stock-prediction redis

# With rebuild
docker-compose -f docker-compose-production.yml up -d --build
```

## 🏭 **Production Deployment**

### **Step 1: Prepare Environment**

```bash
# Clone repository
git clone <repository-url>
cd stock_prediction/v3

# Verify prerequisites
./deploy_production.sh --help
```

### **Step 2: Configure Environment**

```bash
# Copy and edit environment file
cp .env.example .env
nano .env

# Key configurations:
# SERVER_PORT=8081
# LOG_LEVEL=info
# REDIS_PASSWORD=your_secure_password
# STOCK_SYMBOLS=NVDA,TSLA,AAPL,MSFT
```

### **Step 3: Deploy System**

```bash
# Full production deployment
./deploy_production.sh

# With custom options
./deploy_production.sh --rebuild --verbose
```

### **Step 4: Verify Deployment**

```bash
# Check service status
./manage_system.sh status

# Test API endpoints
curl http://localhost:8081/api/v1/health
curl http://localhost:8081/api/v1/predict/NVDA

# Access web interface
open http://localhost:8080
```

### **Step 5: Configure Monitoring**

```bash
# Access Grafana
open http://localhost:3000
# Login: admin/admin

# Access Prometheus
open http://localhost:9090
```

## 🛠️ **Service Management**

### **Management Script Usage**

The `manage_system.sh` script provides comprehensive management capabilities for all Docker services. Here's the complete command reference:

#### **Basic Operations:**
```bash
./manage_system.sh start           # Start all services
./manage_system.sh stop            # Stop all services  
./manage_system.sh restart         # Restart all services
./manage_system.sh status          # Show service status with health checks
```

#### **Monitoring & Debugging:**
```bash
./manage_system.sh logs            # Show logs for all services
./manage_system.sh logs frontend   # Show logs for specific service
./manage_system.sh health          # Comprehensive health check with API tests
./manage_system.sh monitor         # Real-time resource monitoring
./manage_system.sh info            # System information and diagnostics
```

#### **Container Management:**
```bash
./manage_system.sh shell stock-prediction  # Open shell in backend container
./manage_system.sh shell frontend          # Open shell in frontend container
./manage_system.sh shell redis             # Open shell in Redis container
./manage_system.sh shell grafana           # Open shell in Grafana container
./manage_system.sh shell prometheus        # Open shell in Prometheus container
```

#### **Maintenance Operations:**
```bash
./manage_system.sh rebuild         # Rebuild all containers from scratch
./manage_system.sh cleanup         # Clean unused Docker resources
./manage_system.sh update          # Update to latest versions
```

#### **Backup & Recovery:**
```bash
./manage_system.sh backup          # Create timestamped system backup
./manage_system.sh restore backup.tar.gz  # Restore from specific backup file
```

#### **Testing & Validation:**
```bash
./manage_system.sh test            # Run comprehensive system tests
```

#### **Command Options:**
```bash
# Development mode (uses docker-compose.yml)
./manage_system.sh start --dev
./manage_system.sh restart --dev

# Force operations without confirmation
./manage_system.sh stop --force
./manage_system.sh cleanup --force

# Verbose output for debugging
./manage_system.sh logs --verbose
./manage_system.sh info --verbose

# Get help
./manage_system.sh --help
```

#### **Service-Specific Operations:**
```bash
# Restart individual services
./manage_system.sh restart frontend
./manage_system.sh restart stock-prediction

# View logs for specific services
./manage_system.sh logs stock-prediction
./manage_system.sh logs redis
./manage_system.sh logs prometheus
./manage_system.sh logs grafana
```

#### **Health Check Examples:**
```bash
# Quick status check
./manage_system.sh status

# Comprehensive health check with API testing
./manage_system.sh health

# Sample output from health check:
# Backend Health: ✅ {"status":"healthy","version":"v3.1.0"}
# Sample Prediction: ✅ {"symbol":"NVDA","predicted_price":180.50}
# Service Statistics: ✅ {"uptime":"2h30m","cache_hit_rate":0.85}
```

#### **Backup Management:**
```bash
# Create backup (automatically timestamped)
./manage_system.sh backup
# Creates: ./backups/stock_prediction_backup_20250811_153045.tar.gz

# List available backups
ls -lh ./backups/

# Restore from backup
./manage_system.sh restore ./backups/stock_prediction_backup_20250811_153045.tar.gz
```

#### **Resource Monitoring:**
```bash
# Real-time resource usage
./manage_system.sh monitor

# Sample output:
# CONTAINER         NAME                CPU %    MEM USAGE/LIMIT    MEM %    NET I/O      BLOCK I/O
# frontend          frontend            0.50%    45.2MiB/1GiB      4.52%    1.2kB/0B     0B/0B
# stock-prediction  backend             2.30%    180MiB/1GiB       18.0%    15kB/8kB     0B/4kB
# redis             cache               0.10%    12.5MiB/256MiB    4.88%    2kB/1kB      0B/0B
```

### **Available Services:**

| Service | Description | Shell Access |
|---------|-------------|--------------|
| `frontend` | Angular frontend with Bootstrap 5.3.3 | `./manage_system.sh shell frontend` |
| `stock-prediction` | Go backend API with ML predictions | `./manage_system.sh shell stock-prediction` |
| `redis` | Redis cache for high performance | `./manage_system.sh shell redis` |
| `prometheus` | Prometheus metrics collection | `./manage_system.sh shell prometheus` |
| `grafana` | Grafana dashboards and visualization | `./manage_system.sh shell grafana` |

### **Direct Docker Compose Commands**

```bash
# Using production config
COMPOSE_FILE="docker-compose-production.yml"
PROJECT_NAME="stock-prediction-prod"

# Start services
docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME up -d

# View logs
docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME logs -f

# Scale services
docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME up -d --scale stock-prediction=3

# Update services
docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME pull
docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME up -d
```

## 📊 **Monitoring & Observability**

### **Service Endpoints**

| Service | URL | Purpose |
|---------|-----|---------|
| Frontend | http://localhost:8080 | Bootstrap UI |
| Backend API | http://localhost:8081 | REST API |
| Prometheus | http://localhost:9090 | Metrics |
| Grafana | http://localhost:3000 | Dashboards |
| Redis | localhost:6379 | Cache |

### **Health Checks**

```bash
# Backend health
curl http://localhost:8081/api/v1/health

# Frontend health
curl http://localhost:8080/health

# Prometheus health
curl http://localhost:9090/-/healthy

# Grafana health
curl http://localhost:3000/api/health
```

### **Key Metrics**

- **API Response Time**: < 100ms (cached), < 2s (ML predictions)
- **Cache Hit Rate**: > 85%
- **Memory Usage**: < 500MB per service
- **CPU Usage**: < 50% under normal load

### **Grafana Dashboards**

1. **Application Dashboard**: Service performance and health
2. **ML Metrics Dashboard**: Prediction accuracy and model performance
3. **Infrastructure Dashboard**: System resources and Docker metrics
4. **Business Dashboard**: Stock prediction insights

## 🔧 **Troubleshooting**

### **Common Issues**

#### **1. Permission Denied Errors**

```bash
# Fix persistent data permissions
sudo chown -R 65534:65534 persistent_data/prometheus
sudo chown -R 472:472 persistent_data/grafana
sudo chown -R 999:999 persistent_data/redis
sudo chmod -R 755 persistent_data/
```

#### **2. Port Conflicts**

```bash
# Check port usage
sudo netstat -tlnp | grep :8080
sudo netstat -tlnp | grep :8081

# Stop conflicting services
sudo systemctl stop apache2
sudo systemctl stop nginx
```

#### **3. Docker Build Failures**

```bash
# Clean Docker cache
docker system prune -a

# Rebuild without cache
docker-compose -f docker-compose-production.yml build --no-cache

# Check Docker daemon
sudo systemctl status docker
sudo systemctl restart docker
```

#### **4. Service Health Check Failures**

```bash
# Check service logs
./manage_system.sh logs stock-prediction

# Restart specific service
docker-compose -f docker-compose-production.yml restart stock-prediction

# Check network connectivity
docker network ls
docker network inspect stock-prediction-prod_stock-prediction-network
```

### **Debug Commands**

```bash
# Container inspection
docker inspect stock-prediction-prod_stock-prediction_1

# Network debugging
docker exec -it stock-prediction-prod_stock-prediction_1 ping frontend

# Resource usage
docker stats

# System information
docker system df
docker system info
```

## ⚡ **Performance Tuning**

### **Resource Limits**

```yaml
# In docker-compose-production.yml
services:
  stock-prediction:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
```

### **Redis Optimization**

```bash
# Redis configuration
redis-cli CONFIG SET maxmemory 256mb
redis-cli CONFIG SET maxmemory-policy allkeys-lru
redis-cli CONFIG SET save "900 1 300 10 60 10000"
```

### **Nginx Optimization**

```nginx
# In nginx/nginx.conf
worker_processes auto;
worker_connections 2048;
keepalive_timeout 65;
gzip on;
gzip_comp_level 6;
```

## 🛡️ **Security Configuration**

### **Environment Variables**

```bash
# Secure passwords
REDIS_PASSWORD=your_very_secure_password_here
GRAFANA_ADMIN_PASSWORD=your_secure_admin_password

# API security
API_RATE_LIMIT=1000
CORS_ORIGINS=https://yourdomain.com

# SSL/TLS (production)
SSL_CERT_PATH=/etc/nginx/ssl/cert.pem
SSL_KEY_PATH=/etc/nginx/ssl/key.pem
```

### **Network Security**

```yaml
# Restrict external access
services:
  redis:
    ports: []  # Remove external port exposure
    expose:
      - "6379"
```

### **Container Security**

```yaml
# Run as non-root users
services:
  prometheus:
    user: "65534:65534"
  grafana:
    user: "472:472"
```

## 📚 **Additional Resources**

- **[Main README](README.md)** - Project overview and features
- **[API Documentation](API_DOCUMENTATION.md)** - REST API reference
- **[Bootstrap Guide](BOOTSTRAP_GUIDE.md)** - Frontend customization
- **[Monitoring Guide](MONITORING_GUIDE.md)** - Detailed monitoring setup
- **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Common issues and solutions

## 📋 **Quick Reference**

### **Essential Commands:**
```bash
# 🚀 Quick Start
./deploy_production.sh              # Deploy entire system
./manage_system.sh status           # Check system health
./test_docker_deployment.sh         # Validate deployment

# 🛠️ Daily Operations
./manage_system.sh start            # Start services
./manage_system.sh stop             # Stop services
./manage_system.sh logs             # View logs
./manage_system.sh health           # Health check

# 🔧 Maintenance
./manage_system.sh backup           # Create backup
./manage_system.sh cleanup          # Clean resources
./manage_system.sh update           # Update system

# 🐛 Debugging
./manage_system.sh shell stock-prediction  # Backend shell
./manage_system.sh logs frontend           # Frontend logs
./manage_system.sh monitor                 # Resource usage
```

### **Service URLs:**
```bash
Frontend:   http://localhost:8080    # Bootstrap UI
Backend:    http://localhost:8081    # REST API
Grafana:    http://localhost:3000    # Dashboards (admin/admin)
Prometheus: http://localhost:9090    # Metrics
```

### **Key API Endpoints:**
```bash
curl http://localhost:8081/api/v1/health           # Health check
curl http://localhost:8081/api/v1/predict/NVDA     # Stock prediction
curl http://localhost:8081/api/v1/historical/TSLA  # Historical data
curl http://localhost:8081/api/v1/stats            # Service stats
```

### **Configuration Files:**
```bash
docker-compose-production.yml       # Production configuration
docker-compose.yml                  # Development configuration
.env                                # Environment variables
nginx/nginx.conf                    # Reverse proxy config
monitoring/prometheus.yml           # Metrics configuration
```

### **Data Directories:**
```bash
persistent_data/ml_models/          # ML model files
persistent_data/grafana/            # Grafana data
persistent_data/prometheus/         # Metrics data
persistent_data/redis/              # Cache data
persistent_data/logs/               # Application logs
```

## 🤝 **Support**

- **Issues**: [GitHub Issues](https://github.com/your-repo/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-repo/discussions)
- **Documentation**: [Wiki](https://github.com/your-repo/wiki)

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Made with ❤️ for production-ready stock prediction**

**Happy Trading! 📈💰**
