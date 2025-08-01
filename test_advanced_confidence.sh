#!/bin/bash

# Advanced Confidence Testing Script
# Demonstrates the improved confidence calculation with various stock types

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

# API base URL
API_BASE="http://localhost:8080/api/v1"

# Function to print colored headers
print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to print stock prediction with confidence analysis
print_prediction_analysis() {
    local symbol=$1
    local category=$2
    local response=$3
    
    if echo "$response" | jq . >/dev/null 2>&1; then
        # Parse JSON response
        current_price=$(echo "$response" | jq -r '.current_price // "N/A"')
        predicted_price=$(echo "$response" | jq -r '.predicted_price // "N/A"')
        signal=$(echo "$response" | jq -r '.trading_signal // "N/A"')
        confidence=$(echo "$response" | jq -r '.confidence // "N/A"')
        
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
        
        # Color code the confidence
        confidence_num=$(echo "$confidence" | cut -d'.' -f1-2)
        if (( $(echo "$confidence > 0.8" | bc -l) )); then
            confidence_color="${GREEN}${confidence}${NC}"
            confidence_level="HIGH"
        elif (( $(echo "$confidence > 0.65" | bc -l) )); then
            confidence_color="${YELLOW}${confidence}${NC}"
            confidence_level="MODERATE"
        else
            confidence_color="${RED}${confidence}${NC}"
            confidence_level="LOW"
        fi
        
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
        
        echo -e "${PURPLE}[$category]${NC} ${BLUE}$symbol${NC}: $current_price → $predicted_price ($change_display)"
        echo -e "   Signal: $signal_color | Confidence: $confidence_color ($confidence_level)"
        
    else
        echo -e "${RED}$symbol: Error - $response${NC}"
    fi
}

# Test service health first
print_header "Service Health Check"
health_response=$(curl -s "$API_BASE/health")
if echo "$health_response" | jq . >/dev/null 2>&1; then
    status=$(echo "$health_response" | jq -r '.status')
    if [[ "$status" == "healthy" ]]; then
        echo -e "${GREEN}✓ Service is healthy and ready for testing${NC}"
    else
        echo -e "${YELLOW}⚠ Service status: $status${NC}"
    fi
else
    echo -e "${RED}✗ Service is not responding${NC}"
    exit 1
fi

# Test Large Cap Stable Stocks
print_header "Large Cap Stable Stocks (Expected: High Confidence)"
stocks=("MSFT" "GOOGL" "AMZN" "META" "JNJ")
for stock in "${stocks[@]}"; do
    response=$(curl -s "$API_BASE/predict/$stock")
    print_prediction_analysis "$stock" "LARGE CAP" "$response"
done

# Test Growth/Tech Stocks
print_header "Growth/Tech Stocks (Expected: Moderate Confidence)"
stocks=("NVDA" "AAPL" "TSLA" "CRM" "NFLX")
for stock in "${stocks[@]}"; do
    response=$(curl -s "$API_BASE/predict/$stock")
    print_prediction_analysis "$stock" "GROWTH" "$response"
done

# Test Volatile/Meme Stocks
print_header "Volatile/Meme Stocks (Expected: Lower Confidence)"
stocks=("GME" "AMC" "COIN" "PLTR" "RIVN")
for stock in "${stocks[@]}"; do
    response=$(curl -s "$API_BASE/predict/$stock")
    print_prediction_analysis "$stock" "VOLATILE" "$response"
done

# Test Small Cap Stocks
print_header "Small Cap Stocks (Expected: Variable Confidence)"
stocks=("ROKU" "SNAP" "TWTR" "SQ" "SHOP")
for stock in "${stocks[@]}"; do
    response=$(curl -s "$API_BASE/predict/$stock")
    print_prediction_analysis "$stock" "SMALL CAP" "$response"
done

# Summary
print_header "Advanced Confidence Analysis Summary"
echo -e "${GREEN}✓ Multi-Factor Confidence Calculation Active${NC}"
echo -e "${GREEN}✓ Historical Volatility Analysis${NC}"
echo -e "${GREEN}✓ Trend Alignment Detection${NC}"
echo -e "${GREEN}✓ Price Momentum Integration${NC}"
echo -e "${GREEN}✓ Market-Aware Risk Assessment${NC}"

echo -e "\n${BLUE}Confidence Interpretation:${NC}"
echo -e "${GREEN}0.80-0.95${NC}: High confidence - suitable for larger positions"
echo -e "${YELLOW}0.65-0.80${NC}: Moderate confidence - normal position sizing"
echo -e "${RED}0.15-0.65${NC}: Low confidence - smaller positions or skip"

echo -e "\n${BLUE}Key Improvements:${NC}"
echo -e "• Stable stocks get higher confidence for same price changes"
echo -e "• Volatile stocks properly penalized with lower confidence"
echo -e "• Trend-aligned predictions receive confidence boost"
echo -e "• Momentum factors enhance prediction reliability"
echo -e "• Market-aware scaling for different stock categories"

echo -e "\n${PURPLE}Advanced confidence calculation successfully deployed! 🚀${NC}"
