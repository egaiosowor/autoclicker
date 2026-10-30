#!/bin/bash
# Post-build: re-sign the app with the stable AutoClickerDev identity (if set up).
KC="$HOME/Library/Keychains/autoclicker-dev.keychain-db"
PASSFILE="$HOME/.autoclicker-dev-keychain-pass"
APP="${CODESIGNING_FOLDER_PATH:-$1}"
[ -f "$KC" ] && [ -f "$PASSFILE" ] || { echo "note: run scripts/setup-signing.sh for stable signing"; exit 0; }
security unlock-keychain -p "$(cat "$PASSFILE")" "$KC"
SIGN=(codesign --force --sign "AutoClickerDev" --keychain "$KC")
# Sign nested dylibs first (Debug builds embed some), then the bundle itself.
for f in "$APP"/Contents/MacOS/*.dylib; do [ -e "$f" ] && "${SIGN[@]}" "$f"; done
# Test action embeds the xctest bundle; it must be sealed before the app.
for f in "$APP"/Contents/PlugIns/*.xctest; do [ -e "$f" ] && "${SIGN[@]}" "$f"; done
"${SIGN[@]}" --entitlements "${SRCROOT:-.}/AutoClickerPro/AutoClickerPro.entitlements" "$APP"
