#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Starlight"
REPO="poketopa/starlight"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
ZIP_NAME="$APP_NAME.zip"
DOWNLOAD_URL="${STARLIGHT_DOWNLOAD_URL:-https://github.com/$REPO/releases/latest/download/$ZIP_NAME}"
OPEN_APP="${STARLIGHT_OPEN:-1}"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

if ! command -v curl >/dev/null 2>&1; then
  echo "error: curl is required" >&2
  exit 1
fi

if ! command -v ditto >/dev/null 2>&1; then
  echo "error: ditto is required" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"

echo "Downloading $APP_NAME..."
curl -fL "$DOWNLOAD_URL" -o "$TMP_DIR/$ZIP_NAME"

echo "Installing to $INSTALL_DIR..."
ditto -x -k "$TMP_DIR/$ZIP_NAME" "$TMP_DIR"

if [[ ! -d "$TMP_DIR/$APP_NAME.app" ]]; then
  echo "error: $APP_NAME.app was not found in the downloaded archive" >&2
  exit 1
fi

rm -rf "$INSTALL_DIR/$APP_NAME.app"
ditto "$TMP_DIR/$APP_NAME.app" "$INSTALL_DIR/$APP_NAME.app"

echo "$APP_NAME installed at $INSTALL_DIR/$APP_NAME.app"

if [[ "$OPEN_APP" != "0" ]]; then
  open "$INSTALL_DIR/$APP_NAME.app"
fi
