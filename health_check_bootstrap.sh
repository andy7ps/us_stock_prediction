#!/bin/bash

# Bootstrap-Aware Health Check Script
# Comprehensive health monitoring for Bootstrap-enhanced Stock Prediction Service

set -e

echo "🏥 Bootstrap-Enhanced Stock Prediction Service Health Check"
echo "=========================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[CHECK]${NC} $1"
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
    echo -e "${PURPLE}[HEALTH]${NC} $1"
}

# Configuration
PROJECT_NAME="stock-prediction-bootstrap"
FRONTEND_URL="http://localhost:8080"
BACKEND_URL="http://localhost:8081"
GRAFANA_URL="http://localhost:3000"
PROMETHEUS_URL="http://localhost:9090"

# Health check counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Function to perform HTTP health check
check_http_endpoint() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}
    local timeout=${4:-10}
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    print_status "Checking $name at $url"
    
    local response=$(curl -s -o /dev/null -w "%{http_code}" --max-time $timeout "$url" 2>/dev/null || echo "000")
    
    if [ "$response" = "$expected_status" ]; then
        print_success "$name is healthy (HTTP $response)"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        print_error "$name is unhealthy (HTTP $response, expected $expected_status)"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

# Function to check service response content
check_content() {
    local name=$1
    local url=$2
    local pattern=$3
    local timeout=${4:-10}
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    print_status "Checking $name content"
    
    local content=$(curl -s --max-time $timeout "$url" 2>/dev/null || echo "")
    
    if echo "$content" | grep -q "$pattern"; then
        print_success "$name content check passed"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        print_error "$name content check failed (pattern: $pattern)"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

# Function to check Docker container status
check_container() {
    local container_name=$1
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    print_status "Checking container: $container_name"
    
    if docker ps --format "table {{.Names}}" | grep -q "$container_name"; then
        local status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "not_found")
        if [ "$status" = "running" ]; then
            print_success "Container $container_name is running"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            return 0
        else
            print_error "Container $container_name is not running (status: $status)"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            return 1
        fi
    else
        print_error "Container $container_name not found"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

# Function to check Bootstrap integration
check_bootstrap_integration() {
    print_header "Bootstrap Integration Health Check"
    
    # Check if Bootstrap CSS is loaded
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    print_status "Checking Bootstrap CSS integration"
    
    local frontend_content=$(curl -s --max-time 10 "$FRONTEND_URL" 2>/dev/null || echo "")
    if echo "$frontend_content" | grep -q "bootstrap"; then
        print_success "Bootstrap CSS is integrated"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        print_warning "Bootstrap CSS integration not detected in HTML"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
    fi
    
    # Check Bootstrap Icons
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    print_status "Checking Bootstrap Icons integration"
    
    if echo "$frontend_content" | grep -q "bootstrap-icons"; then
        print_success "Bootstrap Icons are integrated"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        print_warning "Bootstrap Icons integration not detected"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
    fi
    
    # Check responsive meta tag
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    print_status "Checking responsive design meta tag"
    
    if echo "$frontend_content" | grep -q "viewport.*width=device-width"; then
        print_success "Responsive design meta tag found"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        print_error "Responsive design meta tag missing"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

# Function to check API functionality
check_api_functionality() {
    print_header "API Functionality Health Check"
    
    # Test prediction endpoint
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    print_status "Testing stock prediction API"
    
    local prediction_response=$(curl -s --max-time 15 "$BACKEND_URL/api/v1/predict/NVDA" 2>/dev/null || echo "")
    if echo "$prediction_response" | grep -q "symbol\|predicted_price"; then
        print_success "Stock prediction API is functional"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        print_error "Stock prediction API is not responding correctly"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
    
    # Test health endpoint
    check_http_endpoint "Backend Health" "$BACKEND_URL/api/v1/health"
    
    # Test stats endpoint
    check_http_endpoint "Backend Stats" "$BACKEND_URL/api/v1/stats"
}

# Function to check performance metrics
check_performance() {
    print_header "Performance Health Check"
    
    # Check frontend response time
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    print_status "Checking frontend response time"
    
    local start_time=$(date +%s%N)
    curl -s --max-time 10 "$FRONTEND_URL" > /dev/null 2>&1
    local end_time=$(date +%s%N)
    local response_time=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
    
    if [ $response_time -lt 2000 ]; then
        print_success "Frontend response time: ${response_time}ms (Good)"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    elif [ $response_time -lt 5000 ]; then
        print_warning "Frontend response time: ${response_time}ms (Acceptable)"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
    else
        print_error "Frontend response time: ${response_time}ms (Too slow)"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
    
    # Check backend response time
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    print_status "Checking backend response time"
    
    start_time=$(date +%s%N)
    curl -s --max-time 10 "$BACKEND_URL/api/v1/health" > /dev/null 2>&1
    end_time=$(date +%s%N)
    response_time=$(( (end_time - start_time) / 1000000 ))
    
    if [ $response_time -lt 1000 ]; then
        print_success "Backend response time: ${response_time}ms (Excellent)"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    elif [ $response_time -lt 3000 ]; then
        print_warning "Backend response time: ${response_time}ms (Acceptable)"
        WARNING_CHECKS=$((WARNING_CHECKS + 1))
    else
        print_error "Backend response time: ${response_time}ms (Too slow)"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

# Function to check resource usage
check_resources() {
    print_header "Resource Usage Health Check"
    
    # Check Docker container resource usage
    if command -v docker &> /dev/null; then
        TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
        print_status "Checking container resource usage"
        
        local containers=$(docker ps --format "{{.Names}}" | grep "$PROJECT_NAME" || echo "")
        if [ -n "$containers" ]; then
            local high_cpu_containers=0
            local high_memory_containers=0
            
            while IFS= read -r container; do
                if [ -n "$container" ]; then
                    local stats=$(docker stats --no-stream --format "{{.CPUPerc}} {{.MemPerc}}" "$container" 2>/dev/null || echo "0.00% 0.00%")
                    local cpu_percent=$(echo "$stats" | awk '{print $1}' | sed 's/%//')
                    local mem_percent=$(echo "$stats" | awk '{print $2}' | sed 's/%//')
                    
                    # Check CPU usage (warning if > 80%)
                    if (( $(echo "$cpu_percent > 80" | bc -l 2>/dev/null || echo 0) )); then
                        high_cpu_containers=$((high_cpu_containers + 1))
                    fi
                    
                    # Check memory usage (warning if > 80%)
                    if (( $(echo "$mem_percent > 80" | bc -l 2>/dev/null || echo 0) )); then
                        high_memory_containers=$((high_memory_containers + 1))
                    fi
                fi
            done <<< "$containers"
            
            if [ $high_cpu_containers -eq 0 ] && [ $high_memory_containers -eq 0 ]; then
                print_success "Container resource usage is normal"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
            else
                print_warning "Some containers have high resource usage (CPU: $high_cpu_containers, Memory: $high_memory_containers)"
                WARNING_CHECKS=$((WARNING_CHECKS + 1))
            fi
        else
            print_error "No containers found for project $PROJECT_NAME"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    fi
}

# Main health check execution
print_header "Starting comprehensive health check..."

# Check Docker containers
print_header "Container Health Check"
check_container "${PROJECT_NAME}_frontend_1"
check_container "${PROJECT_NAME}_stock-prediction_1"
check_container "${PROJECT_NAME}_prometheus_1"
check_container "${PROJECT_NAME}_grafana_1"

# Check HTTP endpoints
print_header "HTTP Endpoint Health Check"
check_http_endpoint "Frontend" "$FRONTEND_URL/health"
check_http_endpoint "Backend Health" "$BACKEND_URL/api/v1/health"
check_http_endpoint "Grafana" "$GRAFANA_URL/api/health"
check_http_endpoint "Prometheus" "$PROMETHEUS_URL/-/healthy"

# Check Bootstrap integration
check_bootstrap_integration

# Check API functionality
check_api_functionality

# Check performance
check_performance

# Check resources
check_resources

# Additional checks
print_header "Additional Health Checks"

# Check persistent data
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
print_status "Checking persistent data directory"
if [ -d "persistent_data" ] && [ -w "persistent_data" ]; then
    print_success "Persistent data directory is accessible"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    print_error "Persistent data directory is not accessible"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Check log files
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
print_status "Checking log files"
if [ -d "persistent_data/logs" ] && [ "$(ls -A persistent_data/logs 2>/dev/null)" ]; then
    print_success "Log files are being generated"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    print_warning "No log files found or logs directory empty"
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
fi

# Summary
echo ""
print_header "Health Check Summary"
echo "===================="
echo "Total Checks: $TOTAL_CHECKS"
echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC}"
echo -e "Warnings: ${YELLOW}$WARNING_CHECKS${NC}"
echo -e "Failed: ${RED}$FAILED_CHECKS${NC}"
echo ""

# Calculate health score
HEALTH_SCORE=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
WARNING_SCORE=$(( (WARNING_CHECKS * 50) / TOTAL_CHECKS ))
TOTAL_SCORE=$(( HEALTH_SCORE + WARNING_SCORE ))

echo "Health Score: $TOTAL_SCORE/100"

if [ $FAILED_CHECKS -eq 0 ] && [ $WARNING_CHECKS -eq 0 ]; then
    print_success "🎉 All health checks passed! Service is fully operational."
    exit 0
elif [ $FAILED_CHECKS -eq 0 ]; then
    print_warning "⚠️  Service is operational with some warnings."
    exit 0
else
    print_error "❌ Service has critical issues that need attention."
    exit 1
fi
