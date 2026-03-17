#!/bin/zsh

# リリースビルドスクリプト（nTabula）
#
# ビルド → .app 公証 → DMG 作成 → DMG 公証 → appcast.xml 更新 をワンコマンドで実行する
#
# 使い方:
#   ./scripts/release.sh                              # デフォルト (v1.0.0)
#   VERSION=1.1.0 ./scripts/release.sh                # バージョンを指定
#   VERSION=1.1.0 BUILD_NUMBER=2 ./scripts/release.sh # バージョン + ビルド番号を指定
#
# 出力先:
#   dist/v<VERSION>/nTabula.app
#   dist/v<VERSION>/nTabula.dmg

set -euo pipefail

APP_NAME="nTabula"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APPCAST="$ROOT_DIR/docs/appcast.xml"
GITHUB_RELEASE_BASE="https://github.com/tako3ch/nTabula/releases/download"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
export VERSION BUILD_NUMBER

DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist/v$VERSION}"
export DIST_DIR

echo "==> Release v$VERSION (build $BUILD_NUMBER)"
echo "    出力先: $DIST_DIR"
echo ""

# 1. アーカイブ & エクスポート（署名済み .app を生成）
"$ROOT_DIR/scripts/build_app.sh"

# 2. .app を公証 & ステープル
TARGET="$DIST_DIR/$APP_NAME.app" "$ROOT_DIR/scripts/notarize.sh"

# 3. DMG 作成 + 公証 + ステープル
"$ROOT_DIR/scripts/build_dmg.sh"

# 4. appcast.xml 更新
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

# sign_update は Sparkle の SPM キャッシュ内に存在する
# xcodeproj が一度でもビルドされていれば DerivedData 以下にある
SIGN_UPDATE=$(find "$HOME/Library/Developer/Xcode/DerivedData" \
  -path "*/Sparkle*/bin/sign_update" -maxdepth 10 2>/dev/null | head -1)

if [[ -z "$SIGN_UPDATE" ]]; then
  echo "ERROR: sign_update が見つかりません。" >&2
  echo "       Xcode でプロジェクトを一度ビルドして Sparkle の DerivedData を生成してください。" >&2
  exit 1
fi

echo "==> appcast.xml を更新"

DMG_LENGTH="$(stat -f %z "$DMG_PATH")"
SIGN_UPDATE_OUTPUT="$("$SIGN_UPDATE" "$DMG_PATH" 2>&1)"
ED_SIGNATURE="$(echo "$SIGN_UPDATE_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)"

if [[ -z "$ED_SIGNATURE" ]]; then
  echo "ERROR: sign_update による署名に失敗しました。" >&2
  echo "       sign_update ($SIGN_UPDATE) の出力:" >&2
  echo "$SIGN_UPDATE_OUTPUT" >&2
  echo "       Sparkle の秘密鍵が Keychain に存在するか確認してください（generate_keys を実行）。" >&2
  exit 1
fi

PUB_DATE="$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"
ENCLOSURE_URL="$GITHUB_RELEASE_BASE/v$VERSION/$APP_NAME.dmg"

mkdir -p "$(dirname "$APPCAST")"
cat > "$APPCAST" <<XML
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>$APP_NAME</title>
        <item>
            <title>v$VERSION</title>
            <pubDate>$PUB_DATE</pubDate>
            <sparkle:version>$BUILD_NUMBER</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <enclosure url="$ENCLOSURE_URL" length="$DMG_LENGTH" type="application/octet-stream" sparkle:edSignature="$ED_SIGNATURE"/>
        </item>
    </channel>
</rss>
XML

# dist/ にも同期
cp "$APPCAST" "$ROOT_DIR/dist/appcast.xml"

echo "    appcast.xml 更新完了"
echo "    url:         $ENCLOSURE_URL"
echo "    length:      $DMG_LENGTH"
echo "    edSignature: $ED_SIGNATURE"

echo ""
echo "==> Release complete: $DIST_DIR"
echo "    $APP_NAME.app"
echo "    $APP_NAME.dmg"
echo ""
echo "次のステップ:"
echo "  1. GitHub Release を作成し DMG をアップロード:"
echo "     https://github.com/tako3ch/nTabula/releases/new?tag=v$VERSION"
echo "  2. docs/appcast.xml を git push → GitHub Pages に反映"
