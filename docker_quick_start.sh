#!/bin/bash

# Quick Start Script for Stock Prediction System
# One-command startup for the complete system

echo "🚀 Quick Starting Stock Prediction System..."

# Ensure we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: docker-compose.yml not found. Please run from project root."
    exit 1
fi

# Setup persistent storage if needed
if [ ! -d "persistent_data" ]; then
    echo "📁 Setting up persistent storage..."
    ./setup_persistent_storage.sh
fi

# Create frontend logs directory
mkdir -p persistent_data/frontend/logs

# Start the system
echo "🐳 Starting Docker containers..."
docker-compose up -d

echo ""
echo "✅ System started successfully!"
echo ""
echo "🌐 Access points:"
echo "   Frontend:  http://localhost:8080"
echo "   Backend:   http://localhost:8081"
echo "   Grafana:   http://localhost:3000 (admin/admin)"
echo "   Prometheus: http://localhost:9090"
echo ""
echo "📊 Test the API:"
echo "   curl http://localhost:8081/api/v1/health"
echo "   curl http://localhost:8081/api/v1/predict/NVDA"
echo ""
echo "🛠️  Management:"
echo "   View logs:  docker-compose logs -f"
echo "   Stop:       docker-compose down"
echo "   Status:     docker-compose ps"
echo ""
