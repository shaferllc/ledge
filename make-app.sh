#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# Configurable via env so make-dmg.sh / CI can reuse this to produce a
# Developer-ID-signed bundle in a staging dir, while the plain `./make-app.sh`
# path keeps building an ad-hoc app on the Desktop.
#   APP_DEST       directory to place Ledge.app in   (default ~/Desktop)
#   SIGN_IDENTITY  codesign identity                 (default "-" = ad-hoc)
#   LEDGE_VERSION  CFBundleShortVersionString         (default 0.3)
#   LEDGE_BUILD    CFBundleVersion                    (default 1)
APP_DEST="${APP_DEST:-$HOME/Desktop}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
LEDGE_VERSION="${LEDGE_VERSION:-0.3}"
LEDGE_BUILD="${LEDGE_BUILD:-1}"

INSTALL=0
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=1 ;;
    -h|--help)
      echo "Usage: $0 [--install]"
      echo "  --install   Move Ledge.app into /Applications and launch it"
      echo ""
      echo "Env: APP_DEST, SIGN_IDENTITY, LEDGE_VERSION, LEDGE_BUILD"
      exit 0
      ;;
  esac
done

echo "› Building release binary…"
swift build -c release

# Generate icon if missing or older than the script.
if [ ! -f AppIcon.icns ] || [ make-icon.swift -nt AppIcon.icns ]; then
  echo "› Generating AppIcon.icns…"
  swift make-icon.swift
fi

APP="$APP_DEST/Ledge.app"
echo "› Assembling $APP"
mkdir -p "$APP_DEST"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/Ledge    "$APP/Contents/MacOS/Ledge"
# The `ledge` CLI lives in Resources, not MacOS: on the case-insensitive macOS
# filesystem "MacOS/ledge" and "MacOS/Ledge" are the same path and would clobber
# the app binary. The installer symlinks /usr/local/bin/ledge to it.
cp .build/release/LedgeCLI "$APP/Contents/Resources/ledge"
cp AppIcon.icns            "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                 <string>Ledge</string>
    <key>CFBundleDisplayName</key>          <string>Ledge</string>
    <key>CFBundleIdentifier</key>           <string>com.tomshafer.ledge</string>
    <key>CFBundleVersion</key>              <string>${LEDGE_BUILD}</string>
    <key>CFBundleShortVersionString</key>   <string>${LEDGE_VERSION}</string>
    <key>CFBundleExecutable</key>           <string>Ledge</string>
    <key>CFBundlePackageType</key>          <string>APPL</string>
    <key>CFBundleSupportedPlatforms</key>   <array><string>MacOSX</string></array>
    <key>CFBundleIconFile</key>             <string>AppIcon</string>
    <key>CFBundleIconName</key>             <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>       <string>14.0</string>
    <key>LSUIElement</key>                  <true/>
    <key>NSHighResolutionCapable</key>      <true/>
    <key>NSAppleEventsUsageDescription</key><string>Ledge controls Spotify and Apple Music to show what's playing and let you skip tracks from the notch.</string>
    <key>NSCalendarsUsageDescription</key>  <string>Ledge shows your upcoming events in the notch calendar module.</string>
    <key>NSCalendarsFullAccessUsageDescription</key><string>Ledge shows your upcoming events and meeting links in the notch calendar module.</string>
    <key>NSRemindersUsageDescription</key>  <string>Ledge shows your reminders and lets you add and complete them from the notch.</string>
    <key>NSRemindersFullAccessUsageDescription</key><string>Ledge shows your reminders and lets you add and complete them from the notch.</string>
    <key>NSLocationWhenInUseUsageDescription</key><string>Ledge uses your location to show local weather in the notch.</string>
    <key>NSCameraUsageDescription</key>     <string>Ledge shows a live front-camera mirror in the notch when you enable the Mirror module.</string>
    <key>NSHumanReadableCopyright</key>     <string>© 2026 Tom Shafer</string>
</dict>
</plist>
PLIST

if [ "$SIGN_IDENTITY" = "-" ]; then
  # Ad-hoc sign so Automation/Calendar permissions bind to a stable identity.
  # Nested executables (the ledge CLI) must be signed before the outer bundle.
  echo "› Ad-hoc signing"
  codesign --force --sign - "$APP/Contents/Resources/ledge" >/dev/null 2>&1 || true
  codesign --force --sign - "$APP/Contents/MacOS/Ledge" >/dev/null 2>&1 || true
  codesign --force --sign - "$APP" >/dev/null 2>&1 || true
else
  # Developer ID signing with the hardened runtime, required for notarization.
  echo "› Signing with: $SIGN_IDENTITY (hardened runtime)"
  codesign --force --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" "$APP/Contents/Resources/ledge"
  codesign --force --options runtime --timestamp \
    --entitlements Ledge.entitlements \
    --sign "$SIGN_IDENTITY" "$APP/Contents/MacOS/Ledge"
  codesign --force --options runtime --timestamp \
    --entitlements Ledge.entitlements \
    --sign "$SIGN_IDENTITY" "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
fi
touch "$APP"

if [ "$INSTALL" = "1" ]; then
  DEST="/Applications/Ledge.app"
  echo "› Installing to $DEST (will quit any running Ledge first)"
  /usr/bin/pkill -x Ledge 2>/dev/null || true
  /bin/sleep 0.3
  rm -rf "$DEST"
  /bin/mv "$APP" "$DEST"
  open "$DEST"
  echo "› Installed and launched."
else
  echo "› Done. Open with:  open '$APP'"
  echo "  Or run:  $0 --install   to drop it in /Applications."
fi
