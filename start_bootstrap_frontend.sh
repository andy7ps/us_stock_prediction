#!/bin/bash

# Enhanced Bootstrap Frontend Startup Script
# Starts the Bootstrap-integrated Angular frontend with the Go backend

set -e

echo "🚀 Starting Enhanced Bootstrap Stock Prediction Frontend"
echo "========================================================"

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
if [ ! -f "frontend/package.json" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Check if backend is running
print_status "Checking if Go backend is running..."
if curl -s http://localhost:8081/api/v1/health > /dev/null 2>&1; then
    print_success "Go backend is running on port 8081"
else
    print_status "Starting Go backend..."
    if [ -f "main.go" ]; then
        go run main.go &
        BACKEND_PID=$!
        echo $BACKEND_PID > .backend.pid
        print_success "Go backend started with PID $BACKEND_PID"
        sleep 3
    else
        print_error "main.go not found. Please ensure you're in the project root."
        exit 1
    fi
fi

# Start the Angular frontend
print_status "Starting Bootstrap-enhanced Angular frontend..."
cd frontend

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    print_status "Installing npm dependencies..."
    npm install
fi

# Check if Angular CLI is available
if ! command -v ng &> /dev/null; then
    print_status "Using npx for Angular CLI..."
    NG_CMD="npx ng"
else
    NG_CMD="ng"
fi

print_status "Starting development server..."
print_status "Frontend will be available at: http://localhost:8080"
print_status "Backend API available at: http://localhost:8081"

echo ""
print_success "🎉 Enhanced Features Available:"
echo "  ✨ Bootstrap 5.3.3 UI Components"
echo "  🎨 Professional Card-based Layout"
echo "  📱 Mobile-First Responsive Design"
echo "  🔍 Bootstrap Icons Integration"
echo "  ⚡ Enhanced Animations & Transitions"
echo "  ♿ Improved Accessibility"
echo "  🌙 Dark Mode Support"
echo "  📊 Beautiful Progress Bars & Badges"
echo ""

# Start the Angular development server
$NG_CMD serve --host 0.0.0.0 --port 8080

# Cleanup function
cleanup() {
    print_status "Shutting down services..."
    if [ -f "../.backend.pid" ]; then
        BACKEND_PID=$(cat ../.backend.pid)
        if kill -0 $BACKEND_PID 2>/dev/null; then
            kill $BACKEND_PID
            print_success "Backend stopped"
        fi
        rm -f ../.backend.pid
    fi
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM
