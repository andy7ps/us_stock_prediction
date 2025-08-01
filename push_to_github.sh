#!/bin/bash

echo "🚀 Pushing to GitHub: us_stock_prediction"
echo "========================================"

REPO_URL="https://github.com/andy7ps/us_stock_prediction.git"

# Check if remote exists
if git remote get-url origin >/dev/null 2>&1; then
    echo "✅ Remote 'origin' already exists"
else
    echo "🔗 Adding remote origin..."
    git remote add origin $REPO_URL
fi

# Rename branch to main (GitHub standard)
echo "🌿 Setting up main branch..."
git branch -M main

# Push main branch
echo "📤 Pushing main branch..."
if git push -u origin main; then
    echo "✅ Successfully pushed main branch"
else
    echo "❌ Failed to push main branch"
    echo "   Make sure you've created the repository on GitHub first"
    exit 1
fi

# Push tags
echo "🏷️  Pushing tags..."
if git push origin --tags; then
    echo "✅ Successfully pushed tags"
else
    echo "⚠️  Warning: Failed to push tags (this is usually okay)"
fi

echo ""
echo "🎉 Repository successfully pushed to GitHub!"
echo "🔗 Repository URL: https://github.com/andy7ps/us_stock_prediction"
echo "📋 You can now:"
echo "   - View your repository: https://github.com/andy7ps/us_stock_prediction"
echo "   - Clone it elsewhere: git clone $REPO_URL"
echo "   - Share it with others"
echo "   - Set up GitHub Actions for CI/CD"
