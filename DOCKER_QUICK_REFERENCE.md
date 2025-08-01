# Docker Quick Reference - Stock Prediction Service

## 🚀 Quick Commands

### Build & Run
```bash
# Build image
make docker-build

# Run container
docker run -d -p 8080:8080 --name stock-prediction stock-prediction:v3

# Run with Docker Compose (includes monitoring)
docker-compose up -d
```

### Test Service
```bash
# Health check
curl http://localhost:8080/api/v1/health

# Get prediction
curl http://localhost:8080/api/v1/predict/NVDA

# View stats
curl http://localhost:8080/api/v1/stats
```

### Docker Hub Upload
```bash
# Upload to Docker Hub
./upload_to_dockerhub.sh YOUR_USERNAME

# Or using make
make docker-push DOCKERHUB_USERNAME=YOUR_USERNAME
```

## 🔧 Management Commands

### Container Management
```bash
# List containers
docker ps

# View logs
docker logs -f stock-prediction

# Stop container
docker stop stock-prediction

# Remove container
docker rm stock-prediction

# Shell access
docker exec -it stock-prediction /bin/bash
```

### Image Management
```bash
# List images
docker images

# Remove image
docker rmi stock-prediction:v3

# Clean up unused images
docker image prune
```

### Docker Compose
```bash
# Start services
docker-compose up -d

# View status
docker-compose ps

# View logs
docker-compose logs -f stock-prediction

# Stop services
docker-compose down

# Rebuild and restart
docker-compose up --build -d
```

## 🌐 Service URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| Stock Prediction API | http://localhost:8080 | - |
| Health Check | http://localhost:8080/api/v1/health | - |
| Prometheus | http://localhost:9090 | - |
| Grafana | http://localhost:3000 | admin/admin |
| Metrics | http://localhost:8080/metrics | - |

## 🔍 Troubleshooting

### Check Container Health
```bash
# Container status
docker ps

# Health check status
docker inspect stock-prediction --format='{{.State.Health.Status}}'

# View logs
docker logs stock-prediction
```

### Debug Mode
```bash
# Run with debug logging
docker run -d -p 8080:8080 -e LOG_LEVEL=debug stock-prediction:v3

# Interactive mode
docker run -it --rm stock-prediction:v3
```

### Resource Monitoring
```bash
# Container resource usage
docker stats stock-prediction

# System resource usage
docker system df
```

## ⚙️ Environment Variables

### Common Settings
```bash
# Debug mode
-e LOG_LEVEL=debug

# Custom stock symbol
-e STOCK_SYMBOL=TSLA

# Custom port
-e SERVER_PORT=9000

# Cache TTL
-e ML_PREDICTION_TTL=10m
```

### Full Example
```bash
docker run -d -p 8080:8080 \
  -e LOG_LEVEL=info \
  -e STOCK_SYMBOL=AAPL \
  -e STOCK_LOOKBACK_DAYS=10 \
  -e ML_PREDICTION_TTL=5m \
  --name stock-prediction \
  stock-prediction:v3
```

## 📊 API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v1/health` | GET | Service health status |
| `/api/v1/predict/{symbol}` | GET | Stock price prediction |
| `/api/v1/historical/{symbol}` | GET | Historical stock data |
| `/api/v1/stats` | GET | Service statistics |
| `/api/v1/cache/clear` | POST | Clear prediction cache |
| `/metrics` | GET | Prometheus metrics |

## 🏷️ Image Tags

| Tag | Description |
|-----|-------------|
| `stock-prediction:v3` | Local build |
| `your-username/stock-prediction:v3` | Docker Hub version tag |
| `your-username/stock-prediction:latest` | Docker Hub latest |

## 📁 Volume Mounts

```bash
# Logs directory
-v $(pwd)/logs:/app/logs

# Models directory (read-only)
-v $(pwd)/models:/app/models:ro

# Configuration file
-v $(pwd)/config.json:/app/config.json:ro
```

## 🔒 Security

### Run as Non-Root
```bash
# Already configured in image
USER appuser
```

### Resource Limits
```bash
docker run -d \
  --memory=1g \
  --cpus=1.0 \
  --read-only \
  --tmpfs /tmp \
  stock-prediction:v3
```

### Network Isolation
```bash
# Create custom network
docker network create stock-net

# Run with custom network
docker run -d --network stock-net stock-prediction:v3
```

## 🚨 Emergency Commands

### Stop All Containers
```bash
docker stop $(docker ps -q)
```

### Clean Everything
```bash
# Stop and remove all containers
docker-compose down

# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune

# System cleanup
docker system prune -a
```

### Backup Data
```bash
# Backup logs
docker cp stock-prediction:/app/logs ./backup-logs

# Backup models
docker cp stock-prediction:/app/models ./backup-models
```

---

**💡 Tip**: Use `make help` to see all available Makefile targets!
