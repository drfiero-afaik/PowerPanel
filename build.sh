#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$DIR/PanelPower.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
APP_VERSION="v1.1.1"
DRIVER_VERSION="v2.2.2"
SDK_PATH="$(xcrun --show-sdk-path)"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

cp "$DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
cp -f "$DIR/Tuya_Zigbee_Metering_Plug.groovy" "$DIR/Tuya_Zigbee_Metering_Plug_${DRIVER_VERSION}.groovy"

# Clean old zip bundles
rm -f "$DIR"/PanelPower-macOS*.zip

SOURCES=(
  "$DIR/src/Models.swift"
  "$DIR/src/AppSettings.swift"
  "$DIR/src/HomeAssistantService.swift"
  "$DIR/src/LiveChartView.swift"
  "$DIR/src/DashboardView.swift"
  "$DIR/src/SettingsView.swift"
  "$DIR/src/AppDelegate.swift"
  "$DIR/src/main.swift"
)

echo "1/2 Compiling PanelPower for Intel Mac (x86_64)..."
swiftc -O \
  -target x86_64-apple-macos14.0 \
  -sdk "$SDK_PATH" \
  "${SOURCES[@]}" \
  -o "$MACOS_DIR/PanelPower"

codesign --force --deep --sign - "$APP_DIR"

echo "Packaging PanelPower-macOS-Intel-${APP_VERSION}.zip..."
(cd "$DIR" && zip -r -q "PanelPower-macOS-Intel-${APP_VERSION}.zip" "PanelPower.app" "Tuya_Zigbee_Metering_Plug_${DRIVER_VERSION}.groovy" "HOW_TO_INSTALL.txt" -x "*.DS_Store")
cp -f "$DIR/PanelPower-macOS-Intel-${APP_VERSION}.zip" "$DIR/PanelPower-macOS-Intel.zip"

echo "2/2 Compiling PanelPower for Apple Silicon (arm64)..."
swiftc -O \
  -target arm64-apple-macos14.0 \
  -sdk "$SDK_PATH" \
  "${SOURCES[@]}" \
  -o "$MACOS_DIR/PanelPower"

codesign --force --deep --sign - "$APP_DIR"

echo "Packaging PanelPower-macOS-ARM-${APP_VERSION}.zip..."
(cd "$DIR" && zip -r -q "PanelPower-macOS-ARM-${APP_VERSION}.zip" "PanelPower.app" "Tuya_Zigbee_Metering_Plug_${DRIVER_VERSION}.groovy" "HOW_TO_INSTALL.txt" -x "*.DS_Store")
cp -f "$DIR/PanelPower-macOS-ARM-${APP_VERSION}.zip" "$DIR/PanelPower-macOS-ARM.zip"

# If running on an Intel Mac, leave the local .app binary as x86_64 before installing
if [ "$(uname -m)" = "x86_64" ]; then
  unzip -q -o "$DIR/PanelPower-macOS-Intel-${APP_VERSION}.zip" "PanelPower.app/*" -d "$DIR"
fi

echo "Installing to /Applications/PanelPower.app..."
rm -rf /Applications/PanelPower.app
cp -R "$APP_DIR" /Applications/PanelPower.app

echo "Build & Installation complete: /Applications/PanelPower.app"
