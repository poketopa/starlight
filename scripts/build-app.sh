#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Starlight"
CONFIGURATION="${CONFIGURATION:-release}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_RESOURCES_DIR="$ROOT_DIR/icon/Resources"
SWIFT_BUILD_DIR="$ROOT_DIR/.build/$APP_NAME"
SWIFT_CACHE_DIR="$ROOT_DIR/.build/$APP_NAME-cache"

if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$SWIFT_BUILD_DIR/module-cache}"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION" --scratch-path "$SWIFT_BUILD_DIR" --cache-path "$SWIFT_CACHE_DIR"
BIN_DIR="$(swift build -c "$CONFIGURATION" --scratch-path "$SWIFT_BUILD_DIR" --cache-path "$SWIFT_CACHE_DIR" --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
install -m 0644 "$ICON_RESOURCES_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
install -m 0644 "$ICON_RESOURCES_DIR/MenuBarIcon.imageset/MenuBarIconTemplate.png" "$RESOURCES_DIR/MenuBarIconTemplate.png"
install -m 0644 "$ICON_RESOURCES_DIR/MenuBarIcon.imageset/MenuBarIconTemplate@2x.png" "$RESOURCES_DIR/MenuBarIconTemplate@2x.png"
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

chmod +x "$MACOS_DIR/$APP_NAME"

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  codesign \
    --force \
    --timestamp \
    --options runtime \
    --entitlements "$ROOT_DIR/Resources/Starlight.entitlements" \
    --sign "$DEVELOPER_ID_APPLICATION" \
    "$APP_DIR"
else
  codesign --force --deep --sign - "$APP_DIR"
fi

echo "Built $APP_DIR"
