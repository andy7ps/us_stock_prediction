#!/bin/bash

# Version Update Script
# Updates version across all relevant files

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <old_version> <new_version>"
    echo "Example: $0 v3.2.0 v3.3.0"
    exit 1
fi

OLD_VERSION="$1"
NEW_VERSION="$2"

print_status "Updating version from $OLD_VERSION to $NEW_VERSION"

# Check if we're in the right directory
if [ ! -f "main.go" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Files to update
declare -A files_to_update=(
    ["main.go"]="Starting Stock Prediction Service"
    ["main.go"]="\"version\": \"$OLD_VERSION\""
    ["internal/services/prediction/service.go"]="ModelVersion:"
    ["README.md"]="# 📈 US Stock Prediction Service"
    ["README.md"]="Release-$OLD_VERSION"
    ["setup_ml_improvements.sh"]="model_version"
    ["ML_IMPROVEMENTS_README.md"]="ML Model Improvements - Stock Prediction"
)

# Update main.go
print_status "Updating main.go..."
sed -i "s/Starting Stock Prediction Service $OLD_VERSION/Starting Stock Prediction Service $NEW_VERSION/g" main.go
sed -i "s/\"version\": \"$OLD_VERSION\"/\"version\": \"$NEW_VERSION\"/g" main.go

# Update prediction service
print_status "Updating prediction service..."
sed -i "s/ModelVersion:   \"$OLD_VERSION\"/ModelVersion:   \"$NEW_VERSION\"/g" internal/services/prediction/service.go
sed -i "s/\"version\":       \"$OLD_VERSION\"/\"version\":       \"$NEW_VERSION\"/g" internal/services/prediction/service.go

# Update README.md
print_status "Updating README.md..."
sed -i "s/# 📈 US Stock Prediction Service $OLD_VERSION/# 📈 US Stock Prediction Service $NEW_VERSION/g" README.md
sed -i "s/Release-$OLD_VERSION/Release-$NEW_VERSION/g" README.md

# Update setup script
print_status "Updating setup script..."
sed -i "s/\"model_version\": \"$OLD_VERSION\"/\"model_version\": \"$NEW_VERSION\"/g" setup_ml_improvements.sh
sed -i "s/ML_MODEL_VERSION=$OLD_VERSION/ML_MODEL_VERSION=$NEW_VERSION/g" setup_ml_improvements.sh

# Update ML README
if [ -f "ML_IMPROVEMENTS_README.md" ]; then
    print_status "Updating ML README..."
    version_number=$(echo $NEW_VERSION | sed 's/v//' | cut -d'.' -f1,2)
    old_version_number=$(echo $OLD_VERSION | sed 's/v//' | cut -d'.' -f1,2)
    sed -i "s/ML Model Improvements - Stock Prediction v$old_version_number/ML Model Improvements - Stock Prediction v$version_number/g" ML_IMPROVEMENTS_README.md
    sed -i "s/ML_MODEL_VERSION=$OLD_VERSION/ML_MODEL_VERSION=$NEW_VERSION/g" ML_IMPROVEMENTS_README.md
    sed -i "s/\"model_version\": \"$OLD_VERSION\"/\"model_version\": \"$NEW_VERSION\"/g" ML_IMPROVEMENTS_README.md
fi

# Update .env file if it exists
if [ -f ".env" ]; then
    print_status "Updating .env file..."
    sed -i "s/ML_MODEL_VERSION=$OLD_VERSION/ML_MODEL_VERSION=$NEW_VERSION/g" .env
fi

# Update Docker files
for dockerfile in Dockerfile docker-compose*.yml; do
    if [ -f "$dockerfile" ]; then
        print_status "Updating $dockerfile..."
        sed -i "s/$OLD_VERSION/$NEW_VERSION/g" "$dockerfile"
    fi
done

# Create git tag
print_status "Creating git tag..."
if git rev-parse --git-dir > /dev/null 2>&1; then
    git add .
    git commit -m "Update version to $NEW_VERSION" || true
    git tag -a "$NEW_VERSION" -m "Release $NEW_VERSION" || true
    print_success "Git tag $NEW_VERSION created"
else
    print_error "Not a git repository, skipping git operations"
fi

print_success "Version updated successfully from $OLD_VERSION to $NEW_VERSION"

echo
print_status "Updated files:"
echo "  ✓ main.go"
echo "  ✓ internal/services/prediction/service.go"
echo "  ✓ README.md"
echo "  ✓ setup_ml_improvements.sh"
echo "  ✓ ML_IMPROVEMENTS_README.md"
echo "  ✓ .env (if exists)"
echo "  ✓ Docker files"

echo
print_status "Next steps:"
echo "1. Review the changes: git diff"
echo "2. Test the application: ./test_ml_improvements.sh"
echo "3. Update release notes: Create RELEASE_NOTES_$NEW_VERSION.md"
echo "4. Push changes: git push && git push --tags"
