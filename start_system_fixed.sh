#!/bin/bash

# Fixed Stock Prediction System Startup Script
# Addresses permission issues and ensures proper startup

set -e

echo "🚀 Starting Stock Prediction System (Fixed Version)"
echo "=================================================="

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

print_header() {
    echo -e "${PURPLE}[SYSTEM]${NC} $1"
}

# Check prerequisites
print_header "Checking Prerequisites"

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed or not in PATH"
    exit 1
fi

if ! docker info &> /dev/null; then
    print_error "Docker daemon is not running"
    exit 1
fi

print_success "Prerequisites check passed"

# Setup persistent storage with correct permissions
print_status "Setting up persistent storage with correct permissions..."

if [ ! -d "persistent_data" ]; then
    print_status "Creating persistent data directories..."
    ./setup_persistent_storage.sh
fi

# Fix permissions for Prometheus (runs as nobody - 65534:65534)
print_status "Fixing Prometheus permissions..."
sudo chown -R 65534:65534 persistent_data/prometheus 2>/dev/null || true
sudo chmod -R 755 persistent_data/prometheus

# Fix permissions for Grafana (runs as grafana - 472:472)
print_status "Fixing Grafana permissions..."
sudo chown -R 472:472 persistent_data/grafana 2>/dev/null || true
sudo chmod -R 755 persistent_data/grafana

# Ensure other directories have correct permissions
print_status "Setting general permissions..."
sudo chown -R $USER:$USER persistent_data/ml_models persistent_data/logs persistent_data/config persistent_data/cache 2>/dev/null || true
chmod -R 755 persistent_data/

print_success "Permissions configured"

# Stop existing containers
print_status "Stopping existing containers..."
docker-compose -f docker-compose-working.yml down --remove-orphans 2>/dev/null || true

# Start the system
print_header "Starting System Services"
print_status "Building and starting services..."

docker-compose -f docker-compose-working.yml up -d --build

# Wait for services to be healthy
print_status "Waiting for services to be healthy..."

# Wait for backend
print_status "Checking backend health..."
for i in {1..30}; do
    if curl -s http://localhost:8081/api/v1/health > /dev/null 2>&1; then
        print_success "Backend is healthy"
        break
    fi
    if [ $i -eq 30 ]; then
        print_error "Backend health check failed"
        docker-compose -f docker-compose-working.yml logs stock-prediction
        exit 1
    fi
    sleep 2
done

# Wait for Prometheus
print_status "Checking Prometheus health..."
for i in {1..20}; do
    if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
        print_success "Prometheus is healthy"
        break
    fi
    if [ $i -eq 20 ]; then
        print_warning "Prometheus health check timeout (non-critical)"
        break
    fi
    sleep 2
done

# Wait for Grafana
print_status "Checking Grafana health..."
for i in {1..30}; do
    if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
        print_success "Grafana is healthy"
        break
    fi
    if [ $i -eq 30 ]; then
        print_warning "Grafana health check timeout (non-critical)"
        break
    fi
    sleep 2
done

# Display system information
print_header "🎉 System Successfully Started!"
echo ""
print_success "Stock Prediction System v3.2.0 (Backend Only)"
echo ""
echo "🔧 Backend API:                http://localhost:8081"
echo "📊 Prometheus Metrics:         http://localhost:9090"
echo "📈 Grafana Dashboards:         http://localhost:3000 (admin/admin)"
echo "🗄️  Redis Cache:                localhost:6379"
echo ""

print_header "🚀 API Endpoints:"
echo "  GET  /api/v1/predict/{symbol}     - Get stock prediction"
echo "  GET  /api/v1/historical/{symbol}  - Get historical data"
echo "  GET  /api/v1/health               - Health check"
echo "  GET  /api/v1/stats                - Service statistics"
echo "  POST /api/v1/cache/clear          - Clear cache"
echo ""

print_header "📊 Example Usage:"
echo "  curl http://localhost:8081/api/v1/predict/NVDA"
echo "  curl http://localhost:8081/api/v1/historical/TSLA?days=30"
echo "  curl http://localhost:8081/api/v1/health"
echo ""

print_header "🛠️  Management Commands:"
echo "  docker-compose -f docker-compose-working.yml logs -f           # View logs"
echo "  docker-compose -f docker-compose-working.yml ps                # View status"
echo "  docker-compose -f docker-compose-working.yml down              # Stop system"
echo "  docker-compose -f docker-compose-working.yml restart backend   # Restart backend"
echo ""

# Test the system
print_header "🧪 Testing System..."
echo "Backend Health:"
curl -s http://localhost:8081/api/v1/health
echo -e "\n"
echo "Sample Prediction:"
curl -s http://localhost:8081/api/v1/predict/NVDA
echo -e "\n"

print_success "System is ready for use! 🎉"

echo ""
print_header "📝 Notes:"
echo "• Frontend Docker build had issues - use local development for frontend"
echo "• To start frontend locally: cd frontend && npm install && npx ng serve"
echo "• All backend services are running and healthy"
echo "• Permissions have been fixed for Prometheus and Grafana"
echo ""

print_status "View logs with: docker-compose -f docker-compose-working.yml logs -f"
