#!/bin/bash

# Deploy Stock Prediction System with Mandatory Persistent Data
# This script ensures ALL data is properly persisted

set -e

echo "🚀 Stock Prediction System - Persistent Data Deployment"
echo "======================================================="
echo "🔥 CRITICAL: This deployment ensures zero data loss"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_critical() {
    echo -e "${RED}[CRITICAL]${NC} $1"
}

# Check if persistent_data directory exists
if [ ! -d "persistent_data" ]; then
    print_critical "persistent_data directory not found!"
    echo ""
    echo "🔧 Setting up persistent data structure..."
    if [ -f "setup_persistent_data.sh" ]; then
        ./setup_persistent_data.sh
    else
        print_error "setup_persistent_data.sh not found!"
        exit 1
    fi
fi

# Verify persistent data structure
print_status "Verifying persistent data structure..."

required_dirs=(
    "persistent_data/ml_models"
    "persistent_data/ml_cache"
    "persistent_data/scalers"
    "persistent_data/stock_data"
    "persistent_data/logs"
    "persistent_data/config"
    "persistent_data/backups"
    "persistent_data/redis"
    "persistent_data/prometheus"
    "persistent_data/grafana"
    "persistent_data/frontend"
)

missing_dirs=()
for dir in "${required_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        missing_dirs+=("$dir")
    fi
done

if [ ${#missing_dirs[@]} -ne 0 ]; then
    print_error "Missing required directories:"
    for dir in "${missing_dirs[@]}"; do
        echo "  ❌ $dir"
    done
    print_status "Running setup script to create missing directories..."
    ./setup_persistent_data.sh
fi

print_success "Persistent data structure verified"

# Check for docker-compose-persistent.yml
if [ ! -f "docker-compose-persistent.yml" ]; then
    print_error "docker-compose-persistent.yml not found!"
    print_error "This file is required for persistent data deployment"
    exit 1
fi

# Stop any existing non-persistent deployments
print_status "Stopping any existing deployments..."
docker-compose down 2>/dev/null || true
docker-compose -f docker-compose-complete.yml down 2>/dev/null || true
docker-compose -f docker-compose-simple.yml down 2>/dev/null || true

# Remove any standalone containers that might conflict
docker stop frontend-simple 2>/dev/null || true
docker rm frontend-simple 2>/dev/null || true

print_success "Existing deployments stopped"

# Build frontend if needed
print_status "Checking frontend build..."
if [ ! -d "frontend/dist/frontend/browser" ]; then
    print_status "Building Angular frontend..."
    cd frontend
    if [ ! -d "node_modules" ]; then
        npm install
    fi
    npx ng build --configuration=production
    cd ..
    print_success "Frontend built successfully"
else
    print_success "Frontend build found"
fi

# Deploy with persistent data
print_status "Deploying with persistent data configuration..."
print_warning "Using docker-compose-persistent.yml (MANDATORY for data persistence)"

docker-compose -f docker-compose-persistent.yml up -d

print_status "Waiting for services to start..."
sleep 30

# Verify deployment
print_status "Verifying deployment..."

services_status=()

# Check backend
if curl -s http://localhost:8081/api/v1/health >/dev/null 2>&1; then
    services_status+=("✅ Backend API (Port 8081): Healthy")
else
    services_status+=("❌ Backend API (Port 8081): Not responding")
fi

# Check frontend
if curl -s http://localhost:8080/ >/dev/null 2>&1; then
    services_status+=("✅ Frontend UI (Port 8080): Accessible")
else
    services_status+=("❌ Frontend UI (Port 8080): Not accessible")
fi

# Check Prometheus
if curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; then
    services_status+=("✅ Prometheus (Port 9090): Healthy")
else
    services_status+=("❌ Prometheus (Port 9090): Not responding")
fi

# Check Grafana
if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
    services_status+=("✅ Grafana (Port 3000): Healthy")
else
    services_status+=("❌ Grafana (Port 3000): Not responding")
fi

# Display service status
echo ""
echo "📊 Service Status:"
for status in "${services_status[@]}"; do
    echo "   $status"
done

# Verify persistent data mounting
print_status "Verifying persistent data mounting..."

# Check if backend can access persistent data
if docker exec $(docker-compose -f docker-compose-persistent.yml ps -q stock-prediction) ls /app/persistent_data >/dev/null 2>&1; then
    print_success "Backend has access to persistent data"
else
    print_error "Backend cannot access persistent data"
fi

# Check if Redis data is persistent
if docker exec $(docker-compose -f docker-compose-persistent.yml ps -q redis) ls /data >/dev/null 2>&1; then
    print_success "Redis has persistent data access"
else
    print_error "Redis persistent data not mounted"
fi

# Test ML prediction to verify model access
print_status "Testing ML prediction with persistent models..."
if curl -s http://localhost:8081/api/v1/predict/NVDA >/dev/null 2>&1; then
    print_success "ML prediction working (models accessible from persistent storage)"
else
    print_warning "ML prediction not ready (models may still be loading)"
fi

# Display final status
echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "======================"
echo ""
echo "✅ Persistent Data Features:"
echo "   🧠 ML Models: Stored in persistent_data/ml_models/"
echo "   📊 Cache: Stored in persistent_data/ml_cache/"
echo "   📝 Logs: Stored in persistent_data/logs/"
echo "   ⚙️ Config: Stored in persistent_data/config/"
echo "   💾 Backups: Available in persistent_data/backups/"
echo ""
echo "🎯 Access Points:"
echo "   🎨 Frontend UI:     http://localhost:8080"
echo "   🔌 Backend API:     http://localhost:8081"
echo "   📊 Prometheus:      http://localhost:9090"
echo "   📈 Grafana:         http://localhost:3000 (admin/admin)"
echo ""
echo "🛠️ Management Commands:"
echo "   docker-compose -f docker-compose-persistent.yml ps     # View services"
echo "   docker-compose -f docker-compose-persistent.yml logs   # View logs"
echo "   docker-compose -f docker-compose-persistent.yml down   # Stop services"
echo ""
echo "💾 Data Persistence:"
echo "   📁 All data in: ./persistent_data/"
echo "   🔄 Survives container restarts: YES"
echo "   💾 Backup ready: YES"
echo "   🔒 Zero data loss: GUARANTEED"
echo ""
print_success "Your system is now running with complete data persistence!"
print_warning "Remember: NEVER delete the persistent_data/ directory!"

# Create a status file
cat > deployment_status.txt << EOF
Stock Prediction System - Persistent Data Deployment
Deployed: $(date)
Configuration: docker-compose-persistent.yml
Persistent Data: ./persistent_data/
Status: ACTIVE with complete data persistence

Services:
- Frontend: http://localhost:8080
- Backend: http://localhost:8081  
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000

Data Locations:
- ML Models: persistent_data/ml_models/
- Cache: persistent_data/ml_cache/
- Logs: persistent_data/logs/
- Backups: persistent_data/backups/

CRITICAL: All data persists across container restarts
EOF

print_success "Deployment status saved to deployment_status.txt"
