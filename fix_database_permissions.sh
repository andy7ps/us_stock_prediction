#!/bin/bash

# Fix Database Permissions for Docker Container
# This script ensures the database files have the correct ownership for the Docker container

set -e

echo "🔧 Fixing database permissions for Docker container..."

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATABASE_DIR="$SCRIPT_DIR/database_data"

# Check if database directory exists
if [ ! -d "$DATABASE_DIR" ]; then
    echo "❌ Database directory not found: $DATABASE_DIR"
    exit 1
fi

# The Docker container runs as user 1001 (appuser)
DOCKER_USER_ID=1001
DOCKER_GROUP_ID=1001

echo "📁 Database directory: $DATABASE_DIR"
echo "👤 Setting ownership to UID:GID $DOCKER_USER_ID:$DOCKER_GROUP_ID"

# Fix ownership of database directory and files
sudo chown -R $DOCKER_USER_ID:$DOCKER_GROUP_ID "$DATABASE_DIR"

# Ensure proper permissions
sudo chmod -R 755 "$DATABASE_DIR"
sudo chmod 664 "$DATABASE_DIR"/*.db 2>/dev/null || true

echo "✅ Database permissions fixed successfully!"

# Show current permissions
echo ""
echo "📋 Current permissions:"
ls -la "$DATABASE_DIR"

echo ""
echo "🎯 The database files are now owned by the Docker container user (1001:1001)"
echo "   This should resolve the 'readonly database' error in the frontend."
