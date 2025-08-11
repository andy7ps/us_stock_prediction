#!/bin/bash

# 📈 US Stock Prediction Service - Full Stack Setup Script
# This script sets up the complete Angular + Go application

set -e

echo "🚀 Setting up US Stock Prediction Service Full Stack Application..."
echo "=================================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check prerequisites
print_status "Checking prerequisites..."

# Check Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Check Node.js (for local development)
if ! command -v node &> /dev/null; then
    print_warning "Node.js is not installed. This is only needed for local development."
else
    NODE_VERSION=$(node --version)
    print_success "Node.js found: $NODE_VERSION"
fi

print_success "Prerequisites check completed!"

# Setup persistent storage
print_status "Setting up persistent storage..."
if [ -f "./setup_persistent_storage.sh" ]; then
    chmod +x ./setup_persistent_storage.sh
    ./setup_persistent_storage.sh
    print_success "Persistent storage setup completed!"
else
    print_warning "Persistent storage setup script not found. Creating basic structure..."
    mkdir -p persistent_data/{ml_models,ml_cache,stock_data,logs,config,backups,monitoring,prometheus,grafana}
fi

# Build and start services
print_status "Building and starting services..."

# Stop any existing containers
print_status "Stopping existing containers..."
docker-compose down --remove-orphans 2>/dev/null || true

# Build and start all services
print_status "Building Docker images..."
docker-compose build --no-cache

print_status "Starting all services..."
docker-compose up -d

# Wait for services to be ready
print_status "Waiting for services to start..."
sleep 10

# Health checks
print_status "Performing health checks..."

# Check frontend
print_status "Checking frontend (port 8080)..."
for i in {1..30}; do
    if curl -f http://localhost:8080/health >/dev/null 2>&1; then
        print_success "Frontend is healthy!"
        break
    fi
    if [ $i -eq 30 ]; then
        print_error "Frontend health check failed after 30 attempts"
        exit 1
    fi
    sleep 2
done

# Check backend API
print_status "Checking backend API (port 8081)..."
for i in {1..30}; do
    if curl -f http://localhost:8081/api/v1/health >/dev/null 2>&1; then
        print_success "Backend API is healthy!"
        break
    fi
    if [ $i -eq 30 ]; then
        print_error "Backend API health check failed after 30 attempts"
        exit 1
    fi
    sleep 2
done

# Check Prometheus
print_status "Checking Prometheus (port 9090)..."
if curl -f http://localhost:9090/-/healthy >/dev/null 2>&1; then
    print_success "Prometheus is healthy!"
else
    print_warning "Prometheus health check failed, but continuing..."
fi

# Check Grafana
print_status "Checking Grafana (port 3000)..."
if curl -f http://localhost:3000/api/health >/dev/null 2>&1; then
    print_success "Grafana is healthy!"
else
    print_warning "Grafana health check failed, but continuing..."
fi

# Test API endpoint
print_status "Testing API endpoint..."
if curl -f http://localhost:8081/api/v1/predict/NVDA >/dev/null 2>&1; then
    print_success "API endpoint test passed!"
else
    print_warning "API endpoint test failed, but services are running..."
fi

# Display service information
echo ""
echo "🎉 Full Stack Application Setup Complete!"
echo "========================================"
echo ""
echo "📊 Service URLs:"
echo "  • Frontend (Angular):     http://localhost:8080"
echo "  • Backend API (Go):       http://localhost:8081"
echo "  • Prometheus Metrics:     http://localhost:9090"
echo "  • Grafana Dashboard:      http://localhost:3000 (admin/admin)"
echo ""
echo "📱 Mobile & PWA Features:"
echo "  • Responsive Design:      Optimized for mobile, tablet, and desktop"
echo "  • Touch-Friendly UI:      48px+ touch targets, swipe gestures"
echo "  • PWA Support:            Add to home screen, offline capabilities"
echo "  • Accessibility:          Screen reader support, ARIA labels"
echo "  • Performance:            Mobile-first CSS, optimized loading"
echo ""
echo "🔗 API Endpoints:"
echo "  • Stock Prediction:       http://localhost:8081/api/v1/predict/{symbol}"
echo "  • Historical Data:        http://localhost:8081/api/v1/historical/{symbol}"
echo "  • Health Check:           http://localhost:8081/api/v1/health"
echo "  • Service Stats:          http://localhost:8081/api/v1/stats"
echo ""
echo "🧪 Quick Test Commands:"
echo "  curl http://localhost:8081/api/v1/predict/NVDA"
echo "  curl http://localhost:8081/api/v1/historical/TSLA?days=30"
echo "  curl http://localhost:8081/api/v1/health"
echo ""
echo "📱 Popular Stock Symbols: NVDA, TSLA, AAPL, MSFT, GOOGL, AMZN, META, NFLX"
echo ""
echo "📱 Mobile Testing:"
echo "  • Chrome DevTools:        F12 → Device Toolbar → Select mobile device"
echo "  • Mobile Browser:         Access http://your-ip:8080 from mobile device"
echo "  • PWA Install:            Chrome → Menu → Add to Home Screen"
echo ""
echo "🛠️  Management Commands:"
echo "  • View logs:              docker-compose logs -f"
echo "  • Stop services:          docker-compose down"
echo "  • Restart services:       docker-compose restart"
echo "  • Update services:        docker-compose pull && docker-compose up -d"
echo ""
echo "📚 Documentation:"
echo "  • README.md - Complete documentation"
echo "  • QUICK_START_GUIDE.md - Quick start guide"
echo "  • DOCKER_USER_GUIDE.md - Docker usage guide"
echo ""

# Show running containers
print_status "Running containers:"
docker-compose ps

print_success "Setup completed successfully! 🚀"
print_status "Access your application at: http://localhost:8080"
