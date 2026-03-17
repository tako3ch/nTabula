#!/bin/zsh

# 公証（Notarization）& ステープルスクリプト
#
# 事前準備（初回のみ）:
#   xcrun notarytool store-credentials "nTabula" \
#     --apple-id "your@apple.com" \
#     --team-id "95U36FYLHZ" \
#     --password "<app-specific-password>" \
#     --keychain "$HOME/Library/Keychains/login.keychain-db"
#
# 使い方:
#   TARGET=dist/v1.0.0/nTabula.app ./scripts/notarize.sh   # .app を公証
#   TARGET=dist/v1.0.0/nTabula.dmg ./scripts/notarize.sh   # DMG を公証

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-1.0.0}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist/v$VERSION}"
TARGET="${TARGET:-$DIST_DIR/nTabula.app}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-nTabula}"
KEYCHAIN_PATH="${KEYCHAIN_PATH:-$HOME/Library/Keychains/login.keychain-db}"

if [[ ! -e "$TARGET" ]]; then
  echo "ERROR: Target not found: $TARGET" >&2
  exit 1
fi

if [[ ! -f "$KEYCHAIN_PATH" ]]; then
  echo "ERROR: Keychain not found: $KEYCHAIN_PATH" >&2
  exit 1
fi

# .app は ZIP に固めてから提出
if [[ "$TARGET" == *.app ]]; then
  ZIP_PATH="$DIST_DIR/_notarize_upload.zip"
  echo "==> Creating ZIP for notarization"
  ditto -c -k --keepParent "$TARGET" "$ZIP_PATH"
  SUBMIT_PATH="$ZIP_PATH"
else
  SUBMIT_PATH="$TARGET"
fi

echo "==> Validating notarization credentials"
xcrun notarytool history \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --keychain "$KEYCHAIN_PATH" >/dev/null

echo "==> Submitting for notarization: $SUBMIT_PATH"
xcrun notarytool submit "$SUBMIT_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --keychain "$KEYCHAIN_PATH" \
  --wait

[[ -n "${ZIP_PATH:-}" ]] && rm -f "$ZIP_PATH"

echo "==> Stapling notarization ticket to: $TARGET"
xcrun stapler staple "$TARGET"
xcrun stapler validate "$TARGET"

echo "Notarization complete: $TARGET"
