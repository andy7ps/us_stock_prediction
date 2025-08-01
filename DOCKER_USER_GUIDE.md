# Docker User Guide - Stock Prediction Service v3.0

This guide provides comprehensive instructions for building, running, and deploying the Stock Prediction Service using Docker.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Building the Docker Image](#building-the-docker-image)
- [Running the Container](#running-the-container)
- [Docker Compose Setup](#docker-compose-setup)
- [Uploading to Docker Hub](#uploading-to-docker-hub)
- [Configuration](#configuration)
- [Monitoring and Health Checks](#monitoring-and-health-checks)
- [Troubleshooting](#troubleshooting)
- [Production Deployment](#production-deployment)

## Prerequisites

Before you begin, ensure you have the following installed:

- **Docker**: Version 20.10 or later
- **Docker Compose**: Version 2.0 or later
- **Make**: For using Makefile commands (optional)
- **Git**: For cloning the repository

### Verify Installation

```bash
docker --version
docker-compose --version
make --version
```

## Quick Start

### 1. Clone and Build

```bash
# Clone the repository
git clone <repository-url>
cd stock-prediction-v3

# Build the Docker image
make docker-build
# OR
docker build -t stock-prediction:v3 .
```

### 2. Run the Service

```bash
# Run the container
docker run -d -p 8080:8080 --name stock-prediction stock-prediction:v3

# Test the service
curl http://localhost:8080/api/v1/health
```

### 3. Get Predictions

```bash
# Get a stock prediction
curl http://localhost:8080/api/v1/predict/NVDA

# Get historical data
curl http://localhost:8080/api/v1/historical/AAPL?days=30
```

## Building the Docker Image

### Method 1: Using Makefile (Recommended)

```bash
# Build the image
make docker-build

# View available make targets
make help
```

### Method 2: Direct Docker Build

```bash
# Build with default tag
docker build -t stock-prediction:v3 .

# Build with custom tag
docker build -t my-stock-predictor:latest .

# Build with build arguments
docker build --build-arg GO_VERSION=1.23 -t stock-prediction:v3 .
```

### Build Process Details

The Docker build uses a **multi-stage approach**:

1. **Builder Stage** (golang:1.23-alpine):
   - Compiles the Go application
   - Creates a static binary
   - Optimized for build speed

2. **Runtime Stage** (python:3.11-slim):
   - Installs Python ML dependencies
   - Copies the Go binary
   - Sets up non-root user
   - Configures health checks

### Build Output

```
Successfully built stock-prediction:v3
Image size: ~520MB
Architecture: linux/amd64
```

## Running the Container

### Basic Run

```bash
# Run in detached mode
docker run -d -p 8080:8080 --name stock-prediction stock-prediction:v3

# Run with custom port
docker run -d -p 9000:8080 --name stock-prediction stock-prediction:v3

# Run with environment variables
docker run -d -p 8080:8080 \
  -e LOG_LEVEL=debug \
  -e STOCK_SYMBOL=TSLA \
  --name stock-prediction \
  stock-prediction:v3
```

### Run with Volume Mounts

```bash
# Mount logs directory
docker run -d -p 8080:8080 \
  -v $(pwd)/logs:/app/logs \
  --name stock-prediction \
  stock-prediction:v3

# Mount models directory
docker run -d -p 8080:8080 \
  -v $(pwd)/models:/app/models:ro \
  -v $(pwd)/logs:/app/logs \
  --name stock-prediction \
  stock-prediction:v3
```

### Interactive Mode

```bash
# Run interactively for debugging
docker run -it --rm -p 8080:8080 stock-prediction:v3

# Override entrypoint for shell access
docker run -it --rm --entrypoint /bin/bash stock-prediction:v3
```

## Docker Compose Setup

### Basic Setup

```bash
# Start all services
docker-compose up -d

# View running services
docker-compose ps

# View logs
docker-compose logs -f stock-prediction

# Stop all services
docker-compose down
```

### Services Included

The Docker Compose setup includes:

1. **Stock Prediction Service** (Port 8080)
   - Main application
   - Health checks enabled
   - Volume mounts for logs and models

2. **Prometheus** (Port 9090)
   - Metrics collection
   - Scrapes application metrics
   - Data retention: 200h

3. **Grafana** (Port 3000)
   - Visualization dashboard
   - Default credentials: admin/admin
   - Pre-configured data sources

### Accessing Services

```bash
# Application
curl http://localhost:8080/api/v1/health

# Prometheus
open http://localhost:9090

# Grafana
open http://localhost:3000
```

### Custom Docker Compose

Create your own `docker-compose.override.yml`:

```yaml
version: '3.8'
services:
  stock-prediction:
    environment:
      - LOG_LEVEL=debug
      - STOCK_SYMBOL=AAPL
    ports:
      - "9000:8080"
    volumes:
      - ./custom-models:/app/models:ro
```

## Uploading to Docker Hub

### Prerequisites

1. **Docker Hub Account**: Create at https://hub.docker.com
2. **Login**: Authenticate with Docker Hub

```bash
docker login
```

### Method 1: Using Upload Script (Recommended)

```bash
# Make script executable
chmod +x upload_to_dockerhub.sh

# Upload to Docker Hub
./upload_to_dockerhub.sh YOUR_DOCKERHUB_USERNAME
```

### Method 2: Using Makefile

```bash
# Tag and push to Docker Hub
make docker-push DOCKERHUB_USERNAME=your-username
```

### Method 3: Manual Upload

```bash
# Tag the image
docker tag stock-prediction:v3 your-username/stock-prediction:v3
docker tag stock-prediction:v3 your-username/stock-prediction:latest

# Push to Docker Hub
docker push your-username/stock-prediction:v3
docker push your-username/stock-prediction:latest
```

### Verify Upload

```bash
# Pull your image from Docker Hub
docker pull your-username/stock-prediction:latest

# Run the pulled image
docker run -d -p 8080:8080 your-username/stock-prediction:latest
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_PORT` | `8080` | HTTP server port |
| `SERVER_READ_TIMEOUT` | `10s` | HTTP read timeout |
| `SERVER_WRITE_TIMEOUT` | `10s` | HTTP write timeout |
| `LOG_LEVEL` | `info` | Logging level (debug, info, warn, error) |
| `LOG_FORMAT` | `json` | Log format (json, text) |
| `STOCK_SYMBOL` | `NVDA` | Default stock symbol |
| `STOCK_LOOKBACK_DAYS` | `5` | Historical data lookback period |
| `STOCK_BUY_THRESHOLD` | `1.01` | Buy signal threshold |
| `STOCK_SELL_THRESHOLD` | `0.99` | Sell signal threshold |
| `STOCK_MAX_RETRIES` | `3` | Maximum API retry attempts |
| `STOCK_REQUESTS_PER_SEC` | `10` | Rate limiting for stock API |
| `API_TIMEOUT` | `30s` | External API timeout |
| `API_USER_AGENT` | `StockPredictor/3.0` | User agent for API requests |
| `ML_PYTHON_SCRIPT` | `scripts/ml/predict.py` | Python ML script path |
| `ML_MODEL_PATH` | `models/nvda_lstm_model` | ML model file path |
| `ML_SCALER_PATH` | `models/scaler.pkl` | ML scaler file path |
| `ML_PREDICTION_TTL` | `5m` | Prediction cache TTL |

### Configuration File

You can also use a JSON configuration file:

```bash
# Set config file path
docker run -d -p 8080:8080 \
  -e CONFIG_FILE=/app/config/config.json \
  -v $(pwd)/config.json:/app/config/config.json:ro \
  stock-prediction:v3
```

Example `config.json`:

```json
{
  "server": {
    "port": 8080,
    "read_timeout": "10s",
    "write_timeout": "10s"
  },
  "stock": {
    "symbol": "NVDA",
    "lookback_days": 5,
    "buy_threshold": 1.01,
    "sell_threshold": 0.99
  },
  "logging": {
    "level": "info",
    "format": "json"
  }
}
```

## Monitoring and Health Checks

### Health Check Endpoint

```bash
# Check service health
curl http://localhost:8080/api/v1/health

# Expected response
{
  "status": "healthy",
  "timestamp": "2025-07-31T08:49:14Z",
  "version": "v3.0",
  "services": {
    "prediction_service": "healthy",
    "yahoo_api": "healthy"
  }
}
```

### Docker Health Checks

The container includes built-in health checks:

```bash
# View container health status
docker ps

# View health check logs
docker inspect stock-prediction --format='{{.State.Health.Status}}'
```

### Prometheus Metrics

Access metrics at: `http://localhost:8080/metrics`

Key metrics include:
- `http_requests_total` - Total HTTP requests
- `prediction_requests_total` - Total prediction requests
- `cache_hits_total` - Cache hit count
- `stock_api_requests_total` - Stock API requests
- `prediction_accuracy` - Prediction accuracy metrics

### Service Statistics

```bash
# Get service statistics
curl http://localhost:8080/api/v1/stats

# Response includes cache info, request counts, uptime
{
  "uptime": "1h30m45s",
  "requests_served": 1250,
  "cache_size": 45,
  "cache_hit_ratio": 0.78,
  "active_connections": 3
}
```

## Troubleshooting

### Common Issues

#### 1. Container Won't Start

```bash
# Check container logs
docker logs stock-prediction

# Check container status
docker ps -a

# Common causes:
# - Port already in use
# - Missing environment variables
# - Invalid configuration
```

#### 2. Health Check Failures

```bash
# Check health endpoint manually
curl -v http://localhost:8080/api/v1/health

# Check container health status
docker inspect stock-prediction --format='{{.State.Health}}'

# Common causes:
# - Service not fully started
# - Network connectivity issues
# - Missing dependencies
```

#### 3. Python Script Errors

```bash
# Check if Python dependencies are installed
docker exec stock-prediction python3 -c "import numpy, pandas, sklearn, joblib"

# Test ML script manually
docker exec stock-prediction python3 scripts/ml/predict.py "100,101,102,103,104"

# Common causes:
# - Missing Python packages
# - Incorrect script path
# - Model file not found
```

#### 4. Memory Issues

```bash
# Check container resource usage
docker stats stock-prediction

# Set memory limits
docker run -d -p 8080:8080 --memory=1g stock-prediction:v3

# Monitor cache size
curl http://localhost:8080/api/v1/stats | jq '.cache_size'
```

### Debug Mode

```bash
# Run with debug logging
docker run -d -p 8080:8080 \
  -e LOG_LEVEL=debug \
  --name stock-prediction-debug \
  stock-prediction:v3

# View debug logs
docker logs -f stock-prediction-debug
```

### Container Shell Access

```bash
# Access running container
docker exec -it stock-prediction /bin/bash

# Run new container with shell
docker run -it --rm stock-prediction:v3 /bin/bash
```

## Production Deployment

### Security Best Practices

1. **Use Non-Root User** (Already implemented)
2. **Limit Resources**:
   ```bash
   docker run -d \
     --memory=1g \
     --cpus=1.0 \
     --read-only \
     --tmpfs /tmp \
     stock-prediction:v3
   ```

3. **Network Security**:
   ```bash
   # Create custom network
   docker network create stock-prediction-net
   
   # Run with custom network
   docker run -d --network stock-prediction-net stock-prediction:v3
   ```

### Scaling

#### Horizontal Scaling

```bash
# Run multiple instances
docker run -d -p 8081:8080 --name stock-prediction-1 stock-prediction:v3
docker run -d -p 8082:8080 --name stock-prediction-2 stock-prediction:v3
docker run -d -p 8083:8080 --name stock-prediction-3 stock-prediction:v3
```

#### Load Balancer (nginx)

```yaml
# docker-compose.yml
version: '3.8'
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - stock-prediction-1
      - stock-prediction-2

  stock-prediction-1:
    image: stock-prediction:v3
    expose:
      - "8080"

  stock-prediction-2:
    image: stock-prediction:v3
    expose:
      - "8080"
```

### Kubernetes Deployment

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stock-prediction
spec:
  replicas: 3
  selector:
    matchLabels:
      app: stock-prediction
  template:
    metadata:
      labels:
        app: stock-prediction
    spec:
      containers:
      - name: stock-prediction
        image: your-username/stock-prediction:v3
        ports:
        - containerPort: 8080
        env:
        - name: LOG_LEVEL
          value: "info"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /api/v1/health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /api/v1/health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

### Backup and Recovery

```bash
# Backup models and data
docker run --rm -v stock-prediction-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/backup.tar.gz /data

# Restore from backup
docker run --rm -v stock-prediction-data:/data -v $(pwd):/backup \
  alpine tar xzf /backup/backup.tar.gz -C /
```

### Logging

```bash
# Configure log rotation
docker run -d \
  --log-driver=json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  stock-prediction:v3

# Send logs to external system
docker run -d \
  --log-driver=syslog \
  --log-opt syslog-address=tcp://logserver:514 \
  stock-prediction:v3
```

## Makefile Reference

Available make targets:

```bash
make help              # Show all available targets
make deps              # Install Go dependencies
make build             # Build Go binary
make run               # Run locally
make test              # Run tests
make docker-build      # Build Docker image
make docker-run        # Run with Docker Compose
make docker-stop       # Stop Docker Compose
make docker-logs       # View Docker logs
make docker-clean      # Clean Docker resources
make docker-push       # Push to Docker Hub
make docker-tag        # Tag for Docker Hub
```

## Support and Resources

- **GitHub Repository**: [Your Repository URL]
- **Docker Hub**: [Your Docker Hub Repository]
- **Issues**: [GitHub Issues URL]
- **Documentation**: [Additional Documentation]

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Last Updated**: July 31, 2025
**Version**: 3.0
**Docker Image Size**: ~520MB
