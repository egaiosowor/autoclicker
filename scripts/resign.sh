#!/bin/bash
# Post-build: re-sign the app with the stable AutoClickerDev identity (if set up).
KC="$HOME/Library/Keychains/autoclicker-dev.keychain-db"
PASSFILE="$HOME/.autoclicker-dev-keychain-pass"
APP="${CODESIGNING_FOLDER_PATH:-$1}"
[ -f "$KC" ] && [ -f "$PASSFILE" ] || { echo "note: run scripts/setup-signing.sh for stable signing"; exit 0; }
security unlock-keychain -p "$(cat "$PASSFILE")" "$KC"
# Test runs embed a half-built xctest that cannot be sealed; tests don't need the stable identity.
if ls "$APP"/Contents/PlugIns/*.xctest >/dev/null 2>&1; then
  echo "note: test build detected, skipping re-sign"; exit 0
fi
SIGN=(codesign --force --sign "AutoClickerDev" --keychain "$KC")
# Sign nested dylibs first (Debug builds embed some), then the bundle itself.
for f in "$APP"/Contents/MacOS/*.dylib; do [ -e "$f" ] && "${SIGN[@]}" "$f"; done
"${SIGN[@]}" --entitlements "${SRCROOT:-.}/AutoClickerPro/AutoClickerPro.entitlements" "$APP"
