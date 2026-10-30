#!/bin/bash
# Post-build: re-sign the app with the stable AutoClickerDev identity (if set up).
KC="$HOME/Library/Keychains/autoclicker-dev.keychain-db"
PASSFILE="$HOME/.autoclicker-dev-keychain-pass"
APP="${CODESIGNING_FOLDER_PATH:-$1}"
[ -f "$KC" ] && [ -f "$PASSFILE" ] || { echo "note: run scripts/setup-signing.sh for stable signing"; exit 0; }
security unlock-keychain -p "$(cat "$PASSFILE")" "$KC"
codesign --force --deep --sign "AutoClickerDev" --keychain "$KC" \
  --entitlements "${SRCROOT:-.}/AutoClickerPro/AutoClickerPro.entitlements" "$APP"
