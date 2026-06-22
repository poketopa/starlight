#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Starlight"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
ZIP_PATH="$ROOT_DIR/dist/$APP_NAME.zip"
NOTARY_KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-starlight-notary}"

: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION, e.g. Developer ID Application: Name (TEAMID)}"

DEVELOPER_ID_APPLICATION="$DEVELOPER_ID_APPLICATION" "$ROOT_DIR/scripts/build-app.sh"

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
  --wait

xcrun stapler staple "$APP_DIR"
spctl --assess --type execute --verbose=4 "$APP_DIR"

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo "Notarized and packaged: $ZIP_PATH"
