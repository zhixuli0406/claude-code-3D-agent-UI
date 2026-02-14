#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="AgentCommand"
INSTALL_DIR="/Applications"

echo "=== AgentCommand - Install ==="
echo ""

# Check Swift toolchain
if ! command -v swift &> /dev/null; then
    echo "Error: Swift is not installed."
    echo "Install Xcode or Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

SWIFT_VERSION=$(swift --version 2>&1 | head -1)
echo "[OK] $SWIFT_VERSION"

# Check macOS version (requires 14+)
MACOS_VERSION=$(sw_vers -productVersion)
MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
if [ "$MAJOR" -lt 14 ]; then
    echo "Error: macOS 14 (Sonoma) or later is required. Current: $MACOS_VERSION"
    exit 1
fi
echo "[OK] macOS $MACOS_VERSION"

# Resolve dependencies
echo ""
echo "Resolving dependencies..."
swift package resolve

# Build release
echo ""
echo "Building release..."
swift build -c release

EXECUTABLE="$SCRIPT_DIR/.build/release/$APP_NAME"
if [ ! -f "$EXECUTABLE" ]; then
    echo "Error: Build failed - executable not found."
    exit 1
fi
echo "[OK] Build succeeded"

# Create .app bundle
echo ""
echo "Packaging $APP_NAME.app..."

APP_BUNDLE="$SCRIPT_DIR/dist/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"

# Copy bundled resources
BUNDLE_RESOURCES="$SCRIPT_DIR/.build/release/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "$BUNDLE_RESOURCES" ]; then
    cp -R "$BUNDLE_RESOURCES" "$RESOURCES_DIR/"
fi

SAMPLE_CONFIGS="$SCRIPT_DIR/AgentCommand/Resources/SampleConfigs"
if [ -d "$SAMPLE_CONFIGS" ]; then
    cp -R "$SAMPLE_CONFIGS" "$RESOURCES_DIR/"
fi

# Generate .icns app icon from PNGs
ICON_SRC="$SCRIPT_DIR/AgentCommand/Resources/Logo/AppIcon.appiconset"
if [ -d "$ICON_SRC" ]; then
    echo "Generating app icon..."
    ICONSET_DIR="$SCRIPT_DIR/dist/AppIcon.iconset"
    rm -rf "$ICONSET_DIR"
    mkdir -p "$ICONSET_DIR"

    cp "$ICON_SRC/icon_16x16.png"     "$ICONSET_DIR/icon_16x16.png"
    cp "$ICON_SRC/icon_32x32.png"     "$ICONSET_DIR/icon_16x16@2x.png"
    cp "$ICON_SRC/icon_32x32.png"     "$ICONSET_DIR/icon_32x32.png"
    cp "$ICON_SRC/icon_64x64.png"     "$ICONSET_DIR/icon_32x32@2x.png"
    cp "$ICON_SRC/icon_128x128.png"   "$ICONSET_DIR/icon_128x128.png"
    cp "$ICON_SRC/icon_256x256.png"   "$ICONSET_DIR/icon_128x128@2x.png"
    cp "$ICON_SRC/icon_256x256.png"   "$ICONSET_DIR/icon_256x256.png"
    cp "$ICON_SRC/icon_512x512.png"   "$ICONSET_DIR/icon_256x256@2x.png"
    cp "$ICON_SRC/icon_512x512.png"   "$ICONSET_DIR/icon_512x512.png"
    cp "$ICON_SRC/icon_1024x1024.png" "$ICONSET_DIR/icon_512x512@2x.png"

    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
    rm -rf "$ICONSET_DIR"
    echo "[OK] App icon generated"
else
    echo "[WARN] AppIcon source not found at $ICON_SRC, skipping icon generation"
fi

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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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

echo "[OK] App bundle created"

# Install to /Applications
echo ""
echo "Installing to $INSTALL_DIR..."
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi
cp -R "$APP_BUNDLE" "$INSTALL_DIR/"

echo "[OK] Installed to $INSTALL_DIR/$APP_NAME.app"

APP_SIZE=$(du -sh "$INSTALL_DIR/$APP_NAME.app" | cut -f1)

echo ""
echo "=== Install complete ==="
echo "  Location: $INSTALL_DIR/$APP_NAME.app"
echo "  Size:     $APP_SIZE"
echo ""
echo "Launch with:"
echo "  open /Applications/$APP_NAME.app"
