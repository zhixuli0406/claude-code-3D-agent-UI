#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="AgentCommand"
BUILD_CONFIG="${1:-release}"
BUILD_DIR="$SCRIPT_DIR/.build"
OUTPUT_DIR="$SCRIPT_DIR/dist"

echo "=== AgentCommand - Build App ==="
echo "Configuration: $BUILD_CONFIG"
echo ""

# Build
echo "Building ($BUILD_CONFIG)..."
if [ "$BUILD_CONFIG" = "release" ]; then
    swift build -c release
    EXECUTABLE="$BUILD_DIR/release/$APP_NAME"
else
    swift build
    EXECUTABLE="$BUILD_DIR/debug/$APP_NAME"
fi

if [ ! -f "$EXECUTABLE" ]; then
    echo "Error: Build succeeded but executable not found at $EXECUTABLE"
    exit 1
fi

echo "[OK] Build succeeded"

# Create .app bundle
echo ""
echo "Creating $APP_NAME.app bundle..."

APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"

# Copy bundled resources (SampleConfigs)
BUNDLE_RESOURCES="$BUILD_DIR/$BUILD_CONFIG/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$BUNDLE_RESOURCES" ]; then
    cp -R "$BUNDLE_RESOURCES" "$RESOURCES_DIR/"
fi

# Also copy SampleConfigs directly for fallback loading
SAMPLE_CONFIGS="$SCRIPT_DIR/AgentCommand/Resources/SampleConfigs"
if [ -d "$SAMPLE_CONFIGS" ]; then
    cp -R "$SAMPLE_CONFIGS" "$RESOURCES_DIR/"
fi

# Write Info.plist
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AgentCommand</string>
    <key>CFBundleIdentifier</key>
    <string>com.agentcommand.app</string>
    <key>CFBundleName</key>
    <string>Agent Command</string>
    <key>CFBundleDisplayName</key>
    <string>Agent Command</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
</dict>
</plist>
PLIST

echo "[OK] $APP_NAME.app created at: $OUTPUT_DIR/$APP_NAME.app"

# Print summary
APP_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)
echo ""
echo "=== Build complete ==="
echo "  App:    $APP_BUNDLE"
echo "  Size:   $APP_SIZE"
echo ""
echo "Run with:"
echo "  open $OUTPUT_DIR/$APP_NAME.app"
