#!/bin/bash

# 🚀 Development Start Script
# Start frontend and backend for local development

set -e

echo "🔧 Starting Development Environment..."
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "main.go" ] || [ ! -d "frontend" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Function to cleanup background processes
cleanup() {
    print_status "Cleaning up background processes..."
    jobs -p | xargs -r kill
    exit 0
}

# Set trap to cleanup on script exit
trap cleanup EXIT INT TERM

# Start backend (Go service) on port 8081
print_status "Starting Go backend on port 8081..."
export SERVER_PORT=8081
go run main.go &
BACKEND_PID=$!

# Wait a moment for backend to start
sleep 3

# Check if backend is running
if ! curl -f http://localhost:8081/api/v1/health >/dev/null 2>&1; then
    print_error "Backend failed to start properly"
    exit 1
fi
print_success "Backend started successfully!"

# Start frontend (Angular) on port 8080
print_status "Starting Angular frontend on port 8080..."
cd frontend

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    print_status "Installing Angular dependencies..."
    npm install
fi

# Start Angular dev server
npm start &
FRONTEND_PID=$!

cd ..

print_success "Development environment started!"
echo ""
echo "🌐 Development URLs:"
echo "  • Frontend (Angular):  http://localhost:8080"
echo "  • Backend API (Go):    http://localhost:8081"
echo ""
echo "🔗 API Endpoints:"
echo "  • Stock Prediction:    http://localhost:8081/api/v1/predict/{symbol}"
echo "  • Health Check:        http://localhost:8081/api/v1/health"
echo ""
echo "Press Ctrl+C to stop all services..."

# Wait for processes
wait
