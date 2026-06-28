#!/usr/bin/env bash
# Cursor Timeline を .app バンドルに固める（Clippo と同じ流儀）。
set -euo pipefail

APP_NAME="CursorTimeline"
DISPLAY_NAME="Cursor Timeline"
BUILD_NUM="$(date +%Y%m%d%H%M%S)"
CONFIG="release"
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$ROOT/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

echo "Building ($CONFIG)..."
swift build -c "$CONFIG"
BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"

echo "Packaging ${APP_DIR}..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.retocrooman.CursorTimeline</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUM}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "Signing the app bundle..."
if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    codesign --force --options runtime --sign "$CODESIGN_IDENTITY" "$APP_DIR"
else
    FOUND_ID="$(security find-identity -p codesigning 2>/dev/null | awk '/"Clippo Dev"/ {print $2; exit}')"
    if [[ -z "$FOUND_ID" ]]; then
        FOUND_ID="$(security find-identity -p codesigning 2>/dev/null | awk '/^[[:space:]]*[0-9]+\)/ {print $2; exit}')"
    fi
    if [[ -n "$FOUND_ID" ]]; then
        codesign --force --options runtime --sign "$FOUND_ID" "$APP_DIR"
    else
        codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || echo "warning: codesign skipped"
    fi
fi

echo "Done: $APP_DIR"
echo "Run: open \"$APP_DIR\""
