#!/bin/bash

# Stock Prediction API Testing Script
# Tests multiple stock symbols and displays results

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# API base URL
API_BASE="http://localhost:8080/api/v1"

# Function to print colored headers
print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to print stock prediction
print_prediction() {
    local symbol=$1
    local response=$2
    
    if echo "$response" | jq . >/dev/null 2>&1; then
        # Parse JSON response
        current_price=$(echo "$response" | jq -r '.current_price // "N/A"')
        predicted_price=$(echo "$response" | jq -r '.predicted_price // "N/A"')
        signal=$(echo "$response" | jq -r '.trading_signal // "N/A"')
        confidence=$(echo "$response" | jq -r '.confidence // "N/A"')
        
        # Color code the signal
        case $signal in
            "BUY")
                signal_color="${GREEN}$signal${NC}"
                ;;
            "SELL")
                signal_color="${RED}$signal${NC}"
                ;;
            "HOLD")
                signal_color="${YELLOW}$signal${NC}"
                ;;
            *)
                signal_color="$signal"
                ;;
        esac
        
        # Calculate percentage change
        if [[ "$current_price" != "N/A" && "$predicted_price" != "N/A" ]]; then
            change=$(echo "scale=2; (($predicted_price - $current_price) / $current_price) * 100" | bc -l 2>/dev/null || echo "N/A")
            if [[ "$change" != "N/A" ]]; then
                if (( $(echo "$change > 0" | bc -l) )); then
                    change_display="${GREEN}+${change}%${NC}"
                else
                    change_display="${RED}${change}%${NC}"
                fi
            else
                change_display="N/A"
            fi
        else
            change_display="N/A"
        fi
        
        echo -e "${BLUE}$symbol${NC}: $current_price → $predicted_price ($change_display) | Signal: $signal_color | Confidence: ${confidence}"
    else
        echo -e "${RED}$symbol: Error - $response${NC}"
    fi
}

# Function to test service health
test_health() {
    print_header "Service Health Check"
    
    response=$(curl -s "$API_BASE/health")
    if echo "$response" | jq . >/dev/null 2>&1; then
        status=$(echo "$response" | jq -r '.status')
        version=$(echo "$response" | jq -r '.version')
        
        if [[ "$status" == "healthy" ]]; then
            echo -e "${GREEN}✓ Service is healthy (version: $version)${NC}"
        else
            echo -e "${YELLOW}⚠ Service status: $status${NC}"
        fi
        
        # Show service details
        echo "$response" | jq '.services'
    else
        echo -e "${RED}✗ Service is not responding${NC}"
        echo "Response: $response"
        exit 1
    fi
}

# Function to test popular stocks
test_popular_stocks() {
    print_header "Popular Stock Predictions"
    
    # Popular tech stocks
    stocks=("AAPL" "NVDA" "MSFT" "GOOGL" "TSLA" "AMZN" "META" "NFLX")
    
    for symbol in "${stocks[@]}"; do
        response=$(curl -s "$API_BASE/predict/$symbol")
        print_prediction "$symbol" "$response"
        sleep 0.5  # Small delay to avoid overwhelming the API
    done
}

# Function to test custom stocks
test_custom_stocks() {
    print_header "Custom Stock Predictions"
    
    echo "Enter stock symbols (space-separated, e.g., AAPL TSLA NVDA):"
    read -r symbols
    
    for symbol in $symbols; do
        # Convert to uppercase
        symbol=$(echo "$symbol" | tr '[:lower:]' '[:upper:]')
        response=$(curl -s "$API_BASE/predict/$symbol")
        print_prediction "$symbol" "$response"
        sleep 0.5
    done
}

# Function to test with different lookback periods
test_lookback_periods() {
    print_header "Lookback Period Comparison (NVDA)"
    
    periods=(5 10 15 20)
    
    for days in "${periods[@]}"; do
        response=$(curl -s "$API_BASE/predict/NVDA?days=$days")
        if echo "$response" | jq . >/dev/null 2>&1; then
            predicted_price=$(echo "$response" | jq -r '.predicted_price')
            confidence=$(echo "$response" | jq -r '.confidence')
            echo -e "${days} days: $predicted_price (confidence: $confidence)"
        else
            echo -e "${RED}${days} days: Error${NC}"
        fi
        sleep 0.5
    done
}

# Function to show historical data
show_historical_data() {
    print_header "Historical Data Sample (AAPL - Last 5 Days)"
    
    response=$(curl -s "$API_BASE/historical/AAPL?days=5")
    if echo "$response" | jq . >/dev/null 2>&1; then
        echo "$response" | jq '.data[] | {date: .timestamp, close: .close, volume: .volume}' | head -20
    else
        echo -e "${RED}Error fetching historical data${NC}"
    fi
}

# Function to monitor predictions in real-time
monitor_predictions() {
    print_header "Real-time Monitoring (Press Ctrl+C to stop)"
    
    echo "Enter stock symbol to monitor:"
    read -r symbol
    symbol=$(echo "$symbol" | tr '[:lower:]' '[:upper:]')
    
    echo -e "\nMonitoring $symbol predictions every 30 seconds...\n"
    
    while true; do
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        response=$(curl -s "$API_BASE/predict/$symbol")
        echo -n "[$timestamp] "
        print_prediction "$symbol" "$response"
        sleep 30
    done
}

# Function to test API performance
test_performance() {
    print_header "API Performance Test"
    
    echo "Testing API response times..."
    
    # Test multiple requests
    total_time=0
    requests=10
    
    for i in $(seq 1 $requests); do
        start_time=$(date +%s.%N)
        curl -s "$API_BASE/predict/AAPL" > /dev/null
        end_time=$(date +%s.%N)
        
        duration=$(echo "$end_time - $start_time" | bc)
        total_time=$(echo "$total_time + $duration" | bc)
        
        echo "Request $i: ${duration}s"
    done
    
    avg_time=$(echo "scale=3; $total_time / $requests" | bc)
    echo -e "\n${GREEN}Average response time: ${avg_time}s${NC}"
}

# Function to show service statistics
show_statistics() {
    print_header "Service Statistics"
    
    response=$(curl -s "$API_BASE/stats")
    if echo "$response" | jq . >/dev/null 2>&1; then
        echo "$response" | jq .
    else
        echo -e "${RED}Error fetching statistics${NC}"
    fi
}

# Function to clear cache
clear_cache() {
    print_header "Cache Management"
    
    echo "Clearing prediction cache..."
    response=$(curl -s -X POST "$API_BASE/cache/clear")
    
    if echo "$response" | jq . >/dev/null 2>&1; then
        message=$(echo "$response" | jq -r '.message')
        echo -e "${GREEN}$message${NC}"
    else
        echo -e "${RED}Error clearing cache${NC}"
    fi
}

# Main menu
show_menu() {
    echo -e "\n${BLUE}Stock Prediction API Testing Menu${NC}"
    echo "=================================="
    echo "1. Health Check"
    echo "2. Popular Stocks Prediction"
    echo "3. Custom Stocks Prediction"
    echo "4. Lookback Period Comparison"
    echo "5. Historical Data Sample"
    echo "6. Real-time Monitoring"
    echo "7. Performance Test"
    echo "8. Service Statistics"
    echo "9. Clear Cache"
    echo "0. Exit"
    echo ""
}

# Main function
main() {
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}Warning: 'jq' is not installed. JSON output will be raw.${NC}"
        echo "Install jq for better formatted output: sudo apt-get install jq"
        echo ""
    fi
    
    # Check if bc is available (for calculations)
    if ! command -v bc &> /dev/null; then
        echo -e "${YELLOW}Warning: 'bc' is not installed. Percentage calculations will be disabled.${NC}"
        echo "Install bc: sudo apt-get install bc"
        echo ""
    fi
    
    echo -e "${GREEN}Stock Prediction Service API Tester${NC}"
    echo -e "${GREEN}====================================${NC}"
    
    # Quick health check
    if ! curl -s "$API_BASE/health" > /dev/null; then
        echo -e "${RED}Error: Cannot connect to API at $API_BASE${NC}"
        echo "Make sure the service is running on http://localhost:8080"
        exit 1
    fi
    
    while true; do
        show_menu
        read -p "Select an option (0-9): " choice
        
        case $choice in
            1) test_health ;;
            2) test_popular_stocks ;;
            3) test_custom_stocks ;;
            4) test_lookback_periods ;;
            5) show_historical_data ;;
            6) monitor_predictions ;;
            7) test_performance ;;
            8) show_statistics ;;
            9) clear_cache ;;
            0) 
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run main function
main "$@"
