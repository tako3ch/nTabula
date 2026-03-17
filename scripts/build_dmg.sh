#!/bin/zsh

# DMG 作成スクリプト（nTabula）
#
# 事前条件:
#   build_app.sh → notarize.sh の順で実行済みであること
#
# 使い方:
#   ./scripts/build_dmg.sh
#   VERSION=1.0.0 ./scripts/build_dmg.sh

set -euo pipefail

APP_NAME="nTabula"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-1.0.0}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist/v$VERSION}"
DMG_ROOT="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
APP_DIR="$DIST_DIR/$APP_NAME.app"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-nTabula}"
KEYCHAIN_PATH="${KEYCHAIN_PATH:-$HOME/Library/Keychains/login.keychain-db}"

if [[ ! -d "$APP_DIR" ]]; then
  echo "ERROR: App bundle not found: $APP_DIR" >&2
  echo "先に build_app.sh と notarize.sh を実行してください。" >&2
  exit 1
fi

# 公証済みか確認
if ! spctl --assess --verbose "$APP_DIR" 2>&1 | grep -q "accepted"; then
  echo "ERROR: $APP_DIR が公証されていません。先に notarize.sh を実行してください。" >&2
  exit 1
fi

echo "==> Preparing DMG contents"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
cp -R "$APP_DIR" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

echo "==> Creating DMG at $DMG_PATH"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  -fs "HFS+" \
  "$DMG_PATH"

rm -rf "$DMG_ROOT"

echo "==> Notarizing DMG"
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --keychain "$KEYCHAIN_PATH" \
  --wait

echo "==> Stapling notarization ticket to DMG"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo "Built DMG: $DMG_PATH"
