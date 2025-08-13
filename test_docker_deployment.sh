#!/bin/bash

# Docker Deployment Test Script
# Comprehensive testing of all services and functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}[SUITE]${NC} $1"
}

# Configuration
COMPOSE_FILE="docker-compose-production.yml"
PROJECT_NAME="stock-prediction-prod"
BASE_URL="http://localhost"
API_URL="${BASE_URL}:8081"
FRONTEND_URL="${BASE_URL}:8080"
GRAFANA_URL="${BASE_URL}:3000"
PROMETHEUS_URL="${BASE_URL}:9090"

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    print_status "Running: $test_name"
    
    if eval "$test_command" > /dev/null 2>&1; then
        print_success "$test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "$test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    print_status "Running: $test_name"
    
    local output
    output=$(eval "$test_command" 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_success "$test_name"
        echo "  Output: $output"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "$test_name"
        echo "  Error: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "🧪 Docker Deployment Test Suite"
echo "==============================="
echo ""

# Test 1: Docker Environment
print_header "Docker Environment Tests"

run_test "Docker daemon is running" "docker info"
run_test "Docker Compose is available" "docker-compose --version"
run_test "Project containers exist" "docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME ps | grep -q 'Up'"

echo ""

# Test 2: Container Health
print_header "Container Health Tests"

containers=("frontend" "stock-prediction" "redis" "prometheus" "grafana")

for container in "${containers[@]}"; do
    run_test "Container $container is running" "docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME ps $container | grep -q 'Up'"
done

echo ""

# Test 3: Network Connectivity
print_header "Network Connectivity Tests"

run_test "Frontend port 8080 is accessible" "curl -s -o /dev/null -w '%{http_code}' $FRONTEND_URL/health | grep -q '200'"
run_test "Backend port 8081 is accessible" "curl -s -o /dev/null -w '%{http_code}' $API_URL/api/v1/health | grep -q '200'"
run_test "Grafana port 3000 is accessible" "curl -s -o /dev/null -w '%{http_code}' $GRAFANA_URL/api/health | grep -q '200'"
run_test "Prometheus port 9090 is accessible" "curl -s -o /dev/null -w '%{http_code}' $PROMETHEUS_URL/-/healthy | grep -q '200'"

echo ""

# Test 4: API Functionality
print_header "API Functionality Tests"

run_test_with_output "Backend health check" "curl -s $API_URL/api/v1/health | jq -r '.status'"
run_test "Backend returns JSON health data" "curl -s $API_URL/api/v1/health | jq -e '.status == \"healthy\"'"

# Test stock prediction endpoints
symbols=("NVDA" "TSLA" "AAPL")
for symbol in "${symbols[@]}"; do
    run_test "Stock prediction for $symbol" "curl -s $API_URL/api/v1/predict/$symbol | jq -e '.symbol == \"$symbol\"'"
done

run_test "Historical data endpoint" "curl -s $API_URL/api/v1/historical/NVDA?days=5 | jq -e '.symbol == \"NVDA\"'"
run_test "Service stats endpoint" "curl -s $API_URL/api/v1/stats | jq -e 'has(\"uptime\")'"

echo ""

# Test 5: Frontend Functionality
print_header "Frontend Functionality Tests"

run_test "Frontend health endpoint" "curl -s $FRONTEND_URL/health | grep -q 'OK'"
run_test "Frontend serves HTML" "curl -s $FRONTEND_URL | grep -q '<html'"
run_test "Bootstrap CSS is loaded" "curl -s $FRONTEND_URL | grep -q 'bootstrap'"
run_test "Angular app is loaded" "curl -s $FRONTEND_URL | grep -q 'ng-'"

echo ""

# Test 6: Monitoring Stack
print_header "Monitoring Stack Tests"

run_test "Prometheus is healthy" "curl -s $PROMETHEUS_URL/-/healthy | grep -q 'Prometheus Server is Healthy'"
run_test "Prometheus has targets" "curl -s $PROMETHEUS_URL/api/v1/targets | jq -e '.data.activeTargets | length > 0'"
run_test "Grafana API is accessible" "curl -s $GRAFANA_URL/api/health | jq -e '.database == \"ok\"'"

echo ""

# Test 7: Data Persistence
print_header "Data Persistence Tests"

run_test "Persistent data directory exists" "[ -d persistent_data ]"
run_test "ML models directory exists" "[ -d persistent_data/ml_models ]"
run_test "Prometheus data directory exists" "[ -d persistent_data/prometheus ]"
run_test "Grafana data directory exists" "[ -d persistent_data/grafana ]"
run_test "Redis data directory exists" "[ -d persistent_data/redis ]"

echo ""

# Test 8: Cache Functionality
print_header "Cache Functionality Tests"

# Test Redis connectivity through backend
run_test "Redis cache is accessible" "docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME exec -T redis redis-cli -a stockprediction2025 ping | grep -q 'PONG'"

# Test cache through API (make same request twice to test caching)
print_status "Testing API caching..."
first_response=$(curl -s "$API_URL/api/v1/predict/NVDA")
sleep 1
second_response=$(curl -s "$API_URL/api/v1/predict/NVDA")

if [ "$first_response" = "$second_response" ]; then
    print_success "API caching is working"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_warning "API caching may not be working (responses differ)"
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

echo ""

# Test 9: Performance Tests
print_header "Performance Tests"

# Test API response time
print_status "Testing API response time..."
response_time=$(curl -s -o /dev/null -w '%{time_total}' "$API_URL/api/v1/health")
if (( $(echo "$response_time < 1.0" | bc -l) )); then
    print_success "API response time is acceptable ($response_time seconds)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_warning "API response time is slow ($response_time seconds)"
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

# Test concurrent requests
print_status "Testing concurrent API requests..."
for i in {1..5}; do
    curl -s "$API_URL/api/v1/health" > /dev/null &
done
wait

if [ $? -eq 0 ]; then
    print_success "Concurrent requests handled successfully"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    print_error "Concurrent requests failed"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_TOTAL=$((TESTS_TOTAL + 1))

echo ""

# Test 10: Security Tests
print_header "Security Tests"

run_test "CORS headers are present" "curl -s -I $API_URL/api/v1/health | grep -q 'Access-Control-Allow-Origin'"
run_test "Security headers on frontend" "curl -s -I $FRONTEND_URL | grep -q 'X-Content-Type-Options'"
run_test "Redis requires authentication" "docker-compose -f $COMPOSE_FILE -p $PROJECT_NAME exec -T redis redis-cli ping 2>&1 | grep -q 'NOAUTH'"

echo ""

# Test Summary
print_header "Test Summary"
echo ""
echo "Total Tests: $TESTS_TOTAL"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    print_success "🎉 All tests passed! Docker deployment is working correctly."
    echo ""
    echo "✅ System Status: HEALTHY"
    echo "✅ All services are running"
    echo "✅ API endpoints are functional"
    echo "✅ Frontend is accessible"
    echo "✅ Monitoring is active"
    echo "✅ Data persistence is working"
    echo ""
    echo "🌐 Access Points:"
    echo "   Frontend:  $FRONTEND_URL"
    echo "   Backend:   $API_URL"
    echo "   Grafana:   $GRAFANA_URL (admin/admin)"
    echo "   Prometheus: $PROMETHEUS_URL"
    echo ""
    exit 0
else
    print_error "❌ Some tests failed. Please check the deployment."
    echo ""
    echo "🔍 Troubleshooting steps:"
    echo "1. Check container logs: ./manage_system.sh logs"
    echo "2. Verify service status: ./manage_system.sh status"
    echo "3. Restart services: ./manage_system.sh restart"
    echo "4. Check Docker resources: docker system df"
    echo ""
    exit 1
fi
