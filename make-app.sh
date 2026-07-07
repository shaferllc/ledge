#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

INSTALL=0
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=1 ;;
    -h|--help)
      echo "Usage: $0 [--install]"
      echo "  --install   Move Ledge.app into /Applications and launch it"
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

APP="$HOME/Desktop/Ledge.app"
echo "› Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/Ledge "$APP/Contents/MacOS/Ledge"
cp AppIcon.icns         "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                 <string>Ledge</string>
    <key>CFBundleDisplayName</key>          <string>Ledge</string>
    <key>CFBundleIdentifier</key>           <string>com.tomshafer.ledge</string>
    <key>CFBundleVersion</key>              <string>1</string>
    <key>CFBundleShortVersionString</key>   <string>0.3</string>
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
    <key>NSLocationWhenInUseUsageDescription</key><string>Ledge uses your location to show local weather in the notch.</string>
    <key>NSCameraUsageDescription</key>     <string>Ledge shows a live front-camera mirror in the notch when you enable the Mirror module.</string>
    <key>NSHumanReadableCopyright</key>     <string>© 2026 Tom Shafer</string>
</dict>
</plist>
PLIST

# Ad-hoc sign so Automation/Calendar permissions bind to a stable identity.
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
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
