#!/bin/bash

# Test Accuracy Feature - Generate Sample Data
# This script will run daily predictions to populate the accuracy tracking system

set -e

echo "🧪 Testing Prediction Accuracy Feature"
echo "======================================"

API_BASE_URL="http://localhost:8081"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Test service health
print_status "Checking service health..."
if curl -s -f "$API_BASE_URL/api/v1/health" > /dev/null; then
    print_success "Service is healthy"
else
    print_error "Service is not responding"
    exit 1
fi

# Run daily predictions to generate data
print_status "Running daily predictions to generate accuracy data..."
response=$(curl -s -X POST "$API_BASE_URL/api/v1/predictions/daily-run")
print_success "Daily predictions executed: $response"

# Wait a moment for processing
sleep 2

# Check daily status
print_status "Checking daily prediction status..."
curl -s "$API_BASE_URL/api/v1/predictions/daily-status"

echo ""
print_status "Checking accuracy summary..."
curl -s "$API_BASE_URL/api/v1/predictions/accuracy/summary"

echo ""
print_status "Checking performance metrics..."
curl -s "$API_BASE_URL/api/v1/predictions/performance"

echo ""
print_success "🎉 Accuracy feature test completed!"
echo ""
echo "📊 How to Access Prediction Accuracy:"
echo "======================================"
echo "1. 🌐 Open your browser to: http://localhost:8080"
echo "2. 📈 Click on the 'Accuracy Tracking' tab"
echo "3. 🔄 Click 'Run Now' to execute daily predictions"
echo "4. 📊 View accuracy metrics and historical analysis"
echo ""
echo "🔗 Direct API Access:"
echo "- Daily Status: $API_BASE_URL/api/v1/predictions/daily-status"
echo "- Accuracy Summary: $API_BASE_URL/api/v1/predictions/accuracy/summary"
echo "- Performance: $API_BASE_URL/api/v1/predictions/performance"
echo ""
echo "📱 Frontend Features:"
echo "- Real-time accuracy tracking"
echo "- Symbol-by-symbol performance"
echo "- Historical prediction analysis"
echo "- Manual prediction execution"
echo "- MAPE and direction accuracy metrics"
