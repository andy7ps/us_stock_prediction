# Docker Troubleshooting Guide - Stock Prediction Service

## 🚨 Common Issues and Solutions

### 1. Container Won't Start

#### Symptoms
- Container exits immediately
- `docker ps` shows no running containers
- Exit code 1 or 125

#### Diagnosis
```bash
# Check container status
docker ps -a

# View container logs
docker logs stock-prediction

# Check exit code
docker inspect stock-prediction --format='{{.State.ExitCode}}'
```

#### Solutions

**Port Already in Use**
```bash
# Check what's using port 8080
sudo netstat -tulpn | grep :8080
# or
sudo lsof -i :8080

# Use different port
docker run -d -p 9000:8080 stock-prediction:v3
```

**Missing Environment Variables**
```bash
# Run with required environment variables
docker run -d -p 8080:8080 \
  -e LOG_LEVEL=info \
  -e STOCK_SYMBOL=NVDA \
  stock-prediction:v3
```

**Permission Issues**
```bash
# Check if running as root is needed
sudo docker run -d -p 8080:8080 stock-prediction:v3

# Or fix Docker permissions
sudo usermod -aG docker $USER
# Then logout and login again
```

### 2. Health Check Failures

#### Symptoms
- Container shows "unhealthy" status
- Health check endpoint returns errors
- Service appears down

#### Diagnosis
```bash
# Check health status
docker inspect stock-prediction --format='{{.State.Health.Status}}'

# View health check logs
docker inspect stock-prediction --format='{{range .State.Health.Log}}{{.Output}}{{end}}'

# Test health endpoint manually
curl -v http://localhost:8080/api/v1/health
```

#### Solutions

**Service Not Ready**
```bash
# Wait for service to fully start (30-60 seconds)
sleep 60
curl http://localhost:8080/api/v1/health

# Check startup logs
docker logs stock-prediction | grep -i "starting\|ready\|listening"
```

**Network Issues**
```bash
# Test from inside container
docker exec stock-prediction wget -qO- http://localhost:8080/api/v1/health

# Check port binding
docker port stock-prediction
```

**Dependencies Missing**
```bash
# Check Python dependencies
docker exec stock-prediction python3 -c "import numpy, pandas, sklearn, joblib"

# Check Go binary
docker exec stock-prediction ls -la /app/main
```

### 3. Python/ML Script Errors

#### Symptoms
- Predictions return errors
- ML script not found
- Import errors in logs

#### Diagnosis
```bash
# Check Python installation
docker exec stock-prediction python3 --version

# Test ML script manually
docker exec stock-prediction python3 scripts/ml/predict.py "100,101,102,103,104"

# Check file permissions
docker exec stock-prediction ls -la scripts/ml/
```

#### Solutions

**Script Not Found**
```bash
# Check if script exists
docker exec stock-prediction find /app -name "predict.py"

# Copy script if missing
docker cp ./scripts/ml/predict.py stock-prediction:/app/scripts/ml/
```

**Python Dependencies Missing**
```bash
# Install missing packages
docker exec stock-prediction pip install numpy pandas scikit-learn joblib

# Or rebuild image
docker build --no-cache -t stock-prediction:v3 .
```

**Model Files Missing**
```bash
# Check model files
docker exec stock-prediction ls -la models/

# Mount models directory
docker run -d -p 8080:8080 \
  -v $(pwd)/models:/app/models:ro \
  stock-prediction:v3
```

### 4. Memory and Performance Issues

#### Symptoms
- Container killed (OOMKilled)
- Slow response times
- High CPU usage

#### Diagnosis
```bash
# Check resource usage
docker stats stock-prediction

# Check memory limits
docker inspect stock-prediction --format='{{.HostConfig.Memory}}'

# Monitor system resources
htop
# or
top
```

#### Solutions

**Increase Memory Limit**
```bash
# Run with more memory
docker run -d -p 8080:8080 --memory=2g stock-prediction:v3

# Check current memory usage
docker exec stock-prediction cat /proc/meminfo | grep MemAvailable
```

**Optimize Cache Settings**
```bash
# Reduce cache TTL
docker run -d -p 8080:8080 \
  -e ML_PREDICTION_TTL=1m \
  stock-prediction:v3

# Clear cache manually
curl -X POST http://localhost:8080/api/v1/cache/clear
```

**CPU Limits**
```bash
# Limit CPU usage
docker run -d -p 8080:8080 --cpus=1.0 stock-prediction:v3
```

### 5. Network and Connectivity Issues

#### Symptoms
- Cannot access service from host
- API calls timeout
- Connection refused errors

#### Diagnosis
```bash
# Check port mapping
docker port stock-prediction

# Test from host
curl -v http://localhost:8080/api/v1/health

# Test from container
docker exec stock-prediction curl -v http://localhost:8080/api/v1/health

# Check firewall
sudo ufw status
```

#### Solutions

**Port Mapping Issues**
```bash
# Ensure correct port mapping
docker run -d -p 8080:8080 stock-prediction:v3

# Use different host port
docker run -d -p 9000:8080 stock-prediction:v3
```

**Firewall Blocking**
```bash
# Allow port through firewall
sudo ufw allow 8080

# Or disable firewall temporarily
sudo ufw disable
```

**Network Configuration**
```bash
# Create custom network
docker network create stock-net
docker run -d --network stock-net -p 8080:8080 stock-prediction:v3

# Check network connectivity
docker exec stock-prediction ping google.com
```

### 6. Docker Compose Issues

#### Symptoms
- Services won't start together
- Dependency issues
- Volume mount problems

#### Diagnosis
```bash
# Check compose status
docker-compose ps

# View all logs
docker-compose logs

# Check specific service
docker-compose logs stock-prediction
```

#### Solutions

**Service Dependencies**
```bash
# Start services in order
docker-compose up -d stock-prediction
sleep 30
docker-compose up -d prometheus grafana
```

**Volume Issues**
```bash
# Check volume mounts
docker-compose config

# Fix permissions
sudo chown -R 1001:1001 ./models ./logs
```

**Port Conflicts**
```bash
# Check for port conflicts
docker-compose down
docker-compose up -d
```

### 7. Docker Hub Upload Issues

#### Symptoms
- Authentication failures
- Push denied
- Image not found

#### Diagnosis
```bash
# Check login status
docker info | grep Username

# Verify image exists
docker images | grep stock-prediction

# Check repository permissions
docker push your-username/stock-prediction:v3
```

#### Solutions

**Authentication Issues**
```bash
# Re-login to Docker Hub
docker logout
docker login

# Use token authentication
docker login -u your-username --password-stdin
```

**Image Tagging Issues**
```bash
# Correct tagging
docker tag stock-prediction:v3 your-username/stock-prediction:v3
docker tag stock-prediction:v3 your-username/stock-prediction:latest

# Verify tags
docker images | grep your-username
```

**Repository Issues**
```bash
# Create repository on Docker Hub first
# Then push
docker push your-username/stock-prediction:v3
```

## 🔧 Debug Tools and Commands

### Container Inspection
```bash
# Full container details
docker inspect stock-prediction

# Specific information
docker inspect stock-prediction --format='{{.State.Status}}'
docker inspect stock-prediction --format='{{.NetworkSettings.IPAddress}}'
docker inspect stock-prediction --format='{{.Mounts}}'
```

### Log Analysis
```bash
# Follow logs in real-time
docker logs -f stock-prediction

# Show last 100 lines
docker logs --tail 100 stock-prediction

# Show logs since specific time
docker logs --since 2025-07-31T08:00:00 stock-prediction

# Filter logs
docker logs stock-prediction 2>&1 | grep ERROR
```

### Process Monitoring
```bash
# Show running processes in container
docker exec stock-prediction ps aux

# Show resource usage
docker stats --no-stream stock-prediction

# Show port usage
docker exec stock-prediction netstat -tulpn
```

### File System Debugging
```bash
# List files in container
docker exec stock-prediction ls -la /app

# Check disk usage
docker exec stock-prediction df -h

# Find files
docker exec stock-prediction find /app -name "*.py"

# Check file permissions
docker exec stock-prediction ls -la /app/scripts/ml/
```

### Network Debugging
```bash
# Test network connectivity
docker exec stock-prediction ping google.com
docker exec stock-prediction curl -v http://finance.yahoo.com

# Check DNS resolution
docker exec stock-prediction nslookup google.com

# Show network configuration
docker exec stock-prediction ip addr show
```

## 🚨 Emergency Recovery

### Complete Reset
```bash
# Stop all containers
docker stop $(docker ps -q)

# Remove all containers
docker rm $(docker ps -aq)

# Remove all images
docker rmi $(docker images -q)

# Clean system
docker system prune -a --volumes
```

### Backup Before Reset
```bash
# Backup important data
docker cp stock-prediction:/app/logs ./backup-logs
docker cp stock-prediction:/app/models ./backup-models

# Export container
docker export stock-prediction > stock-prediction-backup.tar
```

### Recovery from Backup
```bash
# Import container
docker import stock-prediction-backup.tar stock-prediction:backup

# Restore data
docker cp ./backup-logs stock-prediction:/app/logs
docker cp ./backup-models stock-prediction:/app/models
```

## 📞 Getting Help

### Collect Debug Information
```bash
# System information
docker version
docker info
docker-compose version

# Container information
docker ps -a
docker images
docker logs stock-prediction

# System resources
free -h
df -h
```

### Create Debug Report
```bash
#!/bin/bash
echo "=== Docker Debug Report ===" > debug-report.txt
echo "Date: $(date)" >> debug-report.txt
echo "" >> debug-report.txt

echo "=== Docker Version ===" >> debug-report.txt
docker version >> debug-report.txt
echo "" >> debug-report.txt

echo "=== Container Status ===" >> debug-report.txt
docker ps -a >> debug-report.txt
echo "" >> debug-report.txt

echo "=== Container Logs ===" >> debug-report.txt
docker logs stock-prediction >> debug-report.txt
echo "" >> debug-report.txt

echo "=== System Resources ===" >> debug-report.txt
free -h >> debug-report.txt
df -h >> debug-report.txt
```

### Support Channels
- **GitHub Issues**: Report bugs and issues
- **Docker Hub**: Check image status
- **Stack Overflow**: Community support
- **Docker Documentation**: Official guides

---

**💡 Pro Tip**: Always check the logs first - they contain the most valuable debugging information!
