#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# Builds a distributable Ledge.dmg (a signed .app + an /Applications drop link).
#
# Ad-hoc / local:   ./make-dmg.sh
#     Produces build/Ledge.dmg from an ad-hoc-signed app. Fine for handing to
#     yourself; other Macs will still show the Gatekeeper "unidentified
#     developer" prompt (right-click → Open to bypass).
#
# Release / notarized:
#     SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#     NOTARIZE=1 AC_APPLE_ID=you@example.com AC_TEAM_ID=TEAMID \
#     AC_PASSWORD=app-specific-pw ./make-dmg.sh
#     Signs with the hardened runtime, notarizes + staples the app, packages it,
#     then notarizes + staples the DMG so it launches cleanly anywhere.
#
# Env:
#   SIGN_IDENTITY  codesign identity            (default "-" = ad-hoc)
#   LEDGE_VERSION  marketing version            (default 0.3)
#   LEDGE_BUILD    build number                 (default 1)
#   NOTARIZE       1 to notarize via notarytool (default 0)
#   AC_APPLE_ID / AC_TEAM_ID / AC_PASSWORD      Apple ID + app-specific password
#   AC_KEYCHAIN_PROFILE                          alternative: a stored notarytool profile

SIGN_IDENTITY="${SIGN_IDENTITY:--}"
LEDGE_VERSION="${LEDGE_VERSION:-0.3}"
LEDGE_BUILD="${LEDGE_BUILD:-1}"
NOTARIZE="${NOTARIZE:-0}"

BUILD_DIR="build"
STAGE="$BUILD_DIR/dmg-stage"
APP="$STAGE/Ledge.app"
DMG="$BUILD_DIR/Ledge.dmg"

# notarytool credential args: prefer a stored keychain profile, else Apple ID.
notary_args() {
  if [ -n "${AC_KEYCHAIN_PROFILE:-}" ]; then
    echo "--keychain-profile $AC_KEYCHAIN_PROFILE"
  else
    echo "--apple-id $AC_APPLE_ID --team-id $AC_TEAM_ID --password $AC_PASSWORD"
  fi
}

# Submit a path (zip or dmg) to notarytool and block until it's accepted.
notarize_submit() {
  local path="$1"
  echo "› Notarizing $path (this can take a few minutes)…"
  # shellcheck disable=SC2046
  xcrun notarytool submit "$path" $(notary_args) --wait
}

echo "› Building app into $STAGE"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
APP_DEST="$STAGE" SIGN_IDENTITY="$SIGN_IDENTITY" \
  LEDGE_VERSION="$LEDGE_VERSION" LEDGE_BUILD="$LEDGE_BUILD" \
  ./make-app.sh

if [ "$NOTARIZE" = "1" ]; then
  # Notarize + staple the app first so it carries its own ticket offline.
  APPZIP="$BUILD_DIR/Ledge-app.zip"
  /usr/bin/ditto -c -k --keepParent "$APP" "$APPZIP"
  notarize_submit "$APPZIP"
  xcrun stapler staple "$APP"
  rm -f "$APPZIP"
fi

# A drop target so the DMG window offers "drag Ledge into Applications".
ln -sf /Applications "$STAGE/Applications"

# Un-notarized (ad-hoc) builds trip Gatekeeper on first launch; include the
# one-time workaround right in the disk image.
if [ "$NOTARIZE" != "1" ]; then
  cat > "$STAGE/How to Open Ledge.txt" <<'TXT'
Opening Ledge the first time
============================

Ledge isn't notarized yet, so macOS may say it's from an
"unidentified developer" the first time you open it.

To open it:
  1. Drag Ledge into your Applications folder (the shortcut here).
  2. In Applications, RIGHT-CLICK (or Control-click) Ledge.
  3. Choose "Open", then click "Open" again in the dialog.

You only have to do this once. After that Ledge launches normally.
It lives in the menu bar and has no Dock icon.
TXT
fi

echo "› Creating $DMG"
hdiutil create -volname "Ledge" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

if [ "$SIGN_IDENTITY" != "-" ]; then
  codesign --force --sign "$SIGN_IDENTITY" "$DMG"
fi

if [ "$NOTARIZE" = "1" ]; then
  notarize_submit "$DMG"
  xcrun stapler staple "$DMG"
  echo "› Notarized + stapled: $DMG"
fi

echo "› Done: $DMG"
