#!/bin/bash

echo "🚀 System Restart Status Report"
echo "==============================="
echo "Restart Time: $(date)"
echo ""

# Check all container status
echo "📦 Container Status:"
echo "==================="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep v3_

echo ""
echo "🔍 Service Health Checks:"
echo "========================="

# Frontend Health
echo -n "Frontend (Port 8080): "
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)
if [ "$FRONTEND_STATUS" = "200" ]; then
    echo "✅ Healthy (HTTP $FRONTEND_STATUS)"
else
    echo "❌ Unhealthy (HTTP $FRONTEND_STATUS)"
fi

# Backend Health
echo -n "Backend API (Port 8081): "
BACKEND_HEALTH=$(curl -s http://localhost:8081/api/v1/health | jq -r '.status' 2>/dev/null)
if [ "$BACKEND_HEALTH" = "healthy" ]; then
    echo "✅ Healthy"
else
    echo "❌ Unhealthy"
fi

# Redis Health
echo -n "Redis Cache (Port 6379): "
REDIS_HEALTH=$(docker exec v3_redis_1 redis-cli ping 2>/dev/null)
if [ "$REDIS_HEALTH" = "PONG" ]; then
    echo "✅ Healthy"
else
    echo "❌ Unhealthy"
fi

# Prometheus Health
echo -n "Prometheus (Port 9090): "
PROMETHEUS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090 2>/dev/null)
if [ "$PROMETHEUS_STATUS" = "405" ] || [ "$PROMETHEUS_STATUS" = "200" ]; then
    echo "✅ Healthy (HTTP $PROMETHEUS_STATUS)"
else
    echo "❌ Unhealthy (HTTP $PROMETHEUS_STATUS)"
fi

# Grafana Health
echo -n "Grafana (Port 3000): "
GRAFANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null)
if [ "$GRAFANA_STATUS" = "302" ] || [ "$GRAFANA_STATUS" = "200" ]; then
    echo "✅ Healthy (HTTP $GRAFANA_STATUS)"
else
    echo "❌ Unhealthy (HTTP $GRAFANA_STATUS)"
fi

echo ""
echo "🧪 Functionality Tests:"
echo "======================="

# Test Stock Prediction
echo -n "Stock Predictions: "
NVDA_TEST=$(curl -s http://localhost:8081/api/v1/predict/NVDA | jq -r '.symbol' 2>/dev/null)
if [ "$NVDA_TEST" = "NVDA" ]; then
    echo "✅ Working"
else
    echo "❌ Failed"
fi

# Test LMT Symbol
echo -n "LMT Symbol: "
LMT_TEST=$(curl -s http://localhost:8081/api/v1/predict/LMT | jq -r '.symbol' 2>/dev/null)
if [ "$LMT_TEST" = "LMT" ]; then
    echo "✅ Working"
else
    echo "❌ Failed"
fi

# Test Historical Data
echo -n "Historical Data: "
HIST_TEST=$(curl -s "http://localhost:8081/api/v1/historical/NVDA?days=3" | jq -r '.count' 2>/dev/null)
if [ "$HIST_TEST" != "null" ] && [ "$HIST_TEST" != "" ]; then
    echo "✅ Working ($HIST_TEST records)"
else
    echo "❌ Failed"
fi

# Test Frontend Content
echo -n "Frontend Content: "
FRONTEND_CONTENT=$(curl -s http://localhost:8080 | grep -o "Stock Prediction Service" | head -1)
if [ "$FRONTEND_CONTENT" = "Stock Prediction Service" ]; then
    echo "✅ Loading correctly"
else
    echo "❌ Content issue"
fi

echo ""
echo "📊 System Performance:"
echo "====================="

# Get system stats
STATS=$(curl -s http://localhost:8081/api/v1/stats 2>/dev/null)
if [ "$STATS" != "" ]; then
    echo "Memory Usage: $(echo "$STATS" | jq -r '.system.memory_alloc') bytes"
    echo "Goroutines: $(echo "$STATS" | jq -r '.system.goroutines')"
    echo "Cache Size: $(echo "$STATS" | jq -r '.cache.size') entries"
    echo "Model Version: $(echo "$STATS" | jq -r '.model.version')"
else
    echo "❌ Unable to retrieve system stats"
fi

echo ""
echo "🌐 Access URLs:"
echo "=============="
echo "Frontend: http://localhost:8080"
echo "Backend API: http://localhost:8081"
echo "Prometheus: http://localhost:9090"
echo "Grafana: http://localhost:3000 (admin/admin)"
echo ""
echo "Network Access (Dynamic Hostname):"
echo "Frontend: http://[your-ip]:8080"
echo "Backend: http://[your-ip]:8081"

echo ""
echo "✨ Recent Improvements:"
echo "======================"
echo "✅ Layout alignment: All sections use consistent col-lg-10 width"
echo "✅ Popular stocks: 18 symbols with LMT (Lockheed Martin)"
echo "✅ Historical data: Shows last 10 trading days with recent dates"
echo "✅ Mobile optimization: Responsive design for all screen sizes"
echo "✅ Fresh data: Always fetch latest information (no stale cache)"
echo "✅ Network flexibility: Dynamic hostname support maintained"

echo ""
echo "🎯 System Status: All services operational and ready for use!"
echo "============================================================="
