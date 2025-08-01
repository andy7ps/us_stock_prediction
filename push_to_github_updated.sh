#!/bin/bash

echo "🚀 Pushing US Stock Prediction Service v3.1.0 to GitHub"
echo "======================================================"

REPO_NAME="us_stock_prediction"
GITHUB_USERNAME="andy7ps"
REPO_URL="https://github.com/${GITHUB_USERNAME}/${REPO_NAME}.git"

echo "📋 Repository Information:"
echo "   Name: ${REPO_NAME}"
echo "   Owner: ${GITHUB_USERNAME}"
echo "   URL: ${REPO_URL}"
echo ""

# Check if we're in the right directory
if [ ! -f "main.go" ] || [ ! -f "RELEASE_NOTES_v3.1.md" ]; then
    echo "❌ Error: Not in the correct project directory"
    echo "   Please run this script from the stock prediction project root"
    exit 1
fi

# Verify git status
echo "🔍 Checking git status..."
if [ ! -d ".git" ]; then
    echo "❌ Error: Not a git repository"
    exit 1
fi

# Check for uncommitted changes
if ! git diff --quiet || ! git diff --staged --quiet; then
    echo "⚠️  Warning: You have uncommitted changes"
    echo "   Committing changes first..."
    git add -A
    git commit -m "Final updates before GitHub push"
fi

# Show current status
echo "📊 Current Status:"
echo "   Branch: $(git branch --show-current)"
echo "   Commits: $(git rev-list --count HEAD)"
echo "   Latest commit: $(git log -1 --oneline)"
echo "   Tags: $(git tag -l)"
echo ""

# Remove any existing remote
if git remote get-url origin >/dev/null 2>&1; then
    echo "🔧 Removing existing remote..."
    git remote remove origin
fi

# Add fresh remote
echo "🔗 Adding GitHub remote..."
git remote add origin "$REPO_URL"

# Verify we're on main branch
current_branch=$(git branch --show-current)
if [ "$current_branch" != "main" ]; then
    echo "🌿 Switching to main branch..."
    git branch -M main
fi

# Test remote connection
echo "🔍 Testing GitHub repository connection..."
if git ls-remote origin >/dev/null 2>&1; then
    echo "✅ GitHub repository found and accessible"
else
    echo "❌ Cannot connect to GitHub repository"
    echo ""
    echo "🎯 Please make sure you have:"
    echo "   1. Created the repository on GitHub: https://github.com/new"
    echo "   2. Repository name: us_stock_prediction"
    echo "   3. Owner: andy7ps"
    echo "   4. Left initialization options UNCHECKED"
    echo ""
    echo "📝 After creating the repository, run this script again"
    exit 1
fi

# Push main branch
echo "📤 Pushing main branch to GitHub..."
if git push -u origin main; then
    echo "✅ Successfully pushed main branch"
else
    echo "❌ Failed to push main branch"
    echo "   This might be due to authentication issues"
    echo "   You may need to:"
    echo "   1. Set up GitHub authentication (SSH keys or personal access token)"
    echo "   2. Or push manually using GitHub Desktop or web interface"
    exit 1
fi

# Push tags
echo "🏷️  Pushing tags to GitHub..."
if git push origin --tags; then
    echo "✅ Successfully pushed tags"
else
    echo "⚠️  Warning: Failed to push tags (this is usually okay for first push)"
fi

echo ""
echo "🎉 SUCCESS! Repository pushed to GitHub!"
echo "🔗 Repository URL: https://github.com/${GITHUB_USERNAME}/${REPO_NAME}"
echo ""
echo "📋 What's now available on GitHub:"
echo "   ✅ Complete source code"
echo "   ✅ Professional README with badges"
echo "   ✅ MIT License"
echo "   ✅ Release notes v3.1.0"
echo "   ✅ Comprehensive documentation"
echo "   ✅ Docker configuration"
echo "   ✅ Monitoring setup"
echo "   ✅ Persistent storage system"
echo ""
echo "🎯 Next steps:"
echo "   1. Visit: https://github.com/${GITHUB_USERNAME}/${REPO_NAME}"
echo "   2. Create a release for v3.1.0"
echo "   3. Add repository topics: golang, machine-learning, docker, stocks"
echo "   4. Star your own repository! ⭐"
echo ""
echo "🚀 Your Stock Prediction Service is now live on GitHub!"
