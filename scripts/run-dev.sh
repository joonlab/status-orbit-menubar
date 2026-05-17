#!/usr/bin/env bash
# Status Orbit — 개발용 실행 스크립트
# 1) swift build (debug)
# 2) .app 번들 구조로 패키징 (Info.plist 포함)
# 3) open .app
set -euo pipefail

cd "$(dirname "$0")/../src"

echo "▶ Building (debug)…"
swift build

BIN=".build/debug/StatusOrbit"
APP="../dist/StatusOrbit.app"

if [ ! -f "$BIN" ]; then
  echo "✘ Build output not found: $BIN" >&2
  exit 1
fi

echo "▶ Packaging .app bundle…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/StatusOrbit"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# ad-hoc codesign (개발 중에는 필수: NSStatusItem 동작에 필요)
echo "▶ Ad-hoc signing…"
codesign --force --deep --sign - "$APP" 2>&1 | sed 's/^/  /' || true

echo "▶ Opening…"
# 이전 인스턴스 종료
killall StatusOrbit 2>/dev/null || true
sleep 0.3
open "$APP"

echo "✔ Done. 메뉴바 우측 상단에서 회색 점 아이콘을 확인하세요."
echo "  종료하려면: killall StatusOrbit"
