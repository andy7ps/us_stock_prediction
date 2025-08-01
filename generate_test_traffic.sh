#!/bin/bash

# Test Traffic Generator for Grafana Dashboard
# This script generates realistic API traffic to populate Grafana metrics

set -e

echo "🚀 Generating test traffic for Grafana dashboard..."
echo "=================================================="

# Configuration
API_BASE="http://localhost:8080"
STOCKS=("NVDA" "TSLA" "AAPL" "MSFT" "GOOGL" "AMZN" "META" "GME" "AMC" "COIN")
DURATION=60  # seconds
REQUESTS_PER_SECOND=2

echo "📊 Configuration:"
echo "  - API Base: $API_BASE"
echo "  - Duration: ${DURATION}s"
echo "  - Rate: ${REQUESTS_PER_SECOND} requests/second"
echo "  - Stock symbols: ${STOCKS[*]}"
echo ""

# Check if service is running
echo "🔍 Checking service health..."
if ! curl -s "$API_BASE/api/v1/health" >/dev/null; then
    echo "❌ Service not running! Please start with: docker-compose up -d"
    exit 1
fi
echo "✅ Service is healthy"
echo ""

# Function to make API request
make_request() {
    local endpoint=$1
    local symbol=$2
    local method=${3:-GET}
    
    if [ "$method" = "GET" ]; then
        curl -s "$API_BASE$endpoint" >/dev/null 2>&1
    else
        curl -s -X "$method" "$API_BASE$endpoint" >/dev/null 2>&1
    fi
    
    local status=$?
    if [ $status -eq 0 ]; then
        echo "✅ $method $endpoint"
    else
        echo "❌ $method $endpoint (failed)"
    fi
}

# Function to generate random stock symbol
get_random_stock() {
    echo "${STOCKS[$RANDOM % ${#STOCKS[@]}]}"
}

# Function to generate realistic traffic pattern
generate_traffic_burst() {
    local burst_size=$1
    echo "📈 Generating burst of $burst_size requests..."
    
    for ((i=1; i<=burst_size; i++)); do
        local stock=$(get_random_stock)
        local rand=$((RANDOM % 100))
        
        if [ $rand -lt 60 ]; then
            # 60% prediction requests
            make_request "/api/v1/predict/$stock"
        elif [ $rand -lt 80 ]; then
            # 20% historical data requests
            local days=$((RANDOM % 30 + 5))
            make_request "/api/v1/historical/$stock?days=$days"
        elif [ $rand -lt 90 ]; then
            # 10% health checks
            make_request "/api/v1/health"
        elif [ $rand -lt 95 ]; then
            # 5% stats requests
            make_request "/api/v1/stats"
        else
            # 5% cache operations
            make_request "/api/v1/cache/clear" "" "POST"
        fi
        
        # Small delay between requests in burst
        sleep 0.1
    done
}

# Main traffic generation loop
echo "🎯 Starting traffic generation..."
echo "Press Ctrl+C to stop"
echo ""

start_time=$(date +%s)
request_count=0

while true; do
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))
    
    # Stop after duration
    if [ $elapsed -ge $DURATION ]; then
        break
    fi
    
    # Generate different traffic patterns
    pattern=$((RANDOM % 100))
    
    if [ $pattern -lt 70 ]; then
        # 70% normal traffic
        stock=$(get_random_stock)
        make_request "/api/v1/predict/$stock"
        request_count=$((request_count + 1))
        
    elif [ $pattern -lt 85 ]; then
        # 15% burst traffic
        generate_traffic_burst 5
        request_count=$((request_count + 5))
        
    elif [ $pattern -lt 95 ]; then
        # 10% mixed requests
        make_request "/api/v1/health"
        make_request "/api/v1/stats"
        stock=$(get_random_stock)
        make_request "/api/v1/historical/$stock?days=10"
        request_count=$((request_count + 3))
        
    else
        # 5% error simulation (invalid endpoints)
        make_request "/api/v1/predict/INVALID"
        make_request "/api/v1/nonexistent"
        request_count=$((request_count + 2))
    fi
    
    # Progress indicator
    if [ $((request_count % 10)) -eq 0 ]; then
        echo "📊 Progress: ${elapsed}s elapsed, $request_count requests made"
    fi
    
    # Rate limiting
    sleep $(echo "scale=2; 1.0 / $REQUESTS_PER_SECOND" | bc -l)
done

echo ""
echo "🎉 Traffic generation completed!"
echo "📊 Summary:"
echo "  - Duration: ${elapsed}s"
echo "  - Total requests: $request_count"
echo "  - Average rate: $(echo "scale=2; $request_count / $elapsed" | bc -l) req/s"
echo ""
echo "🎯 Now check your Grafana dashboard:"
echo "  - URL: http://localhost:3000"
echo "  - Login: admin/admin"
echo "  - Look for metrics in the panels!"
echo ""
echo "📈 Recommended next steps:"
echo "  1. Open Grafana dashboard"
echo "  2. Set time range to 'Last 5 minutes'"
echo "  3. Enable auto-refresh (5s)"
echo "  4. Watch the metrics populate!"
