#!/usr/bin/env bash
set -euo pipefail

# Read version from package.json
VERSION=$(node -p "require('./package.json').version")

echo "Syncing version ${VERSION} to Xcode project files..."

# Update project.yml
sed -i '' "s/MARKETING_VERSION: \".*\"/MARKETING_VERSION: \"${VERSION}\"/" project.yml
sed -i '' "s/CURRENT_PROJECT_VERSION: \".*\"/CURRENT_PROJECT_VERSION: \"${VERSION}\"/" project.yml

# Update project.pbxproj (unquoted values like: MARKETING_VERSION = 1.0;)
sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = ${VERSION};/" StatusBar.xcodeproj/project.pbxproj
sed -i '' "s/CURRENT_PROJECT_VERSION = .*;/CURRENT_PROJECT_VERSION = ${VERSION};/" StatusBar.xcodeproj/project.pbxproj

# Stage the updated files so changesets can commit them
git add project.yml StatusBar.xcodeproj/project.pbxproj

echo "Version synced to ${VERSION}"
