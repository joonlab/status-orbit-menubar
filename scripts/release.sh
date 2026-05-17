#!/usr/bin/env bash
# Status Orbit — Release 빌드 + DMG 패키징
# 산출물: dist/StatusOrbit.app, dist/StatusOrbit-<ver>.dmg, dist/StatusOrbit-<ver>.dmg.sha256
set -euo pipefail

cd "$(dirname "$0")/.."
PROJ_ROOT="$(pwd)"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" src/Resources/Info.plist)
APP_NAME="StatusOrbit"
APP="$PROJ_ROOT/dist/$APP_NAME.app"
DMG="$PROJ_ROOT/dist/$APP_NAME-$VERSION.dmg"
TMP_DMG_DIR="$PROJ_ROOT/dist/dmg-staging"

echo "▶ Version: $VERSION"

# 1) Release build
echo "▶ swift build -c release …"
(cd src && swift build -c release)

BIN="src/.build/release/$APP_NAME"
[ -f "$BIN" ] || { echo "✘ Build output not found: $BIN" >&2; exit 1; }

BIN_KB=$(du -k "$BIN" | awk '{print $1}')
echo "  binary size: ${BIN_KB} KB"

# 2) .app bundle 패키징
echo "▶ Packaging .app …"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
cp src/Resources/Info.plist "$APP/Contents/Info.plist"

# 3) ad-hoc codesign (외부 배포용 Developer ID 사인은 별도)
echo "▶ Ad-hoc codesign …"
codesign --force --deep --sign - "$APP" 2>&1 | sed 's/^/  /' || true

# 4) DMG 패키징 (drag-to-Applications 레이아웃)
echo "▶ Building DMG …"
rm -f "$DMG"
rm -rf "$TMP_DMG_DIR"
mkdir -p "$TMP_DMG_DIR"
cp -R "$APP" "$TMP_DMG_DIR/"
ln -s /Applications "$TMP_DMG_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$TMP_DMG_DIR" \
  -ov \
  -format UDZO \
  "$DMG" >/dev/null

rm -rf "$TMP_DMG_DIR"

# 5) SHA256
SHA=$(shasum -a 256 "$DMG" | awk '{print $1}')
echo "$SHA  $(basename "$DMG")" > "$DMG.sha256"

DMG_KB=$(du -k "$DMG" | awk '{print $1}')

echo ""
echo "════════════════════════════════════════"
echo "✔  Release 빌드 완료"
echo "    .app  : $APP (${BIN_KB} KB)"
echo "    .dmg  : $DMG (${DMG_KB} KB)"
echo "    sha256: $SHA"
echo "════════════════════════════════════════"
