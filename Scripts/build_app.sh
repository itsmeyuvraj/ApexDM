#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "🚀 Building ApexDM (Apple Silicon Native Release)..."
swift build -c release --arch arm64

BIN_PATH="$DIR/.build/arm64-apple-macosx/release/ApexDM"
if [ ! -f "$BIN_PATH" ]; then
    BIN_PATH="$DIR/.build/release/ApexDM"
fi

APP_BUNDLE="$DIR/build/ApexDM.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "📦 Assembling macOS App Bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$BIN_PATH" "$MACOS_DIR/ApexDM"
chmod +x "$MACOS_DIR/ApexDM"

# Copy Info.plist
cp "$DIR/Resources/Info.plist" "$CONTENTS/Info.plist"

# Copy Icon
if [ -f "$DIR/Resources/AppIcon.icns" ]; then
    cp "$DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Create PkgInfo
echo "APPL????" > "$CONTENTS/PkgInfo"

# Ad-hoc codesign
echo "🔏 Code-signing bundle (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ ApexDM.app build complete!"
echo "📍 Location: $APP_BUNDLE"
echo "💡 You can launch it now by running: open \"$APP_BUNDLE\""
