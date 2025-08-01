#!/bin/bash

# Docker Hub Upload Script for Stock Prediction Service
# Usage: ./upload_to_dockerhub.sh YOUR_DOCKERHUB_USERNAME

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <dockerhub-username>"
    echo "Example: $0 johndoe"
    exit 1
fi

DOCKERHUB_USERNAME=$1
IMAGE_NAME="stock-prediction"
LOCAL_TAG="v3"

echo "🐳 Docker Hub Upload Script"
echo "=========================="
echo "Username: $DOCKERHUB_USERNAME"
echo "Image: $IMAGE_NAME"
echo "Tag: $LOCAL_TAG"
echo ""

# Check if the local image exists
if ! docker images | grep -q "$IMAGE_NAME.*$LOCAL_TAG"; then
    echo "❌ Error: Local image $IMAGE_NAME:$LOCAL_TAG not found!"
    echo "Please build the image first with: make docker-build"
    exit 1
fi

echo "✅ Local image found: $IMAGE_NAME:$LOCAL_TAG"

# Tag the image for Docker Hub
echo "🏷️  Tagging image for Docker Hub..."
docker tag $IMAGE_NAME:$LOCAL_TAG $DOCKERHUB_USERNAME/$IMAGE_NAME:$LOCAL_TAG
docker tag $IMAGE_NAME:$LOCAL_TAG $DOCKERHUB_USERNAME/$IMAGE_NAME:latest

echo "✅ Tagged images:"
docker images | grep "$DOCKERHUB_USERNAME/$IMAGE_NAME"

# Push to Docker Hub
echo ""
echo "📤 Pushing to Docker Hub..."
echo "Pushing $DOCKERHUB_USERNAME/$IMAGE_NAME:$LOCAL_TAG..."
docker push $DOCKERHUB_USERNAME/$IMAGE_NAME:$LOCAL_TAG

echo "Pushing $DOCKERHUB_USERNAME/$IMAGE_NAME:latest..."
docker push $DOCKERHUB_USERNAME/$IMAGE_NAME:latest

echo ""
echo "🎉 Successfully uploaded to Docker Hub!"
echo "Your image is now available at:"
echo "   https://hub.docker.com/r/$DOCKERHUB_USERNAME/$IMAGE_NAME"
echo ""
echo "To pull your image from anywhere:"
echo "   docker pull $DOCKERHUB_USERNAME/$IMAGE_NAME:$LOCAL_TAG"
echo "   docker pull $DOCKERHUB_USERNAME/$IMAGE_NAME:latest"
echo ""
echo "To run your image:"
echo "   docker run -p 8080:8080 $DOCKERHUB_USERNAME/$IMAGE_NAME:latest"
