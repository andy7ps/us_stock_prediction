#!/bin/bash

# GitHub Repository Setup Script
# Repository: us_stock_prediction
# Owner: andy7ps

echo "🚀 Setting up GitHub repository: us_stock_prediction"
echo "=================================================="

# Repository details
REPO_NAME="us_stock_prediction"
GITHUB_USERNAME="andy7ps"
REPO_URL="https://github.com/${GITHUB_USERNAME}/${REPO_NAME}.git"

echo "📋 Repository Information:"
echo "   Name: ${REPO_NAME}"
echo "   Owner: ${GITHUB_USERNAME}"
echo "   URL: ${REPO_URL}"
echo ""

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "❌ Error: Not in a git repository"
    echo "   Please run this script from the project root directory"
    exit 1
fi

# Check git configuration
echo "🔧 Checking git configuration..."
GIT_USER=$(git config user.name)
GIT_EMAIL=$(git config user.email)

if [ "$GIT_USER" != "andy7ps" ] || [ "$GIT_EMAIL" != "andy7ps@eland.idv.tw" ]; then
    echo "⚙️  Configuring git user..."
    git config user.name "andy7ps"
    git config user.email "andy7ps@eland.idv.tw"
    echo "✅ Git user configured"
else
    echo "✅ Git user already configured correctly"
fi

# Add GitHub-specific files
echo "📝 Adding GitHub-specific files..."

# Replace README.md with GitHub version
if [ -f "README_GITHUB.md" ]; then
    cp README_GITHUB.md README.md
    echo "✅ Updated README.md for GitHub"
fi

# Add all changes
echo "📦 Adding all files to git..."
git add -A

# Check if there are changes to commit
if git diff --staged --quiet; then
    echo "ℹ️  No changes to commit"
else
    echo "💾 Committing GitHub setup changes..."
    git commit -m "Prepare repository for GitHub

- Add comprehensive GitHub README with badges and documentation
- Add MIT LICENSE file
- Update repository structure for GitHub
- Prepare for initial GitHub push"
fi

# Show current status
echo ""
echo "📊 Current Repository Status:"
echo "   Branch: $(git branch --show-current)"
echo "   Commits: $(git rev-list --count HEAD)"
echo "   Tags: $(git tag -l | wc -l)"
echo "   Latest tag: $(git describe --tags --abbrev=0 2>/dev/null || echo 'None')"

echo ""
echo "🎯 Next Steps:"
echo "1. Create the repository on GitHub:"
echo "   - Go to https://github.com/new"
echo "   - Repository name: us_stock_prediction"
echo "   - Description: Enterprise-grade US stock prediction service with ML and persistent storage"
echo "   - Make it Public (recommended) or Private"
echo "   - DO NOT initialize with README, .gitignore, or license (we already have them)"
echo ""
echo "2. Add the remote and push:"
echo "   git remote add origin ${REPO_URL}"
echo "   git branch -M main"
echo "   git push -u origin main"
echo "   git push origin --tags"
echo ""
echo "3. Or run the automated push (after creating the repository):"
echo "   ./push_to_github.sh"

# Create automated push script
cat > push_to_github.sh << 'EOF'
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
EOF

chmod +x push_to_github.sh

echo ""
echo "✅ GitHub setup complete!"
echo "📁 Created files:"
echo "   - README.md (GitHub version)"
echo "   - LICENSE (MIT)"
echo "   - setup_github.sh (this script)"
echo "   - push_to_github.sh (automated push script)"
echo ""
echo "🎯 Ready for GitHub! Follow the next steps above."
