#!/bin/bash
# Generate all required PNG sizes from source images
# Uses macOS built-in 'sips' for image conversion
# Run from the Logo directory: cd Resources/Logo && bash generate-pngs.sh

set -e

LOGO_DIR="$(cd "$(dirname "$0")" && pwd)"
ASSETS_DIR="$LOGO_DIR/../Assets.xcassets"

echo "=== Agent Command Logo PNG Generator ==="
echo "Source directory: $LOGO_DIR"
echo ""

# --- Icon-only PNGs (from 1024x1024 source) ---
ICON_SRC="$LOGO_DIR/logo-icon-1024x1024.png"
if [ -f "$ICON_SRC" ]; then
    echo "[Icon] Generating icon sizes from 1024x1024 source..."
    ICON_SIZES=(16 32 64 128 256 512)
    for SIZE in "${ICON_SIZES[@]}"; do
        OUT="$LOGO_DIR/logo-icon-${SIZE}x${SIZE}.png"
        if [ ! -f "$OUT" ]; then
            sips -z "$SIZE" "$SIZE" "$ICON_SRC" --out "$OUT" > /dev/null 2>&1
            echo "  Created: logo-icon-${SIZE}x${SIZE}.png"
        else
            echo "  Exists:  logo-icon-${SIZE}x${SIZE}.png"
        fi
    done
else
    echo "[WARN] Missing source: logo-icon-1024x1024.png"
fi

# --- Full logo PNGs (from 1024x1024 source) ---
FULL_SRC="$LOGO_DIR/logo-full-1024x1024.png"
if [ -f "$FULL_SRC" ]; then
    echo ""
    echo "[Full] Generating full logo sizes from 1024x1024 source..."
    FULL_SIZES=(128 256 512)
    for SIZE in "${FULL_SIZES[@]}"; do
        OUT="$LOGO_DIR/logo-full-${SIZE}x${SIZE}.png"
        if [ ! -f "$OUT" ]; then
            sips -z "$SIZE" "$SIZE" "$FULL_SRC" --out "$OUT" > /dev/null 2>&1
            echo "  Created: logo-full-${SIZE}x${SIZE}.png"
        else
            echo "  Exists:  logo-full-${SIZE}x${SIZE}.png"
        fi
    done
else
    echo "[WARN] Missing source: logo-full-1024x1024.png"
fi

# --- AppIcon set (for macOS) ---
echo ""
echo "[AppIcon] Syncing to AppIcon.appiconset..."
APPICON_DIR="$LOGO_DIR/AppIcon.appiconset"
mkdir -p "$APPICON_DIR"

ICON_MAPPINGS=(
    "16:icon_16x16.png"
    "32:icon_32x32.png"
    "64:icon_64x64.png"
    "128:icon_128x128.png"
    "256:icon_256x256.png"
    "512:icon_512x512.png"
    "1024:icon_1024x1024.png"
)

for MAP in "${ICON_MAPPINGS[@]}"; do
    SIZE="${MAP%%:*}"
    FNAME="${MAP##*:}"
    SRC="$LOGO_DIR/logo-icon-${SIZE}x${SIZE}.png"
    DST="$APPICON_DIR/$FNAME"
    if [ -f "$SRC" ]; then
        cp "$SRC" "$DST"
        echo "  Synced: $FNAME"
    fi
done

# --- Sync to Assets.xcassets ---
echo ""
echo "[Assets] Syncing to Assets.xcassets..."

# AppIcon
ASSETS_APPICON="$ASSETS_DIR/AppIcon.appiconset"
if [ -d "$ASSETS_APPICON" ]; then
    cp "$APPICON_DIR"/*.png "$ASSETS_APPICON/" 2>/dev/null
    cp "$APPICON_DIR/Contents.json" "$ASSETS_APPICON/" 2>/dev/null
    echo "  Synced AppIcon.appiconset"
fi

# LogoIcon imageset
ASSETS_ICON="$ASSETS_DIR/LogoIcon.imageset"
if [ -d "$ASSETS_ICON" ]; then
    cp "$LOGO_DIR/logo-icon-128x128.png" "$ASSETS_ICON/logo-icon-1x.png"
    cp "$LOGO_DIR/logo-icon-256x256.png" "$ASSETS_ICON/logo-icon-2x.png"
    cp "$LOGO_DIR/logo-icon-512x512.png" "$ASSETS_ICON/logo-icon-3x.png"
    echo "  Synced LogoIcon.imageset"
fi

# LogoFull imageset
ASSETS_FULL="$ASSETS_DIR/LogoFull.imageset"
if [ -d "$ASSETS_FULL" ]; then
    cp "$LOGO_DIR/logo-full-256x256.png" "$ASSETS_FULL/logo-full-1x.png"
    cp "$LOGO_DIR/logo-full-512x512.png" "$ASSETS_FULL/logo-full-2x.png"
    cp "$LOGO_DIR/logo-full-1024x1024.png" "$ASSETS_FULL/logo-full-3x.png"
    echo "  Synced LogoFull.imageset"
fi

# LogoNavbar imageset
ASSETS_NAVBAR="$ASSETS_DIR/LogoNavbar.imageset"
if [ -d "$ASSETS_NAVBAR" ]; then
    cp "$LOGO_DIR/logo-icon-64x64.png" "$ASSETS_NAVBAR/logo-navbar-1x.png"
    cp "$LOGO_DIR/logo-icon-128x128.png" "$ASSETS_NAVBAR/logo-navbar-2x.png"
    cp "$LOGO_DIR/logo-icon-256x256.png" "$ASSETS_NAVBAR/logo-navbar-3x.png"
    echo "  Synced LogoNavbar.imageset"
fi

echo ""
echo "=== Done! ==="
echo ""
echo "Summary of logo variants:"
echo "  - Favicon (16x16, 32x32, 64x64): For tiny display contexts"
echo "  - Icon (128-1024): App icon, medium displays"
echo "  - Full (256-1024): With branding text"
echo "  - Navbar: Sidebar/toolbar logo"
echo "  - AppIcon: macOS app icon set"
echo ""
echo "SVG variants available:"
echo "  - logo-favicon.svg    : Simplified for small sizes"
echo "  - logo-navbar.svg     : Horizontal with text"
echo "  - logo-splash.svg     : Large splash/hero layout"
echo "  - logo-icon-only.svg  : Icon without text"
echo "  - logo-final.svg      : Full design with branding"
