#!/bin/zsh

# アプリビルドスクリプト（nTabula）
#
# 使い方:
#   ./scripts/build_app.sh
#   VERSION=1.1.0 BUILD_NUMBER=2 ./scripts/build_app.sh
#
# 出力先:
#   dist/v<VERSION>/nTabula.app

set -euo pipefail

APP_NAME="nTabula"
SCHEME="nTabula"
CONFIGURATION="${CONFIGURATION:-Release}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist/v$VERSION}"
ARCHIVE_PATH="$DIST_DIR/$APP_NAME.xcarchive"
APP_DIR="$DIST_DIR/$APP_NAME.app"
EXPORT_OPTIONS="$ROOT_DIR/scripts/ExportOptions.plist"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: UMI.DESIGN LIMITED LIABILITY COMPANY (95U36FYLHZ)}"

mkdir -p "$DIST_DIR"

echo "==> Archiving $APP_NAME v$VERSION (build $BUILD_NUMBER)"
xcodebuild archive \
  -project "$ROOT_DIR/nTabula.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  CODE_SIGN_STYLE="Manual" \
  DEVELOPMENT_TEAM="95U36FYLHZ"

echo "==> Exporting app bundle"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$DIST_DIR" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

# exportArchive は exportPath 直下に .app を出力する
if [[ ! -d "$APP_DIR" ]]; then
  echo "ERROR: App bundle not found after export: $APP_DIR" >&2
  exit 1
fi

codesign --verify --deep --strict "$APP_DIR"
echo "Built app: $APP_DIR"
