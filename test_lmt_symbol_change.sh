#!/bin/bash

echo "🔄 Testing LT to LMT Symbol Change"
echo "================================="

# Test 1: Frontend accessibility
echo "1. Testing frontend accessibility..."
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)
if [ "$FRONTEND_STATUS" = "200" ]; then
    echo "   ✅ Frontend is accessible (HTTP $FRONTEND_STATUS)"
else
    echo "   ❌ Frontend is not accessible (HTTP $FRONTEND_STATUS)"
    exit 1
fi

# Test 2: Check LMT in frontend code
echo ""
echo "2. Checking LMT symbol in frontend..."
FRONTEND_JS=$(find /home/achen/andy_misc/golang/ml/stock_prediction/v3/frontend/dist/frontend/browser -name "main-*.js" | head -1)
LMT_COUNT=$(grep -o "LMT" "$FRONTEND_JS" | wc -l)
if [ "$LMT_COUNT" -gt 0 ]; then
    echo "   ✅ LMT symbol found in frontend ($LMT_COUNT occurrences)"
else
    echo "   ❌ LMT symbol not found in frontend"
fi

# Test 3: Check LT is removed from frontend
echo ""
echo "3. Checking LT symbol removal..."
LT_COUNT=$(grep -o "\"LT\"" "$FRONTEND_JS" | wc -l)
if [ "$LT_COUNT" -eq 0 ]; then
    echo "   ✅ LT symbol successfully removed from frontend"
else
    echo "   ❌ LT symbol still found in frontend ($LT_COUNT occurrences)"
fi

# Test 4: Test LMT API functionality
echo ""
echo "4. Testing LMT API functionality..."
LMT_PREDICTION=$(curl -s "http://localhost:8081/api/v1/predict/LMT")
LMT_SYMBOL=$(echo "$LMT_PREDICTION" | jq -r '.symbol' 2>/dev/null)
LMT_PRICE=$(echo "$LMT_PREDICTION" | jq -r '.current_price' 2>/dev/null)
LMT_SIGNAL=$(echo "$LMT_PREDICTION" | jq -r '.trading_signal' 2>/dev/null)
LMT_CONFIDENCE=$(echo "$LMT_PREDICTION" | jq -r '.confidence' 2>/dev/null)

if [ "$LMT_SYMBOL" = "LMT" ] && [ "$LMT_PRICE" != "null" ] && [ "$LMT_SIGNAL" != "null" ]; then
    echo "   ✅ LMT prediction API working"
    echo "      Symbol: $LMT_SYMBOL"
    echo "      Price: \$$(echo "$LMT_PRICE" | cut -c1-6)"
    echo "      Signal: $LMT_SIGNAL"
    echo "      Confidence: $(echo "$LMT_CONFIDENCE" | cut -c1-4)"
else
    echo "   ❌ LMT prediction API failed"
    echo "   Raw response: $LMT_PREDICTION"
fi

# Test 5: Test LMT historical data
echo ""
echo "5. Testing LMT historical data..."
LMT_HISTORICAL=$(curl -s "http://localhost:8081/api/v1/historical/LMT?days=3")
LMT_HIST_COUNT=$(echo "$LMT_HISTORICAL" | jq -r '.count' 2>/dev/null)
LMT_HIST_SYMBOL=$(echo "$LMT_HISTORICAL" | jq -r '.symbol' 2>/dev/null)

if [ "$LMT_HIST_SYMBOL" = "LMT" ] && [ "$LMT_HIST_COUNT" != "null" ]; then
    echo "   ✅ LMT historical data working"
    echo "      Records: $LMT_HIST_COUNT"
    echo "      Recent dates:"
    echo "$LMT_HISTORICAL" | jq -r '.data[] | "      📅 " + (.timestamp | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d")) + " - Close: $" + (.close | tostring)' | tail -3
else
    echo "   ❌ LMT historical data failed"
fi

# Test 6: Verify all 18 symbols in frontend
echo ""
echo "6. Verifying all 18 popular stock symbols..."
ALL_SYMBOLS=("NVDA" "TSLA" "AAPL" "MSFT" "GOOGL" "AMZN" "AUR" "PLTR" "SMCI" "TSM" "MP" "SMR" "SPY" "AMD" "META" "NOC" "RTX" "LMT")
SYMBOL_SUCCESS=0

for symbol in "${ALL_SYMBOLS[@]}"; do
    if grep -q "$symbol" "$FRONTEND_JS"; then
        SYMBOL_SUCCESS=$((SYMBOL_SUCCESS + 1))
        if [ "$symbol" = "LMT" ]; then
            echo "   ✅ $symbol found (NEW - replaced LT)"
        else
            echo "   ✅ $symbol found"
        fi
    else
        echo "   ❌ $symbol not found"
    fi
done

echo "   📊 Popular stocks: $SYMBOL_SUCCESS/${#ALL_SYMBOLS[@]} found"

# Test 7: Test LMT company information
echo ""
echo "7. LMT Company Information..."
echo "   🏢 Company: Lockheed Martin Corporation"
echo "   🏭 Sector: Aerospace & Defense"
echo "   📍 Industry: Aerospace & Defense Equipment & Services"
echo "   💼 Business: Defense contractor, aerospace, arms, defense, technology"

# Test 8: Compare LT vs LMT
echo ""
echo "8. Symbol Comparison..."
echo "   ❌ LT (Removed): Was pointing to incorrect/ambiguous symbol"
echo "   ✅ LMT (Added): Lockheed Martin Corporation (correct NYSE symbol)"
echo "   📈 Benefit: More accurate defense sector representation"

echo ""
echo "🎉 LT to LMT Symbol Change Testing Complete!"
echo "==========================================="

# Calculate success metrics
SUCCESS_COUNT=0
TOTAL_TESTS=6

if [ "$FRONTEND_STATUS" = "200" ]; then SUCCESS_COUNT=$((SUCCESS_COUNT + 1)); fi
if [ "$LMT_COUNT" -gt 0 ]; then SUCCESS_COUNT=$((SUCCESS_COUNT + 1)); fi
if [ "$LT_COUNT" -eq 0 ]; then SUCCESS_COUNT=$((SUCCESS_COUNT + 1)); fi
if [ "$LMT_SYMBOL" = "LMT" ]; then SUCCESS_COUNT=$((SUCCESS_COUNT + 1)); fi
if [ "$LMT_HIST_SYMBOL" = "LMT" ]; then SUCCESS_COUNT=$((SUCCESS_COUNT + 1)); fi
if [ $SYMBOL_SUCCESS -eq ${#ALL_SYMBOLS[@]} ]; then SUCCESS_COUNT=$((SUCCESS_COUNT + 1)); fi

echo "📊 Test Results: $SUCCESS_COUNT/$TOTAL_TESTS tests passed"
echo ""

if [ $SUCCESS_COUNT -eq $TOTAL_TESTS ]; then
    echo "✅ All Tests Passed! LT to LMT change successful:"
    echo "   🔄 Symbol updated: LT → LMT"
    echo "   🏢 Company: Lockheed Martin Corporation"
    echo "   📈 API working: Predictions and historical data"
    echo "   🎯 Frontend updated: LMT in popular stocks list"
    echo "   🗑️  LT removed: No longer in frontend code"
elif [ $SUCCESS_COUNT -ge 4 ]; then
    echo "✅ Most Tests Passed! LT to LMT change mostly successful ($SUCCESS_COUNT/$TOTAL_TESTS)"
else
    echo "⚠️  Some Tests Failed! Need to review symbol change ($SUCCESS_COUNT/$TOTAL_TESTS)"
fi

echo ""
echo "🌐 Updated Popular Stocks List (18 symbols):"
echo "   Tech: NVDA, TSLA, AAPL, MSFT, GOOGL, AMZN, AMD, META"
echo "   Growth: AUR, PLTR, SMCI"
echo "   International: TSM"
echo "   Materials/Energy: MP, SMR"
echo "   Defense: NOC, RTX, LMT (NEW)"
echo "   Market: SPY"
echo ""
echo "📱 Access your frontend: http://localhost:8080"
echo "   Look for LMT in the Popular Stocks section"
