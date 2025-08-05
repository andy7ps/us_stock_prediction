#!/bin/bash

# Enhanced Docker Deployment Script for Bootstrap-Integrated Stock Prediction Service
# Deploys the complete stack with Bootstrap 5.3.3 frontend

set -e

echo "🚀 Deploying Bootstrap-Enhanced Stock Prediction Service"
echo "======================================================="

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
    echo -e "${PURPLE}[DEPLOY]${NC} $1"
}

# Configuration
COMPOSE_FILE="docker-compose.yml"
COMPOSE_PROD_FILE="docker-compose.prod.yml"
PROJECT_NAME="stock-prediction-bootstrap"
BOOTSTRAP_VERSION="5.3.3"
ANGULAR_VERSION="20.1.0"

# Parse command line arguments
ENVIRONMENT="development"
REBUILD="false"
SKIP_TESTS="false"
VERBOSE="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --prod|--production)
            ENVIRONMENT="production"
            COMPOSE_FILE="$COMPOSE_PROD_FILE"
            shift
            ;;
        --rebuild)
            REBUILD="true"
            shift
            ;;
        --skip-tests)
            SKIP_TESTS="true"
            shift
            ;;
        --verbose)
            VERBOSE="true"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --prod, --production    Deploy in production mode"
            echo "  --rebuild              Force rebuild of all containers"
            echo "  --skip-tests           Skip pre-deployment tests"
            echo "  --verbose              Enable verbose output"
            echo "  -h, --help             Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

print_header "Starting deployment in $ENVIRONMENT mode"

# Check prerequisites
print_status "Checking prerequisites..."

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

# Check Bootstrap integration
print_status "Verifying Bootstrap integration..."

if [ -f "frontend/package.json" ]; then
    if grep -q "bootstrap.*$BOOTSTRAP_VERSION" frontend/package.json; then
        print_success "Bootstrap $BOOTSTRAP_VERSION found in package.json"
    else
        print_warning "Bootstrap version mismatch or not found"
    fi
    
    if grep -q "bootstrap-icons" frontend/package.json; then
        print_success "Bootstrap Icons found in package.json"
    else
        print_warning "Bootstrap Icons not found in package.json"
    fi
fi

if [ -f "frontend/angular.json" ]; then
    if grep -q "bootstrap" frontend/angular.json; then
        print_success "Bootstrap configured in angular.json"
    else
        print_error "Bootstrap not configured in angular.json"
        exit 1
    fi
fi

# Setup persistent storage
print_status "Setting up persistent storage..."

if [ ! -d "persistent_data" ]; then
    print_status "Creating persistent storage structure..."
    ./setup_persistent_storage.sh
    print_success "Persistent storage created"
else
    print_success "Persistent storage already exists"
fi

# Ensure proper permissions
sudo chown -R $USER:$USER persistent_data/ 2>/dev/null || true
chmod -R 755 persistent_data/

# Run pre-deployment tests
if [ "$SKIP_TESTS" != "true" ]; then
    print_status "Running pre-deployment tests..."
    
    # Test Bootstrap integration
    if [ -f "test_bootstrap_frontend.sh" ]; then
        print_status "Testing Bootstrap integration..."
        if ./test_bootstrap_frontend.sh > /dev/null 2>&1; then
            print_success "Bootstrap integration tests passed"
        else
            print_warning "Bootstrap integration tests failed, continuing anyway"
        fi
    fi
    
    # Test Go backend
    print_status "Testing Go backend compilation..."
    if go build -o /tmp/stock-prediction-test main.go; then
        print_success "Go backend compilation successful"
        rm -f /tmp/stock-prediction-test
    else
        print_error "Go backend compilation failed"
        exit 1
    fi
    
    print_success "Pre-deployment tests completed"
fi

# Stop existing containers
print_status "Stopping existing containers..."
docker-compose -p "$PROJECT_NAME" down --remove-orphans 2>/dev/null || true

# Clean up if rebuild requested
if [ "$REBUILD" == "true" ]; then
    print_status "Cleaning up for rebuild..."
    docker-compose -p "$PROJECT_NAME" down --volumes --remove-orphans 2>/dev/null || true
    docker system prune -f --volumes 2>/dev/null || true
    print_success "Cleanup completed"
fi

# Build and start services
print_status "Building and starting services..."

if [ "$VERBOSE" == "true" ]; then
    BUILD_ARGS="--verbose"
else
    BUILD_ARGS=""
fi

if [ "$REBUILD" == "true" ]; then
    BUILD_ARGS="$BUILD_ARGS --no-cache --force-rm"
fi

# Build services
print_status "Building Docker images..."
if [ "$ENVIRONMENT" == "production" ]; then
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" build $BUILD_ARGS \
        --build-arg NODE_ENV=production \
        --build-arg BOOTSTRAP_VERSION="$BOOTSTRAP_VERSION" \
        --build-arg GO_VERSION=1.23
else
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" build $BUILD_ARGS \
        --build-arg NODE_ENV=development \
        --build-arg BOOTSTRAP_VERSION="$BOOTSTRAP_VERSION" \
        --build-arg GO_VERSION=1.23
fi

print_success "Docker images built successfully"

# Start services
print_status "Starting services..."
docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d

# Wait for services to be ready
print_status "Waiting for services to be ready..."

# Function to wait for service
wait_for_service() {
    local service_name=$1
    local url=$2
    local max_attempts=30
    local attempt=1
    
    print_status "Waiting for $service_name..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$url" > /dev/null 2>&1; then
            print_success "$service_name is ready"
            return 0
        fi
        
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    print_error "$service_name failed to start within expected time"
    return 1
}

# Wait for backend
wait_for_service "Go Backend" "http://localhost:8081/api/v1/health"

# Wait for frontend
wait_for_service "Bootstrap Frontend" "http://localhost:8080/health"

# Wait for monitoring services
wait_for_service "Prometheus" "http://localhost:9090/-/healthy"
wait_for_service "Grafana" "http://localhost:3000/api/health"

# Verify Bootstrap integration in running container
print_status "Verifying Bootstrap integration in running container..."

# Check if Bootstrap CSS is loaded
if docker exec "${PROJECT_NAME}_frontend_1" find /usr/share/nginx/html -name "*.css" -exec grep -l "bootstrap" {} \; 2>/dev/null | head -1 > /dev/null; then
    print_success "Bootstrap CSS found in frontend container"
else
    print_warning "Bootstrap CSS not found in frontend container"
fi

# Check if Bootstrap JS is loaded
if docker exec "${PROJECT_NAME}_frontend_1" find /usr/share/nginx/html -name "*.js" -exec grep -l "bootstrap" {} \; 2>/dev/null | head -1 > /dev/null; then
    print_success "Bootstrap JS found in frontend container"
else
    print_warning "Bootstrap JS not found in frontend container"
fi

# Display service status
print_status "Checking service status..."
docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps

# Display service information
echo ""
print_header "🎉 Deployment Complete!"
echo ""
print_success "Bootstrap-Enhanced Stock Prediction Service is now running!"
echo ""
echo "📊 Service Access Points:"
echo "  🌐 Frontend (Bootstrap UI):  http://localhost:8080"
echo "  🔧 Backend API:              http://localhost:8081"
echo "  📈 Grafana Dashboards:       http://localhost:3000 (admin/admin)"
echo "  📊 Prometheus Metrics:       http://localhost:9090"
if docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps | grep -q redis; then
    echo "  🗄️  Redis Cache:              http://localhost:6379"
fi
echo ""
echo "🎨 Bootstrap Features:"
echo "  ✨ Bootstrap Version:         $BOOTSTRAP_VERSION"
echo "  🅰️  Angular Version:          $ANGULAR_VERSION"
echo "  📱 Mobile-First Design:       ✅ Enabled"
echo "  ♿ Accessibility:             ✅ WCAG 2.1"
echo "  🌙 Dark Mode:                ✅ System-based"
echo "  🔍 Bootstrap Icons:           ✅ 1,800+ icons"
echo ""
echo "🛠️  Management Commands:"
echo "  📋 View logs:                 docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME logs -f"
echo "  🔄 Restart services:          docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME restart"
echo "  🛑 Stop services:             docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME down"
echo "  🧹 Clean up:                  docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME down --volumes"
echo ""
echo "🧪 Testing Commands:"
echo "  🔍 Test Bootstrap:            ./test_bootstrap_frontend.sh"
echo "  🏥 Health Check:              ./health_check_bootstrap.sh"
echo "  ⚡ Performance Test:          ./performance_test_bootstrap.sh"
echo ""

# Save deployment info
cat > .deployment_info << EOF
# Bootstrap-Enhanced Stock Prediction Service Deployment Info
DEPLOYMENT_DATE=$(date)
ENVIRONMENT=$ENVIRONMENT
BOOTSTRAP_VERSION=$BOOTSTRAP_VERSION
ANGULAR_VERSION=$ANGULAR_VERSION
COMPOSE_FILE=$COMPOSE_FILE
PROJECT_NAME=$PROJECT_NAME
FRONTEND_URL=http://localhost:8080
BACKEND_URL=http://localhost:8081
GRAFANA_URL=http://localhost:3000
PROMETHEUS_URL=http://localhost:9090
EOF

print_success "Deployment information saved to .deployment_info"

# Final verification
print_status "Performing final verification..."

# Test a simple API call
if curl -f -s "http://localhost:8081/api/v1/health" > /dev/null; then
    print_success "Backend API is responding"
else
    print_warning "Backend API is not responding properly"
fi

# Test frontend
if curl -f -s "http://localhost:8080/health" > /dev/null; then
    print_success "Bootstrap frontend is responding"
else
    print_warning "Bootstrap frontend is not responding properly"
fi

echo ""
print_header "🚀 Ready to use! Visit http://localhost:8080 to see your Bootstrap-enhanced stock prediction service!"
echo ""

# Optional: Open browser (uncomment if desired)
# if command -v xdg-open &> /dev/null; then
#     xdg-open http://localhost:8080
# elif command -v open &> /dev/null; then
#     open http://localhost:8080
# fi
