#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ClipLite.app"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ZIP_PATH="$DIST_DIR/ClipLite-unsigned.zip"

echo "[1/4] Building release binary..."
cd "$ROOT_DIR"
swift build -c release

echo "[2/4] Preparing app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/release/ClipLite" "$MACOS_DIR/ClipLite"
cp "$ROOT_DIR/ClipLite/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/ClipLite/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$ROOT_DIR/ClipLite/Resources/StatusBarIconTemplate.png" "$RESOURCES_DIR/StatusBarIconTemplate.png"

chmod +x "$MACOS_DIR/ClipLite"

echo "[3/4] Writing zip artifact..."
rm -f "$ZIP_PATH"
(
  cd "$DIST_DIR"
  zip -qry "$(basename "$ZIP_PATH")" "$APP_NAME"
)

echo "[4/4] Done."
ls -lh "$MACOS_DIR/ClipLite" "$RESOURCES_DIR/AppIcon.icns" "$RESOURCES_DIR/StatusBarIconTemplate.png" "$ZIP_PATH"
