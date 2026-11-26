#!/bin/sh
# Собирает ThreeFingers.app и кладёт в /Applications
set -e
cd "$(dirname "$0")"
APP=/Applications/ThreeFingers.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp AppIcon.icns "$APP/Contents/Resources/"
swiftc -O main.swift -o "$APP/Contents/MacOS/ThreeFingers"
cat > "$APP/Contents/Info.plist" <<P
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.threefingers</string>
<key>CFBundleName</key><string>ThreeFingers</string>
<key>CFBundleExecutable</key><string>ThreeFingers</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
<key>CFBundleIconFile</key><string>AppIcon</string>
</dict></plist>
P
codesign -f -s - "$APP"
