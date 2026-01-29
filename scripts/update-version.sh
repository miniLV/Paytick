#!/bin/bash

# Script to release a new version
# Usage: ./scripts/update-version.sh <version>
# Example: ./scripts/update-version.sh 1.0.6
#
# This script will:
# 1. Update MARKETING_VERSION in Xcode project
# 2. Commit the change
# 3. Create and push the tag
# 4. Push to master

set -e

PROJECT_FILE="Paytick/Paytick.xcodeproj/project.pbxproj"

# Check if version is provided
if [ -z "$1" ]; then
    echo "Usage: ./scripts/update-version.sh <version>"
    echo "Example: ./scripts/update-version.sh 1.0.6"
    exit 1
fi

VERSION="$1"
TAG_NAME="v$VERSION"

echo "🚀 Releasing version $VERSION..."

# Check if tag already exists
if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    echo "Error: Tag $TAG_NAME already exists"
    exit 1
fi

# Update MARKETING_VERSION
echo "📝 Updating MARKETING_VERSION to $VERSION"
sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $VERSION;/g" "$PROJECT_FILE"

# Commit
echo "💾 Committing changes..."
git add "$PROJECT_FILE"
git commit -m "chore: bump version to $VERSION"

# Create tag
echo "🏷️  Creating tag $TAG_NAME..."
git tag "$TAG_NAME"

# Push
echo "📤 Pushing to remote..."
git push origin master
git push origin "$TAG_NAME"

echo "✅ Done! Version $VERSION released successfully."
echo "   Tag $TAG_NAME points to the commit with correct version."
