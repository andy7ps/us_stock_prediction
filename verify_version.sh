#!/bin/bash

# Version Verification Script for Stock Prediction Service v3.1.0
# This script verifies that all version references have been updated correctly

echo "🔍 Stock Prediction Service v3.1.0 - Version Verification"
echo "=========================================================="

# Check version in main.go
echo "📁 Checking main.go..."
if grep -q "v3.1.0" main.go; then
    echo "✅ main.go version updated correctly"
else
    echo "❌ main.go version not updated"
fi

# Check version in handlers
echo "📁 Checking handlers.go..."
if grep -q "v3.1.0" internal/handlers/handlers.go; then
    echo "✅ handlers.go version updated correctly"
else
    echo "❌ handlers.go version not updated"
fi

# Check version in prediction services
echo "📁 Checking prediction services..."
if grep -q "v3.1.0" internal/services/prediction/service.go; then
    echo "✅ prediction service.go version updated correctly"
else
    echo "❌ prediction service.go version not updated"
fi

# Check version in integration test
echo "📁 Checking integration test..."
if grep -q "v3.1.0" integration_test.go; then
    echo "✅ integration_test.go version updated correctly"
else
    echo "❌ integration_test.go version not updated"
fi

# Check git tag
echo "📁 Checking git tag..."
if git tag -l | grep -q "v3.1.0"; then
    echo "✅ Git tag v3.1.0 exists"
    echo "📋 Tag details:"
    git show v3.1.0 --no-patch | head -10
else
    echo "❌ Git tag v3.1.0 not found"
fi

echo ""
echo "🎉 Version verification complete!"
echo "📊 Current release: Stock Prediction Service v3.1.0"
echo "🏷️  Git tag: v3.1.0"
echo "📅 Release date: $(date '+%Y-%m-%d')"
