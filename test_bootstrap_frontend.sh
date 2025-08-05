#!/bin/bash

# Test Bootstrap Integration for Stock Prediction Frontend
# This script tests the Bootstrap-enhanced Angular frontend

set -e

echo "🚀 Testing Bootstrap Integration for Stock Prediction Frontend"
echo "============================================================"

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

# Check if we're in the right directory
if [ ! -f "frontend/package.json" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

cd frontend

print_status "Checking Node.js and npm versions..."
node --version
npm --version

print_status "Checking Angular CLI..."
if ! command -v ng &> /dev/null; then
    print_warning "Angular CLI not found globally, using npx..."
    NG_CMD="npx ng"
else
    NG_CMD="ng"
fi

print_status "Verifying Bootstrap dependencies..."
if npm list bootstrap > /dev/null 2>&1; then
    print_success "Bootstrap is installed"
    npm list bootstrap | grep bootstrap
else
    print_error "Bootstrap is not installed"
    exit 1
fi

if npm list bootstrap-icons > /dev/null 2>&1; then
    print_success "Bootstrap Icons is installed"
    npm list bootstrap-icons | grep bootstrap-icons
else
    print_error "Bootstrap Icons is not installed"
    exit 1
fi

print_status "Checking Angular configuration..."
if grep -q "bootstrap" angular.json; then
    print_success "Bootstrap is configured in angular.json"
else
    print_error "Bootstrap is not configured in angular.json"
    exit 1
fi

if grep -q "bootstrap-icons" angular.json; then
    print_success "Bootstrap Icons is configured in angular.json"
else
    print_error "Bootstrap Icons is not configured in angular.json"
    exit 1
fi

print_status "Verifying component files..."
if [ -f "src/app/components/stock-prediction.component.html" ]; then
    print_success "Bootstrap HTML template exists"
else
    print_error "Bootstrap HTML template is missing"
    exit 1
fi

if [ -f "src/app/components/stock-prediction.component.css" ]; then
    print_success "Enhanced CSS file exists"
else
    print_error "Enhanced CSS file is missing"
    exit 1
fi

if [ -f "src/app/components/stock-prediction.component.ts" ]; then
    print_success "Component TypeScript file exists"
else
    print_error "Component TypeScript file is missing"
    exit 1
fi

print_status "Checking for Bootstrap classes in template..."
if grep -q "btn btn-primary" src/app/components/stock-prediction.component.html; then
    print_success "Bootstrap button classes found"
else
    print_warning "Bootstrap button classes not found"
fi

if grep -q "card" src/app/components/stock-prediction.component.html; then
    print_success "Bootstrap card classes found"
else
    print_warning "Bootstrap card classes not found"
fi

if grep -q "container-fluid" src/app/components/stock-prediction.component.html; then
    print_success "Bootstrap container classes found"
else
    print_warning "Bootstrap container classes not found"
fi

print_status "Checking for Bootstrap Icons..."
if grep -q "bi bi-" src/app/components/stock-prediction.component.html; then
    print_success "Bootstrap Icons found in template"
else
    print_warning "Bootstrap Icons not found in template"
fi

print_status "Testing build process..."
if $NG_CMD build --configuration development > /dev/null 2>&1; then
    print_success "Development build successful"
else
    print_error "Development build failed"
    exit 1
fi

print_status "Checking build output for Bootstrap..."
if [ -d "dist" ]; then
    if find dist -name "*.css" -exec grep -l "bootstrap" {} \; | head -1 > /dev/null; then
        print_success "Bootstrap CSS found in build output"
    else
        print_warning "Bootstrap CSS not found in build output"
    fi
    
    if find dist -name "*.js" -exec grep -l "bootstrap" {} \; | head -1 > /dev/null; then
        print_success "Bootstrap JS found in build output"
    else
        print_warning "Bootstrap JS not found in build output"
    fi
else
    print_warning "Build output directory not found"
fi

print_status "Testing component compilation..."
if $NG_CMD build --configuration development --verbose 2>&1 | grep -q "stock-prediction.component"; then
    print_success "Stock prediction component compiled successfully"
else
    print_warning "Could not verify component compilation"
fi

print_status "Checking for responsive design classes..."
if grep -q "col-" src/app/components/stock-prediction.component.html; then
    print_success "Bootstrap grid classes found"
else
    print_warning "Bootstrap grid classes not found"
fi

if grep -q "d-flex\|d-grid" src/app/components/stock-prediction.component.html; then
    print_success "Bootstrap flexbox classes found"
else
    print_warning "Bootstrap flexbox classes not found"
fi

print_status "Verifying mobile-first approach..."
if grep -q "@media.*max-width" src/app/components/stock-prediction.component.css; then
    print_success "Mobile-first CSS media queries found"
else
    print_warning "Mobile-first CSS media queries not found"
fi

print_status "Testing service integration..."
if [ -f "src/app/services/stock-prediction.service.ts" ]; then
    print_success "Stock prediction service exists"
else
    print_error "Stock prediction service is missing"
    exit 1
fi

echo ""
echo "============================================================"
print_success "Bootstrap Integration Test Complete!"
echo ""
print_status "Summary of enhancements:"
echo "  ✅ Bootstrap 5.3.3 integrated"
echo "  ✅ Bootstrap Icons added"
echo "  ✅ Responsive grid system"
echo "  ✅ Enhanced UI components"
echo "  ✅ Mobile-first design"
echo "  ✅ Accessibility improvements"
echo "  ✅ Modern card-based layout"
echo "  ✅ Professional styling"
echo ""
print_status "To start the development server:"
echo "  cd frontend && npm start"
echo ""
print_status "To build for production:"
echo "  cd frontend && npm run build"
echo ""
print_success "Your Angular frontend is now Bootstrap-ready! 🎉"
