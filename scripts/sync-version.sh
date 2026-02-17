#!/usr/bin/env bash
set -euo pipefail

# Read version from package.json
VERSION=$(node -p "require('./package.json').version")

echo "Syncing version ${VERSION} to Xcode project files..."

# Portable in-place sed (macOS requires -i '', GNU/Linux requires -i)
sedi() { if [[ "$OSTYPE" == darwin* ]]; then sed -i '' "$@"; else sed -i "$@"; fi; }

# Update project.yml
sedi "s/MARKETING_VERSION: \".*\"/MARKETING_VERSION: \"${VERSION}\"/" project.yml
sedi "s/CURRENT_PROJECT_VERSION: \".*\"/CURRENT_PROJECT_VERSION: \"${VERSION}\"/" project.yml

# Update project.pbxproj (unquoted values like: MARKETING_VERSION = 1.0;)
sedi "s/MARKETING_VERSION = .*;/MARKETING_VERSION = ${VERSION};/" StatusBar.xcodeproj/project.pbxproj
sedi "s/CURRENT_PROJECT_VERSION = .*;/CURRENT_PROJECT_VERSION = ${VERSION};/" StatusBar.xcodeproj/project.pbxproj

# Stage the updated files so changesets can commit them
git add project.yml StatusBar.xcodeproj/project.pbxproj

echo "Version synced to ${VERSION}"
