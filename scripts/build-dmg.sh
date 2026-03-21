#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="AI Writing Tools"
SCHEME="AiWritingTools"

# Read version from Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PROJECT_DIR/AiWritingTools/Info.plist")
DMG_NAME="$APP_NAME-$VERSION.dmg"

echo "Building $APP_NAME v$VERSION..."

# Clean and build Release
xcodebuild -scheme "$SCHEME" -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  clean build 2>&1 | tail -5

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
  echo "Error: $APP_PATH not found"
  exit 1
fi

echo "Creating DMG..."

# Remove old DMG if it exists
rm -f "$BUILD_DIR/$DMG_NAME"

create-dmg \
  --volname "$APP_NAME" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "$APP_NAME.app" 150 190 \
  --app-drop-link 450 190 \
  "$BUILD_DIR/$DMG_NAME" \
  "$APP_PATH"

echo ""
echo "Done: $BUILD_DIR/$DMG_NAME"
