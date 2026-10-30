#!/bin/bash
# One-time: creates a self-signed "AutoClickerDev" code-signing identity in a dedicated
# keychain so every build has the same signature and macOS keeps the Accessibility grant.
set -euo pipefail
KC="$HOME/Library/Keychains/autoclicker-dev.keychain-db"
PASSFILE="$HOME/.autoclicker-dev-keychain-pass"
NAME="AutoClickerDev"

if [ ! -f "$PASSFILE" ]; then
  umask 077; openssl rand -hex 16 > "$PASSFILE"
fi
PASS=$(cat "$PASSFILE")

if [ ! -f "$KC" ]; then
  security create-keychain -p "$PASS" "$KC"
  security set-keychain-settings "$KC"            # no auto-lock
fi
security unlock-keychain -p "$PASS" "$KC"

if ! security find-certificate -c "$NAME" "$KC" >/dev/null 2>&1; then
  T=$(mktemp -d)
  cat > "$T/c.cnf" <<CNF
[req]
distinguished_name=dn
prompt=no
x509_extensions=v3
[dn]
CN=$NAME
[v3]
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
basicConstraints=critical,CA:FALSE
CNF
  openssl req -x509 -newkey rsa:2048 -nodes -keyout "$T/k.pem" -out "$T/c.pem" -days 3650 -config "$T/c.cnf" 2>/dev/null
  openssl pkcs12 -export -legacy -inkey "$T/k.pem" -in "$T/c.pem" -out "$T/i.p12" -passout pass:"$PASS"
  security import "$T/i.p12" -k "$KC" -P "$PASS" -T /usr/bin/codesign >/dev/null
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PASS" "$KC" >/dev/null
  rm -rf "$T"
fi

# Make the keychain visible to codesign (keep existing ones).
EXISTING=$(security list-keychains -d user | tr -d '"')
echo "$EXISTING" | grep -q autoclicker-dev || security list-keychains -d user -s "$KC" $EXISTING
echo "Signing identity ready: $NAME"
