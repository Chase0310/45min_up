#!/bin/bash
# 组装 ad-hoc 签名的 .app（本机 CLT 无 Xcode，见 ADR-0001）
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/45min Up.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp .build/release/StandUp "$APP/Contents/MacOS/StandUp"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>StandUp</string>
    <key>CFBundleIdentifier</key><string>com.chase0310.45minup</string>
    <key>CFBundleName</key><string>45min Up</string>
    <key>CFBundleDisplayName</key><string>45min Up</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.2</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSUserNotificationsUsageDescription</key>
    <string>站立提醒的兜底通知通道（刘海层不可见时使用）</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null 2>&1

echo "✅ $APP 已构建并完成 ad-hoc 签名"
echo "   启动: open \"$APP\""
