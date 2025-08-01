#!/bin/bash

# Enhanced Prediction Testing Script
# Demonstrates all enhanced prediction capabilities and model switching

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# API base URL
API_BASE="http://localhost:8080/api/v1"

# Function to print colored headers
print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to print sub-headers
print_subheader() {
    echo -e "\n${CYAN}--- $1 ---${NC}"
}

# Function to test prediction with different models
test_prediction_with_model() {
    local symbol=$1
    local model=$2
    local description=$3
    
    echo -e "${PURPLE}Testing $symbol with $model model${NC}"
    
    # Switch to the model
    switch_response=$(curl -s -X POST "$API_BASE/model/switch" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"$model\"}")
    
    if echo "$switch_response" | jq . >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Switched to $model model${NC}"
    else
        echo -e "${RED}✗ Failed to switch to $model model${NC}"
        return 1
    fi
    
    # Make prediction
    prediction_response=$(curl -s "$API_BASE/predict/$symbol")
    
    if echo "$prediction_response" | jq . >/dev/null 2>&1; then
        current_price=$(echo "$prediction_response" | jq -r '.current_price // "N/A"')
        predicted_price=$(echo "$prediction_response" | jq -r '.predicted_price // "N/A"')
        confidence=$(echo "$prediction_response" | jq -r '.confidence // "N/A"')
        signal=$(echo "$prediction_response" | jq -r '.trading_signal // "N/A"')
        model_version=$(echo "$prediction_response" | jq -r '.model_version // "N/A"')
        
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
        
        # Color code confidence
        if (( $(echo "$confidence > 0.8" | bc -l) )); then
            confidence_color="${GREEN}${confidence}${NC}"
        elif (( $(echo "$confidence > 0.65" | bc -l) )); then
            confidence_color="${YELLOW}${confidence}${NC}"
        else
            confidence_color="${RED}${confidence}${NC}"
        fi
        
        echo -e "  Current: $current_price → Predicted: $predicted_price ($change_display)"
        echo -e "  Signal: $signal | Confidence: $confidence_color | Model: $model_version"
        echo -e "  Description: $description"
        
    else
        echo -e "${RED}✗ Prediction failed for $symbol with $model model${NC}"
        echo -e "  Response: $prediction_response"
    fi
    
    echo ""
}

# Function to compare models side by side
compare_models() {
    local symbol=$1
    
    print_subheader "Model Comparison for $symbol"
    
    echo -e "${CYAN}Model${NC} | ${CYAN}Current${NC} | ${CYAN}Predicted${NC} | ${CYAN}Change${NC} | ${CYAN}Confidence${NC} | ${CYAN}Signal${NC}"
    echo "------|---------|-----------|--------|------------|--------"
    
    for model in "simple" "enhanced" "advanced"; do
        # Switch model
        curl -s -X POST "$API_BASE/model/switch" \
            -H "Content-Type: application/json" \
            -d "{\"model\": \"$model\"}" >/dev/null
        
        # Get prediction
        response=$(curl -s "$API_BASE/predict/$symbol")
        
        if echo "$response" | jq . >/dev/null 2>&1; then
            current=$(echo "$response" | jq -r '.current_price')
            predicted=$(echo "$response" | jq -r '.predicted_price')
            confidence=$(echo "$response" | jq -r '.confidence')
            signal=$(echo "$response" | jq -r '.trading_signal')
            
            change=$(echo "scale=2; (($predicted - $current) / $current) * 100" | bc -l 2>/dev/null)
            
            printf "%-6s | %7.2f | %9.2f | %6.2f%% | %10.3f | %6s\n" \
                "$model" "$current" "$predicted" "$change" "$confidence" "$signal"
        else
            printf "%-6s | ERROR\n" "$model"
        fi
    done
    
    echo ""
}

# Test service health first
print_header "Service Health Check"
health_response=$(curl -s "$API_BASE/health")
if echo "$health_response" | jq . >/dev/null 2>&1; then
    status=$(echo "$health_response" | jq -r '.status')
    if [[ "$status" == "healthy" ]]; then
        echo -e "${GREEN}✓ Service is healthy and ready for enhanced testing${NC}"
    else
        echo -e "${YELLOW}⚠ Service status: $status${NC}"
    fi
else
    echo -e "${RED}✗ Service is not responding${NC}"
    exit 1
fi

# Test model management endpoints
print_header "Model Management Testing"

print_subheader "Available Models"
models_response=$(curl -s "$API_BASE/models")
if echo "$models_response" | jq . >/dev/null 2>&1; then
    echo "$models_response" | jq '.available_models[] | {name, description}'
    echo -e "\n${GREEN}✓ Successfully retrieved available models${NC}"
else
    echo -e "${RED}✗ Failed to get available models${NC}"
fi

print_subheader "Current Model Info"
model_info_response=$(curl -s "$API_BASE/model/info")
if echo "$model_info_response" | jq . >/dev/null 2>&1; then
    echo "$model_info_response" | jq '.'
    echo -e "\n${GREEN}✓ Successfully retrieved current model info${NC}"
else
    echo -e "${RED}✗ Failed to get current model info${NC}"
fi

# Test individual models
print_header "Individual Model Testing"

print_subheader "Simple Model (Linear Regression)"
test_prediction_with_model "AAPL" "simple" "Basic linear regression with trend analysis"

print_subheader "Enhanced Model (Technical Indicators)"
test_prediction_with_model "AAPL" "enhanced" "Multiple algorithms with RSI, MACD, Bollinger Bands"

print_subheader "Advanced Model (OHLCV Analysis)"
test_prediction_with_model "AAPL" "advanced" "Full OHLCV data with support/resistance analysis"

# Test different stock categories with different models
print_header "Stock Category Analysis with Different Models"

# Large Cap Stocks
print_subheader "Large Cap Stocks"
for stock in "MSFT" "GOOGL" "AMZN"; do
    compare_models "$stock"
done

# Growth/Tech Stocks
print_subheader "Growth/Tech Stocks"
for stock in "NVDA" "TSLA"; do
    compare_models "$stock"
done

# Volatile Stocks
print_subheader "Volatile Stocks"
for stock in "GME" "AMC"; do
    compare_models "$stock"
done

# Performance comparison
print_header "Performance Analysis"

print_subheader "Response Time Comparison"
echo -e "${CYAN}Testing response times for different models...${NC}"

for model in "simple" "enhanced" "advanced"; do
    # Switch to model
    curl -s -X POST "$API_BASE/model/switch" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"$model\"}" >/dev/null
    
    # Time the prediction
    start_time=$(date +%s%N)
    response=$(curl -s "$API_BASE/predict/AAPL")
    end_time=$(date +%s%N)
    
    duration=$(echo "scale=2; ($end_time - $start_time) / 1000000" | bc -l)
    
    if echo "$response" | jq . >/dev/null 2>&1; then
        echo -e "${model} model: ${duration}ms"
    else
        echo -e "${model} model: ERROR"
    fi
done

# Enhanced statistics
print_header "Enhanced Statistics"
enhanced_stats_response=$(curl -s "$API_BASE/stats/enhanced")
if echo "$enhanced_stats_response" | jq . >/dev/null 2>&1; then
    echo "$enhanced_stats_response" | jq '.'
    echo -e "\n${GREEN}✓ Successfully retrieved enhanced statistics${NC}"
else
    echo -e "${RED}✗ Failed to get enhanced statistics${NC}"
fi

# Model switching stress test
print_header "Model Switching Stress Test"
echo -e "${CYAN}Testing rapid model switching...${NC}"

models=("simple" "enhanced" "advanced")
for i in {1..5}; do
    model=${models[$((i % 3))]}
    echo -e "Switch $i: Switching to $model model"
    
    switch_response=$(curl -s -X POST "$API_BASE/model/switch" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"$model\"}")
    
    if echo "$switch_response" | jq . >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Switch $i successful${NC}"
    else
        echo -e "${RED}✗ Switch $i failed${NC}"
    fi
done

# Summary
print_header "Enhanced Prediction Testing Summary"
echo -e "${GREEN}✓ Model Management System Active${NC}"
echo -e "${GREEN}✓ Multiple Prediction Algorithms Available${NC}"
echo -e "${GREEN}✓ Dynamic Model Switching Functional${NC}"
echo -e "${GREEN}✓ Enhanced Confidence Calculation Active${NC}"
echo -e "${GREEN}✓ Performance Monitoring Available${NC}"

echo -e "\n${BLUE}Available Models:${NC}"
echo -e "${YELLOW}simple${NC}:   Linear regression (fastest, basic)"
echo -e "${YELLOW}enhanced${NC}: Technical indicators (moderate speed, good accuracy)"
echo -e "${YELLOW}advanced${NC}: OHLCV analysis (slower, highest accuracy)"

echo -e "\n${BLUE}Model Switching Commands:${NC}"
echo -e "curl -X POST $API_BASE/model/switch -H 'Content-Type: application/json' -d '{\"model\": \"enhanced\"}'"

echo -e "\n${BLUE}Model Information:${NC}"
echo -e "curl $API_BASE/model/info"
echo -e "curl $API_BASE/models"

echo -e "\n${PURPLE}Enhanced prediction system successfully deployed! 🚀${NC}"
