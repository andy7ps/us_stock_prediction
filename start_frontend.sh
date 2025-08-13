#!/bin/bash

# Production Frontend Server Script
# Serves the Bootstrap-enhanced Angular frontend on port 8080

set -e

echo "🚀 Starting Production Frontend Server"
echo "======================================"
echo "🎨 Bootstrap 5.3.3 + Angular 20+ UI"
echo "📱 Mobile-first responsive design"
echo "🔗 Backend API: http://localhost:8081"
echo ""

# Check if frontend is built
if [ ! -d "frontend/dist/frontend/browser" ]; then
    echo "❌ Frontend not built. Building now..."
    cd frontend
    npm install
    npx ng build --configuration=production
    cd ..
    echo "✅ Frontend built successfully"
fi

# Check if port 8080 is available
if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null ; then
    echo "⚠️  Port 8080 is already in use"
    echo "   Checking if it's our frontend server..."
    if curl -s http://localhost:8080/ | grep -q "Stock Prediction"; then
        echo "✅ Frontend is already running on http://localhost:8080"
        exit 0
    else
        echo "❌ Port 8080 is used by another service"
        echo "   Please stop the service using port 8080 and try again"
        exit 1
    fi
fi

echo "🌐 Starting frontend server on http://localhost:8080"
echo "📊 Backend API available at http://localhost:8081"
echo ""
echo "✅ Frontend Features:"
echo "   🎨 Bootstrap 5.3.3 professional UI"
echo "   📱 Responsive design for all devices"
echo "   🔍 Real-time stock predictions"
echo "   📈 Interactive charts and data"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

cd frontend/dist/frontend/browser

# Use Python's built-in server
python3 -m http.server 8080

echo ""
echo "✅ Frontend server stopped"
