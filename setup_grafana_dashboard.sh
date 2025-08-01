#!/bin/bash

# Grafana Dashboard Quick Setup Script
# This script helps you set up the complete monitoring dashboard

set -e

echo "🎯 Grafana Dashboard Setup for Stock Prediction Service"
echo "======================================================"

# Check if services are running
echo "🔍 Checking services..."
if ! docker-compose ps | grep -q "Up"; then
    echo "⚠️  Services not running. Starting Docker Compose..."
    docker-compose up -d
    echo "⏳ Waiting for services to start..."
    sleep 30
fi

# Verify services
echo "✅ Checking service health..."
services=("stock-prediction:8080" "prometheus:9090" "grafana:3000")
for service in "${services[@]}"; do
    name=${service%:*}
    port=${service#*:}
    if curl -s "http://localhost:$port" >/dev/null; then
        echo "  ✅ $name (port $port) - Running"
    else
        echo "  ❌ $name (port $port) - Not responding"
    fi
done

echo ""
echo "🎨 Dashboard Setup Instructions:"
echo "================================"
echo ""
echo "1. 🌐 Open Grafana in your browser:"
echo "   URL: http://localhost:3000"
echo "   Username: admin"
echo "   Password: admin"
echo ""
echo "2. 📊 Import the pre-built dashboard:"
echo "   Method A - Import JSON file:"
echo "   - Click '+' → Import"
echo "   - Upload: monitoring/grafana/dashboards/stock-prediction-complete.json"
echo ""
echo "   Method B - Copy-paste JSON:"
echo "   - Click '+' → Import"
echo "   - Paste the JSON content from the file above"
echo ""
echo "3. 🔧 Configure dashboard:"
echo "   - Set time range: 'Last 1 hour'"
echo "   - Enable auto-refresh: '5s'"
echo "   - Save dashboard"
echo ""
echo "4. 📈 Generate test data:"
echo "   Run: ./generate_test_traffic.sh"
echo "   This will populate your dashboard with realistic metrics"
echo ""

# Generate some initial test traffic
echo "🚀 Generating initial test traffic..."
echo "This will help populate your dashboard with data..."

# Background traffic generation
(
    for i in {1..30}; do
        curl -s http://localhost:8080/api/v1/health >/dev/null 2>&1 &
        curl -s http://localhost:8080/api/v1/predict/NVDA >/dev/null 2>&1 &
        curl -s http://localhost:8080/api/v1/predict/TSLA >/dev/null 2>&1 &
        curl -s http://localhost:8080/api/v1/predict/AAPL >/dev/null 2>&1 &
        curl -s http://localhost:8080/api/v1/stats >/dev/null 2>&1 &
        sleep 2
    done
    wait
) &

echo "✅ Test traffic generation started in background"
echo ""
echo "🎯 Dashboard Panels You'll See:"
echo "==============================="
echo "📈 API Request Rate       - Current traffic load"
echo "⚡ Cache Hit Ratio        - Caching efficiency"
echo "❌ Error Rate            - System reliability"
echo "🔗 Active Connections    - Concurrent users"
echo "🔮 Prediction Requests   - ML usage patterns"
echo "⏱️  Response Time         - Performance metrics"
echo "📋 Popular Stocks        - Business intelligence"
echo "💾 Memory Usage          - Resource monitoring"
echo "🎯 Prediction Accuracy   - ML model performance"
echo ""
echo "🎨 Dashboard Features:"
echo "====================="
echo "✅ Real-time updates (5-second refresh)"
echo "✅ Interactive time range selection"
echo "✅ Color-coded thresholds (green/yellow/red)"
echo "✅ Business intelligence metrics"
echo "✅ Performance monitoring"
echo "✅ System health tracking"
echo ""
echo "🔧 Customization Options:"
echo "========================="
echo "- Add new panels with custom queries"
echo "- Set up alerting for critical metrics"
echo "- Create variables for dynamic filtering"
echo "- Export/import dashboard configurations"
echo "- Share dashboards with team members"
echo ""
echo "📊 Key Prometheus Queries Used:"
echo "==============================="
echo "rate(http_requests_total[5m])                    # Request rate"
echo "cache_hits_total / (cache_hits_total + cache_misses_total) * 100  # Cache ratio"
echo "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))  # Response time"
echo "topk(10, sum by (symbol) (prediction_requests_total))  # Popular stocks"
echo ""
echo "🎉 Setup Complete!"
echo "=================="
echo "Your Grafana dashboard is ready to use!"
echo ""
echo "Next steps:"
echo "1. Open http://localhost:3000 in your browser"
echo "2. Login with admin/admin"
echo "3. Import the dashboard JSON"
echo "4. Watch your metrics come alive!"
echo ""
echo "For continuous test traffic, run:"
echo "./generate_test_traffic.sh"
echo ""
echo "Happy monitoring! 📊✨"
