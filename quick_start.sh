#!/bin/bash

# Stock Prediction Service v3.1.0 - Quick Start Script
# This script automates the setup and testing process

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Go
    if command -v go &> /dev/null; then
        GO_VERSION=$(go version | awk '{print $3}')
        print_status "Go found: $GO_VERSION"
    else
        print_error "Go is not installed. Please install Go 1.23+ first."
        exit 1
    fi
    
    # Check Python
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version)
        print_status "Python found: $PYTHON_VERSION"
    else
        print_error "Python3 is not installed. Please install Python 3.11+ first."
        exit 1
    fi
    
    # Check Docker (optional)
    if command -v docker &> /dev/null; then
        print_status "Docker found: $(docker --version)"
    else
        print_warning "Docker not found. Docker deployment will not be available."
    fi
    
    # Check Make (optional)
    if command -v make &> /dev/null; then
        print_status "Make found: $(make --version | head -n1)"
    else
        print_warning "Make not found. Using manual commands."
    fi
    
    echo ""
}

# Function to setup environment
setup_environment() {
    print_header "Setting Up Environment"
    
    # Create necessary directories
    print_status "Creating directories..."
    mkdir -p models logs bin
    
    # Copy environment file
    if [ ! -f .env ]; then
        print_status "Creating .env file..."
        cp .env.example .env
    else
        print_status ".env file already exists"
    fi
    
    # Install Go dependencies
    print_status "Installing Go dependencies..."
    go mod download
    go mod tidy
    
    print_status "Environment setup complete!"
    echo ""
}

# Function to test Python script
test_python_script() {
    print_header "Testing Python ML Script"
    
    print_status "Testing Python prediction script..."
    if python3 scripts/ml/predict.py "100.0,101.0,102.0,103.0,104.0"; then
        print_status "Python script test passed!"
    else
        print_error "Python script test failed!"
        exit 1
    fi
    echo ""
}

# Function to build application
build_application() {
    print_header "Building Application"
    
    print_status "Building Go application..."
    go build -o bin/stock-prediction-v3 .
    
    if [ -f bin/stock-prediction-v3 ]; then
        print_status "Build successful!"
    else
        print_error "Build failed!"
        exit 1
    fi
    echo ""
}

# Function to run tests
run_tests() {
    print_header "Running Tests"
    
    print_status "Running unit tests..."
    if go test -v ./...; then
        print_status "All tests passed!"
    else
        print_error "Some tests failed!"
        exit 1
    fi
    echo ""
}

# Function to start service
start_service() {
    print_header "Starting Service"
    
    print_status "Starting Stock Prediction Service..."
    print_status "Service will start on http://localhost:8080"
    print_status "Press Ctrl+C to stop the service"
    echo ""
    
    # Start the service
    ./bin/stock-prediction-v3
}

# Function to test API endpoints
test_api_endpoints() {
    print_header "Testing API Endpoints"
    
    # Wait for service to start
    print_status "Waiting for service to start..."
    sleep 3
    
    # Test health endpoint
    print_status "Testing health endpoint..."
    if curl -s -f http://localhost:8080/api/v1/health > /dev/null; then
        print_status "Health endpoint: OK"
        curl -s http://localhost:8080/api/v1/health | python3 -m json.tool
    else
        print_error "Health endpoint: FAILED"
    fi
    
    echo ""
    
    # Test prediction endpoint
    print_status "Testing prediction endpoint..."
    if curl -s -f http://localhost:8080/api/v1/predict/AAPL > /dev/null; then
        print_status "Prediction endpoint: OK"
        curl -s http://localhost:8080/api/v1/predict/AAPL | python3 -m json.tool
    else
        print_warning "Prediction endpoint: FAILED (might be due to network/API issues)"
    fi
    
    echo ""
    
    # Test stats endpoint
    print_status "Testing stats endpoint..."
    if curl -s -f http://localhost:8080/api/v1/stats > /dev/null; then
        print_status "Stats endpoint: OK"
        curl -s http://localhost:8080/api/v1/stats | python3 -m json.tool
    else
        print_error "Stats endpoint: FAILED"
    fi
    
    echo ""
}

# Function to show usage examples
show_usage_examples() {
    print_header "Usage Examples"
    
    echo -e "${GREEN}Basic Stock Prediction:${NC}"
    echo "curl http://localhost:8080/api/v1/predict/NVDA"
    echo ""
    
    echo -e "${GREEN}Prediction with Custom Lookback:${NC}"
    echo "curl http://localhost:8080/api/v1/predict/AAPL?days=10"
    echo ""
    
    echo -e "${GREEN}Historical Data:${NC}"
    echo "curl http://localhost:8080/api/v1/historical/TSLA?days=30"
    echo ""
    
    echo -e "${GREEN}Health Check:${NC}"
    echo "curl http://localhost:8080/api/v1/health"
    echo ""
    
    echo -e "${GREEN}Service Stats:${NC}"
    echo "curl http://localhost:8080/api/v1/stats"
    echo ""
    
    echo -e "${GREEN}Clear Cache:${NC}"
    echo "curl -X POST http://localhost:8080/api/v1/cache/clear"
    echo ""
    
    echo -e "${GREEN}Prometheus Metrics:${NC}"
    echo "curl http://localhost:8080/metrics"
    echo ""
}

# Function to start with Docker
start_with_docker() {
    print_header "Starting with Docker"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed!"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed!"
        exit 1
    fi
    
    print_status "Starting services with Docker Compose..."
    docker-compose up -d
    
    print_status "Waiting for services to start..."
    sleep 10
    
    print_status "Services started!"
    echo ""
    echo -e "${GREEN}Available Services:${NC}"
    echo "- Stock Prediction API: http://localhost:8080"
    echo "- Prometheus: http://localhost:9090"
    echo "- Grafana: http://localhost:3000 (admin/admin)"
    echo ""
    
    print_status "Checking service status..."
    docker-compose ps
}

# Main function
main() {
    print_header "Stock Prediction Service v3.1.0 - Quick Start"
    
    # Parse command line arguments
    case "${1:-local}" in
        "local")
            check_prerequisites
            setup_environment
            test_python_script
            build_application
            run_tests
            echo ""
            print_status "Setup complete! Starting service..."
            echo ""
            show_usage_examples
            echo ""
            start_service
            ;;
        "docker")
            check_prerequisites
            start_with_docker
            ;;
        "test")
            check_prerequisites
            setup_environment
            test_python_script
            build_application
            run_tests
            
            # Start service in background for testing
            print_status "Starting service for API testing..."
            ./bin/stock-prediction-v3 &
            SERVICE_PID=$!
            
            # Test API endpoints
            test_api_endpoints
            
            # Stop service
            print_status "Stopping service..."
            kill $SERVICE_PID
            wait $SERVICE_PID 2>/dev/null
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [local|docker|test|help]"
            echo ""
            echo "Commands:"
            echo "  local   - Setup and start service locally (default)"
            echo "  docker  - Start service with Docker Compose"
            echo "  test    - Run full test suite including API tests"
            echo "  help    - Show this help message"
            echo ""
            exit 0
            ;;
        *)
            print_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
