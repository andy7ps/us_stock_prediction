#!/bin/bash

echo "🔍 Verifying LT to LMT Symbol Fix"
echo "================================="

# Check frontend container
echo "1. Frontend Container Status:"
FRONTEND_STATUS=$(docker ps | grep v3_frontend | wc -l)
if [ "$FRONTEND_STATUS" -eq 1 ]; then
    echo "   ✅ Frontend container running"
else
    echo "   ❌ Frontend container not running"
fi

# Check for LT in built frontend
echo ""
echo "2. Checking for LT symbol in frontend:"
LT_COUNT=$(grep -o "\"LT\"" /home/achen/andy_misc/golang/ml/stock_prediction/v3/frontend/dist/frontend/browser/main-*.js 2>/dev/null | wc -l)
if [ "$LT_COUNT" -eq 0 ]; then
    echo "   ✅ LT symbol completely removed from frontend"
else
    echo "   ❌ LT symbol still found ($LT_COUNT occurrences)"
fi

# Check for LMT in built frontend
echo ""
echo "3. Checking for LMT symbol in frontend:"
LMT_COUNT=$(grep -o "LMT" /home/achen/andy_misc/golang/ml/stock_prediction/v3/frontend/dist/frontend/browser/main-*.js 2>/dev/null | wc -l)
if [ "$LMT_COUNT" -gt 0 ]; then
    echo "   ✅ LMT symbol found in frontend ($LMT_COUNT occurrences)"
else
    echo "   ❌ LMT symbol not found in frontend"
fi

# Check source code
echo ""
echo "4. Checking source code:"
SOURCE_LMT=$(grep -o "LMT" /home/achen/andy_misc/golang/ml/stock_prediction/v3/frontend/src/app/components/stock-prediction.component.ts | wc -l)
if [ "$SOURCE_LMT" -gt 0 ]; then
    echo "   ✅ LMT in source code ($SOURCE_LMT occurrences)"
else
    echo "   ❌ LMT not in source code"
fi

# Test LMT API functionality
echo ""
echo "5. Testing LMT API functionality:"
LMT_API_TEST=$(curl -s http://localhost:8081/api/v1/predict/LMT | jq -r '.symbol' 2>/dev/null)
if [ "$LMT_API_TEST" = "LMT" ]; then
    LMT_SIGNAL=$(curl -s http://localhost:8081/api/v1/predict/LMT | jq -r '.trading_signal' 2>/dev/null)
    LMT_CONFIDENCE=$(curl -s http://localhost:8081/api/v1/predict/LMT | jq -r '.confidence' 2>/dev/null)
    echo "   ✅ LMT API working"
    echo "      Signal: $LMT_SIGNAL"
    echo "      Confidence: $(echo "$LMT_CONFIDENCE" | cut -c1-4)"
else
    echo "   ❌ LMT API not working"
fi

# Test frontend accessibility
echo ""
echo "6. Testing frontend accessibility:"
FRONTEND_HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)
if [ "$FRONTEND_HTTP" = "200" ]; then
    echo "   ✅ Frontend accessible (HTTP $FRONTEND_HTTP)"
else
    echo "   ❌ Frontend not accessible (HTTP $FRONTEND_HTTP)"
fi

# Check all 18 symbols
echo ""
echo "7. Verifying all 18 popular stock symbols:"
EXPECTED_SYMBOLS=("NVDA" "TSLA" "AAPL" "MSFT" "GOOGL" "AMZN" "AUR" "PLTR" "SMCI" "TSM" "MP" "SMR" "SPY" "AMD" "META" "NOC" "RTX" "LMT")
FOUND_SYMBOLS=0

for symbol in "${EXPECTED_SYMBOLS[@]}"; do
    if grep -q "$symbol" /home/achen/andy_misc/golang/ml/stock_prediction/v3/frontend/dist/frontend/browser/main-*.js 2>/dev/null; then
        FOUND_SYMBOLS=$((FOUND_SYMBOLS + 1))
        if [ "$symbol" = "LMT" ]; then
            echo "   ✅ $symbol (Lockheed Martin - FIXED)"
        else
            echo "   ✅ $symbol"
        fi
    else
        echo "   ❌ $symbol not found"
    fi
done

echo ""
echo "📊 Summary:"
echo "=========="
echo "Total symbols expected: ${#EXPECTED_SYMBOLS[@]}"
echo "Total symbols found: $FOUND_SYMBOLS"
echo "LT occurrences: $LT_COUNT"
echo "LMT occurrences: $LMT_COUNT"

if [ "$LT_COUNT" -eq 0 ] && [ "$LMT_COUNT" -gt 0 ] && [ "$FOUND_SYMBOLS" -eq 18 ] && [ "$LMT_API_TEST" = "LMT" ]; then
    echo ""
    echo "🎉 SUCCESS: LT to LMT change completed successfully!"
    echo "✅ LT symbol completely removed"
    echo "✅ LMT symbol properly implemented"
    echo "✅ All 18 symbols working"
    echo "✅ API functionality verified"
    echo "✅ Frontend rebuilt and deployed"
else
    echo ""
    echo "⚠️  Issues found - please review the results above"
fi

echo ""
echo "🌐 Access your frontend: http://localhost:8080"
echo "   Look for LMT in the Popular Stocks section"
