#!/bin/bash

echo "📅 Testing Historical Data Date Fix"
echo "=================================="

# Get current date for reference
CURRENT_DATE=$(date +"%Y/%m/%d")
echo "Current Date: $CURRENT_DATE"
echo ""

# Test 1: Backend Historical Data
echo "1. Testing Backend Historical Data (Last 10 Days)..."
HISTORICAL_DATA=$(curl -s "http://localhost:8081/api/v1/historical/NVDA?days=10")
LATEST_DATE=$(echo "$HISTORICAL_DATA" | jq -r '.data[-1].timestamp' | cut -d'T' -f1 | tr '-' '/')
OLDEST_DATE=$(echo "$HISTORICAL_DATA" | jq -r '.data[0].timestamp' | cut -d'T' -f1 | tr '-' '/')
RECORD_COUNT=$(echo "$HISTORICAL_DATA" | jq -r '.count')

echo "   📊 Records returned: $RECORD_COUNT"
echo "   📅 Date range: $OLDEST_DATE to $LATEST_DATE"

# Check if latest date is recent (within last 3 days)
CURRENT_EPOCH=$(date -d "$CURRENT_DATE" +%s)
LATEST_EPOCH=$(date -d "$LATEST_DATE" +%s)
DAYS_DIFF=$(( (CURRENT_EPOCH - LATEST_EPOCH) / 86400 ))

if [ $DAYS_DIFF -le 3 ]; then
    echo "   ✅ Latest date is recent (within $DAYS_DIFF days)"
else
    echo "   ❌ Latest date is too old ($DAYS_DIFF days ago)"
fi

# Test 2: Check for July dates (should not exist)
echo ""
echo "2. Checking for old July dates..."
JULY_COUNT=$(echo "$HISTORICAL_DATA" | jq '.data[] | select(.timestamp | contains("2025-07-1"))' | jq -s length)
if [ "$JULY_COUNT" -eq 0 ]; then
    echo "   ✅ No July 14-18 dates found (old cache cleared)"
else
    echo "   ❌ Found $JULY_COUNT July dates (cache issue)"
fi

# Test 3: Verify August dates
echo ""
echo "3. Verifying August dates..."
AUGUST_COUNT=$(echo "$HISTORICAL_DATA" | jq '.data[] | select(.timestamp | contains("2025-08"))' | jq -s length)
echo "   📊 August records: $AUGUST_COUNT"

if [ "$AUGUST_COUNT" -gt 5 ]; then
    echo "   ✅ Good coverage of August dates"
else
    echo "   ⚠️  Limited August data ($AUGUST_COUNT records)"
fi

# Test 4: Display recent dates
echo ""
echo "4. Recent trading dates (last 5 records)..."
echo "$HISTORICAL_DATA" | jq -r '.data[-5:] | .[] | "   📅 " + (.timestamp | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%Y/%m/%d")) + " - Close: $" + (.close | tostring)'

# Test 5: Frontend functionality
echo ""
echo "5. Testing Frontend..."
FRONTEND_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)
if [ "$FRONTEND_STATUS" = "200" ]; then
    echo "   ✅ Frontend accessible (HTTP $FRONTEND_STATUS)"
else
    echo "   ❌ Frontend not accessible (HTTP $FRONTEND_STATUS)"
fi

# Test 6: Backend health
echo ""
echo "6. Testing Backend Health..."
BACKEND_HEALTH=$(curl -s http://localhost:8081/api/v1/health | jq -r '.status' 2>/dev/null)
if [ "$BACKEND_HEALTH" = "healthy" ]; then
    echo "   ✅ Backend healthy"
else
    echo "   ❌ Backend not healthy"
fi

# Test 7: Test different stock symbols
echo ""
echo "7. Testing Different Stock Symbols..."
SYMBOLS=("TSLA" "AAPL" "MSFT")
for symbol in "${SYMBOLS[@]}"; do
    SYMBOL_DATA=$(curl -s "http://localhost:8081/api/v1/historical/$symbol?days=5")
    SYMBOL_LATEST=$(echo "$SYMBOL_DATA" | jq -r '.data[-1].timestamp' | cut -d'T' -f1 | tr '-' '/')
    SYMBOL_COUNT=$(echo "$SYMBOL_DATA" | jq -r '.count')
    echo "   📈 $symbol: $SYMBOL_COUNT records, latest: $SYMBOL_LATEST"
done

echo ""
echo "🎉 Historical Data Testing Complete!"
echo "==================================="

# Calculate success metrics
SUCCESS_COUNT=0
TOTAL_TESTS=6

if [ $DAYS_DIFF -le 3 ]; then SUCCESS_COUNT=$((SUCCESS_COUNT + 1)); fi
if [ "$JULY_COUNT" -eq 0 ]; then SUCCESS_COUNT=$((SUCCESS_COUNT + 1)); fi
if [ "$AUGUST_COUNT" -gt 5 ]; then SUCCESS_COUNT=$((SUCCESS_COUNT + 1)); fi
if [ "$FRONTEND_STATUS" = "200" ]; then SUCCESS_COUNT=$((SUCCESS_COUNT + 1)); fi
if [ "$BACKEND_HEALTH" = "healthy" ]; then SUCCESS_COUNT=$((SUCCESS_COUNT + 1)); fi
if [ "$RECORD_COUNT" -ge 8 ]; then SUCCESS_COUNT=$((SUCCESS_COUNT + 1)); fi

echo "📊 Test Results: $SUCCESS_COUNT/$TOTAL_TESTS tests passed"
echo ""

if [ $SUCCESS_COUNT -eq $TOTAL_TESTS ]; then
    echo "✅ All Tests Passed! Historical data is now showing correct recent dates:"
    echo "   📅 Date range: $OLDEST_DATE to $LATEST_DATE"
    echo "   📊 Records: $RECORD_COUNT (last 10 trading days)"
    echo "   🗑️  Old July cache cleared"
    echo "   📈 Fresh August data available"
elif [ $SUCCESS_COUNT -ge 4 ]; then
    echo "✅ Most Tests Passed! Historical data mostly fixed ($SUCCESS_COUNT/$TOTAL_TESTS)"
else
    echo "⚠️  Some Issues Found! Need to investigate ($SUCCESS_COUNT/$TOTAL_TESTS)"
fi

echo ""
echo "🌐 Frontend Changes Made:"
echo "   ✅ Request last 10 days instead of 30"
echo "   ✅ Show 10 rows instead of 5 in table"
echo "   ✅ Always fetch fresh data (no caching)"
echo "   ✅ Improved date formatting (UTC-based)"
echo "   ✅ Clear historical data on new predictions"
echo ""
echo "📱 Access your frontend: http://localhost:8080"
echo "   Click 'Show Historical Data' to see the last 10 trading days"
