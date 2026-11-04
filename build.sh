#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$DIR/PanelPower.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$DIR/Info.plist" "$APP_DIR/Contents/Info.plist"

echo "Compiling PanelPower for Intel Mac (x86_64)..."
swiftc -O \
  -target x86_64-apple-macos14.0 \
  -sdk "$(xcrun --show-sdk-path)" \
  "$DIR/src/Models.swift" \
  "$DIR/src/AppSettings.swift" \
  "$DIR/src/HomeAssistantService.swift" \
  "$DIR/src/LiveChartView.swift" \
  "$DIR/src/DashboardView.swift" \
  "$DIR/src/SettingsView.swift" \
  "$DIR/src/AppDelegate.swift" \
  "$DIR/src/main.swift" \
  -o "$MACOS_DIR/PanelPower"

echo "Signing PanelPower.app..."
codesign --force --deep --sign - "$APP_DIR"

echo "Packaging PanelPower-macOS.zip..."
rm -f "$DIR/PanelPower-macOS.zip"
(cd "$DIR" && zip -r -q "PanelPower-macOS.zip" "PanelPower.app" "Tuya_Zigbee_Metering_Plug.groovy" "HOW_TO_INSTALL.txt" -x "*.DS_Store")

echo "Installing to /Applications/PanelPower.app..."
rm -rf /Applications/PanelPower.app
cp -R "$APP_DIR" /Applications/PanelPower.app

echo "Build & Installation complete: /Applications/PanelPower.app"
