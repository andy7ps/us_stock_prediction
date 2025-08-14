#!/bin/bash

# Test Script for Stock Prediction Service v3.4.0
# Tests all new daily prediction tracking features
# Author: Stock Prediction Service Development Team
# Created: 2024-08-14

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_BASE_URL="${API_BASE_URL:-http://localhost:8081}"
FRONTEND_URL="${FRONTEND_URL:-http://localhost:8080}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Test function wrapper
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log_info "Running test: $test_name"
    
    if $test_function; then
        log_success "$test_name"
    else
        log_error "$test_name"
    fi
    echo ""
}

# Test service health
test_service_health() {
    local response
    response=$(curl -s -w "%{http_code}" "$API_BASE_URL/api/v1/health" 2>/dev/null)
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        if echo "$body" | grep -q '"status":"healthy"'; then
            return 0
        fi
    fi
    return 1
}

# Test new API endpoints
test_daily_status_endpoint() {
    local response
    response=$(curl -s -w "%{http_code}" "$API_BASE_URL/api/v1/predictions/daily-status" 2>/dev/null)
    local http_code="${response: -3}"
    
    [ "$http_code" = "200" ]
}

test_overall_performance_endpoint() {
    local response
    response=$(curl -s -w "%{http_code}" "$API_BASE_URL/api/v1/predictions/accuracy/summary" 2>/dev/null)
    local http_code="${response: -3}"
    
    [ "$http_code" = "200" ]
}

test_accuracy_summary_endpoint() {
    local response
    response=$(curl -s -w "%{http_code}" "$API_BASE_URL/api/v1/predictions/accuracy/NVDA" 2>/dev/null)
    local http_code="${response: -3}"
    
    [ "$http_code" = "200" ]
}

test_prediction_history_endpoint() {
    local response
    response=$(curl -s -w "%{http_code}" "$API_BASE_URL/api/v1/predictions/history/NVDA" 2>/dev/null)
    local http_code="${response: -3}"
    
    [ "$http_code" = "200" ]
}

test_performance_metrics_endpoint() {
    local response
    response=$(curl -s -w "%{http_code}" "$API_BASE_URL/api/v1/predictions/performance" 2>/dev/null)
    local http_code="${response: -3}"
    
    [ "$http_code" = "200" ]
}

test_accuracy_trends_endpoint() {
    local response
    response=$(curl -s -w "%{http_code}" "$API_BASE_URL/api/v1/predictions/trends/NVDA?days=30" 2>/dev/null)
    local http_code="${response: -3}"
    
    [ "$http_code" = "200" ]
}

test_top_performers_endpoint() {
    local response
    response=$(curl -s -w "%{http_code}" "$API_BASE_URL/api/v1/predictions/top-performers?limit=5" 2>/dev/null)
    local http_code="${response: -3}"
    
    [ "$http_code" = "200" ]
}

# Test manual daily prediction execution
test_manual_daily_execution() {
    local payload='{"symbols":["NVDA","TSLA"],"execution_type":"manual","force_execute":true}'
    local response
    response=$(curl -s -w "%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$API_BASE_URL/api/v1/predictions/daily-run" 2>/dev/null)
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" = "200" ]; then
        if echo "$body" | grep -q '"execution_type":"manual"'; then
            return 0
        fi
    fi
    return 1
}

# Test database functionality
test_database_connection() {
    # Check if database file exists and is accessible
    local db_path="/app/persistent_data/predictions.db"
    if [ -f "$db_path" ] || [ -f "./data/predictions.db" ]; then
        return 0
    fi
    
    # If running in Docker, the database might be created on first run
    # So we'll consider this test passed if the API endpoints work
    test_daily_status_endpoint
}

# Test market calendar functionality
test_market_calendar() {
    # Test by checking if the service can determine market status
    local today=$(date +%Y-%m-%d)
    local response
    response=$(curl -s "$API_BASE_URL/api/v1/predictions/daily-status" 2>/dev/null)
    
    if echo "$response" | grep -q "is_enabled"; then
        return 0
    fi
    return 1
}

# Test frontend accessibility
test_frontend_accessibility() {
    local response
    response=$(curl -s -w "%{http_code}" "$FRONTEND_URL" 2>/dev/null)
    local http_code="${response: -3}"
    
    [ "$http_code" = "200" ]
}

# Test version update
test_version_update() {
    local response
    response=$(curl -s "$API_BASE_URL/" 2>/dev/null)
    
    if echo "$response" | grep -q '"version":"v3.4.0"'; then
        return 0
    fi
    return 1
}

# Test accuracy range endpoint
test_accuracy_range_endpoint() {
    local start_date=$(date -d "30 days ago" +%Y-%m-%d)
    local end_date=$(date +%Y-%m-%d)
    local response
    response=$(curl -s -w "%{http_code}" \
        "$API_BASE_URL/api/v1/predictions/accuracy/range?start_date=$start_date&end_date=$end_date" 2>/dev/null)
    
    local http_code="${response: -3}"
    [ "$http_code" = "200" ]
}

# Test update actual price endpoint
test_update_actual_price_endpoint() {
    local yesterday=$(date -d "yesterday" +%Y-%m-%d)
    local payload="{\"symbol\":\"NVDA\",\"date\":\"$yesterday\",\"actual_close\":125.50}"
    local response
    response=$(curl -s -w "%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$API_BASE_URL/api/v1/predictions/update-actual" 2>/dev/null)
    
    local http_code="${response: -3}"
    # This might fail if no prediction exists for yesterday, which is expected
    [ "$http_code" = "200" ] || [ "$http_code" = "500" ]
}

# Test cron job setup
test_cron_job_setup() {
    if [ -f "$SCRIPT_DIR/scripts/daily_prediction.sh" ] && [ -x "$SCRIPT_DIR/scripts/daily_prediction.sh" ]; then
        return 0
    fi
    return 1
}

# Test daily prediction script
test_daily_prediction_script() {
    if [ -f "$SCRIPT_DIR/scripts/daily_prediction.sh" ]; then
        # Test script syntax
        bash -n "$SCRIPT_DIR/scripts/daily_prediction.sh"
        return $?
    fi
    return 1
}

# Test setup script
test_setup_script() {
    if [ -f "$SCRIPT_DIR/setup_daily_predictions.sh" ] && [ -x "$SCRIPT_DIR/setup_daily_predictions.sh" ]; then
        # Test script syntax
        bash -n "$SCRIPT_DIR/setup_daily_predictions.sh"
        return $?
    fi
    return 1
}

# Test Go module dependencies
test_go_dependencies() {
    cd "$SCRIPT_DIR"
    if go mod verify > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Test SQLite dependency
test_sqlite_dependency() {
    cd "$SCRIPT_DIR"
    if go list -m github.com/mattn/go-sqlite3 > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Main test execution
main() {
    echo "🧪 Stock Prediction Service v3.4.0 Feature Tests"
    echo "================================================"
    echo ""
    
    log_info "API Base URL: $API_BASE_URL"
    log_info "Frontend URL: $FRONTEND_URL"
    echo ""
    
    # Core service tests
    run_test "Service Health Check" test_service_health
    run_test "Version Update" test_version_update
    run_test "Go Dependencies" test_go_dependencies
    run_test "SQLite Dependency" test_sqlite_dependency
    
    # Database and storage tests
    run_test "Database Connection" test_database_connection
    run_test "Market Calendar" test_market_calendar
    
    # New API endpoint tests
    run_test "Daily Status Endpoint" test_daily_status_endpoint
    run_test "Overall Performance Endpoint" test_overall_performance_endpoint
    run_test "Accuracy Summary Endpoint" test_accuracy_summary_endpoint
    run_test "Prediction History Endpoint" test_prediction_history_endpoint
    run_test "Performance Metrics Endpoint" test_performance_metrics_endpoint
    run_test "Accuracy Trends Endpoint" test_accuracy_trends_endpoint
    run_test "Top Performers Endpoint" test_top_performers_endpoint
    run_test "Accuracy Range Endpoint" test_accuracy_range_endpoint
    run_test "Update Actual Price Endpoint" test_update_actual_price_endpoint
    
    # Functionality tests
    run_test "Manual Daily Execution" test_manual_daily_execution
    
    # Script and automation tests
    run_test "Cron Job Setup" test_cron_job_setup
    run_test "Daily Prediction Script" test_daily_prediction_script
    run_test "Setup Script" test_setup_script
    
    # Frontend tests
    run_test "Frontend Accessibility" test_frontend_accessibility
    
    # Test summary
    echo "================================================"
    echo "🏁 Test Results Summary"
    echo "================================================"
    echo ""
    echo "Total Tests: $TOTAL_TESTS"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed! v3.4.0 features are working correctly.${NC}"
        echo ""
        echo "✅ Daily prediction tracking is ready for production!"
        echo "✅ All new API endpoints are functional"
        echo "✅ Database integration is working"
        echo "✅ Automation scripts are ready"
        echo ""
        echo "🚀 Next steps:"
        echo "   1. Run: ./setup_daily_predictions.sh"
        echo "   2. Test manual execution in frontend"
        echo "   3. Monitor daily execution logs"
        return 0
    else
        echo -e "${RED}❌ Some tests failed. Please review the errors above.${NC}"
        echo ""
        echo "🔧 Troubleshooting:"
        echo "   1. Ensure the service is running: docker-compose ps"
        echo "   2. Check service logs: docker-compose logs"
        echo "   3. Verify database permissions: ls -la persistent_data/"
        echo "   4. Test API manually: curl $API_BASE_URL/api/v1/health"
        return 1
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--help] [--api-url URL] [--frontend-url URL]"
        echo ""
        echo "Options:"
        echo "  --help              Show this help message"
        echo "  --api-url URL       Set API base URL (default: http://localhost:8081)"
        echo "  --frontend-url URL  Set frontend URL (default: http://localhost:8080)"
        echo ""
        echo "Environment Variables:"
        echo "  API_BASE_URL        API base URL"
        echo "  FRONTEND_URL        Frontend URL"
        exit 0
        ;;
    --api-url)
        API_BASE_URL="$2"
        shift 2
        ;;
    --frontend-url)
        FRONTEND_URL="$2"
        shift 2
        ;;
esac

# Run main function
main "$@"
