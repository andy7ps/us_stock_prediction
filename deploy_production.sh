#!/bin/bash

# Production Deployment Script for Stock Prediction System v3.2.0
# Complete Docker deployment with all services

set -e

echo "🚀 Deploying Stock Prediction System v3.2.0 (Production)"
echo "=========================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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
    echo -e "${PURPLE}[DEPLOY]${NC} $1"
}

print_feature() {
    echo -e "${CYAN}  ✨${NC} $1"
}

# Configuration
COMPOSE_FILE="docker-compose-production.yml"
PROJECT_NAME="stock-prediction-prod"
BOOTSTRAP_VERSION="5.3.3"
ANGULAR_VERSION="20.1.0"
GO_VERSION="1.23"

# Parse command line arguments
REBUILD="false"
VERBOSE="false"
SKIP_HEALTH_CHECK="false"
DETACHED="true"
ENVIRONMENT="production"

while [[ $# -gt 0 ]]; do
    case $1 in
        --rebuild)
            REBUILD="true"
            shift
            ;;
        --verbose)
            VERBOSE="true"
            shift
            ;;
        --no-detach)
            DETACHED="false"
            shift
            ;;
        --skip-health)
            SKIP_HEALTH_CHECK="true"
            shift
            ;;
        --dev)
            ENVIRONMENT="development"
            COMPOSE_FILE="docker-compose.yml"
            PROJECT_NAME="stock-prediction-dev"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --rebuild       Force rebuild of all containers"
            echo "  --verbose       Enable verbose output"
            echo "  --no-detach     Run in foreground (don't detach)"
            echo "  --skip-health   Skip health checks"
            echo "  --dev           Use development configuration"
            echo "  -h, --help      Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_header "Environment: $ENVIRONMENT"
print_header "Compose File: $COMPOSE_FILE"
print_header "Project Name: $PROJECT_NAME"

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

# Check Docker daemon
if ! docker info &> /dev/null; then
    print_error "Docker daemon is not running"
    exit 1
fi

print_success "Prerequisites check passed"

# Verify project structure
print_status "Verifying project structure..."

required_files=(
    "$COMPOSE_FILE"
    "Dockerfile"
    "frontend/Dockerfile"
    "frontend/package.json"
    "main.go"
    "go.mod"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        print_error "Required file not found: $file"
        exit 1
    fi
done

print_success "Project structure verified"

# Setup persistent storage with correct permissions
print_status "Setting up persistent storage..."

if [ ! -d "persistent_data" ]; then
    print_status "Creating persistent data directories..."
    ./setup_persistent_storage.sh
fi

# Create additional directories for production
mkdir -p persistent_data/{frontend/logs,nginx/logs,cache,backups}

# Fix permissions for all services
print_status "Configuring permissions for all services..."

# Prometheus (runs as nobody - 65534:65534)
sudo chown -R 65534:65534 persistent_data/prometheus 2>/dev/null || true
sudo chmod -R 755 persistent_data/prometheus

# Grafana (runs as grafana - 472:472)  
sudo chown -R 472:472 persistent_data/grafana 2>/dev/null || true
sudo chmod -R 755 persistent_data/grafana

# Redis (runs as redis - 999:999)
sudo chown -R 999:999 persistent_data/redis 2>/dev/null || true
sudo chmod -R 755 persistent_data/redis

# Frontend/Nginx (runs as nginx - 101:101)
sudo chown -R 101:101 persistent_data/frontend 2>/dev/null || true
sudo chmod -R 755 persistent_data/frontend

# General directories
sudo chown -R $USER:$USER persistent_data/{ml_models,logs,config,cache,backups,scalers} 2>/dev/null || true
chmod -R 755 persistent_data/

print_success "Permissions configured"

# Stop existing containers
print_status "Stopping existing containers..."
docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME down --remove-orphans 2>/dev/null || true

# Build/rebuild containers if requested
if [ "$REBUILD" = "true" ]; then
    print_status "Rebuilding all containers..."
    docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME build --no-cache
else
    print_status "Building containers (using cache)..."
    docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME build
fi

# Start the system
print_header "Starting Production System"

if [ "$DETACHED" = "true" ]; then
    print_status "Starting services in detached mode..."
    docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME up -d
else
    print_status "Starting services in foreground mode..."
    docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME up
    exit 0
fi

# Wait for services to be healthy
if [ "$SKIP_HEALTH_CHECK" = "false" ]; then
    print_status "Waiting for services to be healthy..."
    
    # Wait for Redis
    print_status "Checking Redis health..."
    for i in {1..30}; do
        if docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME exec -T redis redis-cli -a stockprediction2025 ping > /dev/null 2>&1; then
            print_success "Redis is healthy"
            break
        fi
        if [ $i -eq 30 ]; then
            print_warning "Redis health check timeout (non-critical)"
            break
        fi
        sleep 2
    done
    
    # Wait for Prometheus
    print_status "Checking Prometheus health..."
    for i in {1..30}; do
        if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
            print_success "Prometheus is healthy"
            break
        fi
        if [ $i -eq 30 ]; then
            print_warning "Prometheus health check timeout (non-critical)"
            break
        fi
        sleep 2
    done
    
    # Wait for backend
    print_status "Checking backend health..."
    for i in {1..60}; do
        if curl -s http://localhost:8081/api/v1/health > /dev/null 2>&1; then
            print_success "Backend is healthy"
            break
        fi
        if [ $i -eq 60 ]; then
            print_error "Backend health check failed"
            docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME logs stock-prediction
            exit 1
        fi
        sleep 2
    done
    
    # Wait for frontend
    print_status "Checking frontend health..."
    for i in {1..45}; do
        if curl -s http://localhost:8080/health > /dev/null 2>&1; then
            print_success "Frontend is healthy"
            break
        fi
        if [ $i -eq 45 ]; then
            print_error "Frontend health check failed"
            docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME logs frontend
            exit 1
        fi
        sleep 2
    done
    
    # Wait for Grafana
    print_status "Checking Grafana health..."
    for i in {1..45}; do
        if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
            print_success "Grafana is healthy"
            break
        fi
        if [ $i -eq 45 ]; then
            print_warning "Grafana health check timeout (non-critical)"
            break
        fi
        sleep 2
    done
fi

# Display system information
print_header "🎉 Production System Successfully Deployed!"
echo ""
print_success "Stock Prediction System v3.2.0 (Production Ready)"
echo ""
echo "🌐 Service Endpoints:"
echo "   Frontend (Bootstrap UI):    http://localhost:8080"
echo "   Backend API:                http://localhost:8081"
echo "   Prometheus Metrics:         http://localhost:9090"
echo "   Grafana Dashboards:         http://localhost:3000 (admin/admin)"
echo "   Redis Cache:                localhost:6379"
echo ""

print_header "🎨 Production Features:"
print_feature "Bootstrap $BOOTSTRAP_VERSION with professional UI"
print_feature "Angular $ANGULAR_VERSION with TypeScript"
print_feature "Go $GO_VERSION backend with ML predictions"
print_feature "Redis caching for high performance"
print_feature "Prometheus monitoring with metrics"
print_feature "Grafana dashboards with visualizations"
print_feature "Persistent data storage"
print_feature "Health checks and auto-restart"
print_feature "Production-grade security"
print_feature "Scalable Docker architecture"
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
echo "  docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME logs -f           # View logs"
echo "  docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME ps                # View status"
echo "  docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME down              # Stop system"
echo "  docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME restart frontend  # Restart service"
echo "  docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME exec stock-prediction /bin/bash  # Shell access"
echo ""

if [ "$VERBOSE" = "true" ]; then
    print_header "📋 Container Status:"
    docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME ps
    echo ""
    
    print_header "📊 Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
    echo ""
    
    print_header "🔍 Service Health:"
    echo "Backend Health:"
    curl -s http://localhost:8081/api/v1/health | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8081/api/v1/health
    echo ""
fi

print_success "Production deployment completed successfully! 🎉"

# Test the system
print_header "🧪 System Verification:"
echo "Testing API endpoints..."
echo ""

# Test health
echo "Health Check:"
curl -s http://localhost:8081/api/v1/health
echo ""

# Test prediction
echo "Sample Prediction (NVDA):"
curl -s http://localhost:8081/api/v1/predict/NVDA
echo ""

print_status "System is ready for production use!"
print_status "Access the frontend at: http://localhost:8080"

# Optionally show logs
if [ "$DETACHED" = "true" ]; then
    echo ""
    read -p "Would you like to view the logs? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME logs -f
    fi
fi
