#!/bin/bash

# Enhanced Docker System Startup Script
# Starts the complete Bootstrap-enhanced Stock Prediction System

set -e

echo "🚀 Starting Bootstrap-Enhanced Stock Prediction System"
echo "======================================================"

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
    echo -e "${PURPLE}[SYSTEM]${NC} $1"
}

print_feature() {
    echo -e "${CYAN}  ✨${NC} $1"
}

# Configuration
COMPOSE_FILE="docker-compose.yml"
PROJECT_NAME="stock-prediction-v3"
BOOTSTRAP_VERSION="5.3.3"
ANGULAR_VERSION="20.1.0"

# Parse command line arguments
REBUILD="false"
VERBOSE="false"
SKIP_HEALTH_CHECK="false"
DETACHED="true"

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
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --rebuild       Force rebuild of all containers"
            echo "  --verbose       Enable verbose output"
            echo "  --no-detach     Run in foreground (don't detach)"
            echo "  --skip-health   Skip health checks"
            echo "  -h, --help      Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

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
    "docker-compose.yml"
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

# Setup persistent storage
print_status "Setting up persistent storage..."
if [ ! -d "persistent_data" ]; then
    print_status "Creating persistent data directories..."
    ./setup_persistent_storage.sh
fi

# Create frontend logs directory
mkdir -p persistent_data/frontend/logs
chmod 755 persistent_data/frontend/logs

print_success "Persistent storage ready"

# Stop existing containers if running
print_status "Stopping existing containers..."
docker-compose -p $PROJECT_NAME down --remove-orphans 2>/dev/null || true

# Build/rebuild containers if requested
if [ "$REBUILD" = "true" ]; then
    print_status "Rebuilding all containers..."
    docker-compose -p $PROJECT_NAME build --no-cache
else
    print_status "Building containers (using cache)..."
    docker-compose -p $PROJECT_NAME build
fi

# Start the system
print_header "Starting System Services"

if [ "$DETACHED" = "true" ]; then
    print_status "Starting services in detached mode..."
    docker-compose -p $PROJECT_NAME up -d
else
    print_status "Starting services in foreground mode..."
    docker-compose -p $PROJECT_NAME up
    exit 0
fi

# Wait for services to be healthy
if [ "$SKIP_HEALTH_CHECK" = "false" ]; then
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
            exit 1
        fi
        sleep 2
    done
    
    # Wait for frontend
    print_status "Checking frontend health..."
    for i in {1..30}; do
        if curl -s http://localhost:8080/health > /dev/null 2>&1; then
            print_success "Frontend is healthy"
            break
        fi
        if [ $i -eq 30 ]; then
            print_error "Frontend health check failed"
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
fi

# Display system information
print_header "🎉 System Successfully Started!"
echo ""
print_success "Bootstrap-Enhanced Stock Prediction System v3.2.0"
echo ""
echo "📱 Frontend (Bootstrap UI):     http://localhost:8080"
echo "🔧 Backend API:                http://localhost:8081"
echo "📊 Prometheus Metrics:         http://localhost:9090"
echo "📈 Grafana Dashboards:         http://localhost:3000 (admin/admin)"
echo "🗄️  Redis Cache:                localhost:6379"
echo ""

print_header "🎨 Bootstrap Features Available:"
print_feature "Bootstrap $BOOTSTRAP_VERSION with professional UI components"
print_feature "Angular $ANGULAR_VERSION with modern TypeScript"
print_feature "Bootstrap Icons 1.13.1 with 1,800+ scalable icons"
print_feature "Mobile-first responsive design"
print_feature "Dark mode support"
print_feature "Professional card-based layout"
print_feature "Enhanced animations and transitions"
print_feature "Accessibility (WCAG 2.1) compliance"
print_feature "PWA support for mobile app-like experience"
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
echo ""

print_header "🛠️  Management Commands:"
echo "  docker-compose -p $PROJECT_NAME logs -f           # View logs"
echo "  docker-compose -p $PROJECT_NAME ps                # View status"
echo "  docker-compose -p $PROJECT_NAME down              # Stop system"
echo "  docker-compose -p $PROJECT_NAME restart frontend  # Restart frontend"
echo ""

if [ "$VERBOSE" = "true" ]; then
    print_header "📋 Container Status:"
    docker-compose -p $PROJECT_NAME ps
    echo ""
    
    print_header "📊 Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
fi

print_success "System is ready for use! 🎉"
print_status "Press Ctrl+C to view logs, or run 'docker-compose -p $PROJECT_NAME logs -f' to follow logs"

# Optionally show logs
if [ "$DETACHED" = "true" ]; then
    echo ""
    read -p "Would you like to view the logs? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose -p $PROJECT_NAME logs -f
    fi
fi
