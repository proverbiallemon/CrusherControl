#!/bin/bash
# Build script for Crusher Control menu bar app

set -e

APP_NAME="CrusherControl"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

echo "Building ${APP_NAME}..."

# Clean
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Create app bundle structure
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy Info.plist
cp Info.plist "${APP_BUNDLE}/Contents/"

# Compile Swift files
echo "Compiling Swift..."
swiftc \
    -o "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" \
    -framework Cocoa \
    -framework IOBluetooth \
    -target arm64-apple-macos12.0 \
    -O \
    main.swift \
    AppDelegate.swift \
    CrusherConnection.swift \
    PopoverViewController.swift \
    UpdateChecker.swift

# Sign the app (ad-hoc for local use)
echo "Signing..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo ""
echo "Build complete: ${APP_BUNDLE}"
echo ""
echo "To run: open ${APP_BUNDLE}"
echo "To install: cp -r ${APP_BUNDLE} /Applications/"
