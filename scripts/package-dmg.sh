#!/bin/bash
# 打包 DMG：build/45min Up.app → build/45min-Up-<版本>.dmg（含拖入 Applications 的快捷方式）
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/45min Up.app"
if [ ! -d "$APP" ]; then
  echo "先跑 ./scripts/build-app.sh" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
STAGING="build/dmg-staging"
DMG="build/45min-Up-$VERSION.dmg"

rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "45min Up" -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
codesign --force --sign - "$DMG" >/dev/null 2>&1 || true

echo "✅ $DMG"
echo "   本机安装: open \"$DMG\"，拖入 Applications"
echo "   首次启动需右键 → 打开（未公证的 Gatekeeper 放行）"
