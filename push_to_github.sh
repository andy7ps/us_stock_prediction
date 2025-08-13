#!/bin/bash

# GitHub Push Script
# Run this after adding SSH key to GitHub

set -e

echo "🚀 Pushing Stock Prediction ML Improvements to GitHub..."
echo

# Navigate to project directory
cd /home/achen/andy_misc/golang/ml/stock_prediction/v3

# Test SSH connection first
echo "🔑 Testing SSH connection to GitHub..."
if ssh -T git@github.com -o ConnectTimeout=10 2>&1 | grep -q "successfully authenticated"; then
    echo "✅ SSH connection successful!"
else
    echo "❌ SSH connection failed. Please add the SSH key to GitHub first."
    echo
    echo "SSH Public Key to add:"
    echo "----------------------------------------"
    cat ~/.ssh/id_ed25519.pub
    echo "----------------------------------------"
    echo
    echo "Add this key at: https://github.com/settings/keys"
    exit 1
fi

# Show what will be pushed
echo
echo "📊 Commits ready to push:"
git log --oneline -2

echo
echo "📁 Files to be pushed:"
git show --name-only --pretty=format: HEAD | grep -v '^$' | head -10
echo "... and more"

echo
echo "🚀 Pushing to GitHub..."

# Push to GitHub
if git push --set-upstream origin main; then
    echo
    echo "🎉 Successfully pushed to GitHub!"
    echo
    echo "✅ Repository updated with:"
    echo "  - Automatic ML training system"
    echo "  - Performance monitoring"
    echo "  - 13 stock symbol support"
    echo "  - Comprehensive documentation"
    echo
    echo "🔗 View at: https://github.com/andy7ps/us_stock_prediction"
else
    echo
    echo "❌ Push failed. Please check:"
    echo "  1. SSH key is added to GitHub"
    echo "  2. Repository permissions are correct"
    echo "  3. Network connection is stable"
    exit 1
fi

echo
echo "🎯 Next steps:"
echo "  1. Setup automatic training: ./setup_cron_jobs.sh"
echo "  2. Train remaining symbols: ./manage_ml_models.sh train AMZN AUR PLTR SMCI TSM MP SMR SPY"
echo "  3. Monitor system: ./dashboard.sh"
echo
echo "🚀 Your ML system is now on GitHub and ready for production!"
