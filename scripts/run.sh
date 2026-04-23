#!/usr/bin/env bash
#
# Build QuickPolish2, sign with our local self-signed cert (so TCC grants
# persist across rebuilds), kill any previous instance, and relaunch.
set -euo pipefail

cd "$(dirname "$0")/.."

CERT_NAME="QuickPolishLocal"
BINARY=".build/debug/QuickPolish2"
BUNDLE_ID="com.quickpolish.QuickPolish2"

# Self-signed certs show up as "(CSSMERR_TP_NOT_TRUSTED)" under `-v`, so we
# check the unfiltered list instead. Lack of trust is fine for local signing —
# it only matters for Gatekeeper verification, which won't run on a binary we
# built and launched ourselves.
if ! security find-identity | grep -q "\"$CERT_NAME\""; then
  echo "❌ Signing identity '$CERT_NAME' not found."
  echo "   Run ./scripts/setup-signing.sh first."
  exit 1
fi

echo "→ Building..."
swift build

echo "→ Signing with '$CERT_NAME' (identifier=$BUNDLE_ID)..."
# --force    overwrite any prior signature
# -i         embed the stable bundle identifier (used by TCC for tracking)
# -o runtime not required for local dev; omitted so we don't need entitlements
codesign --force --sign "$CERT_NAME" -i "$BUNDLE_ID" "$BINARY"

# Verify — mostly for the designated requirement output, which should now
# reference our identifier + certificate CN instead of a volatile cdhash.
codesign -dvvv "$BINARY" 2>&1 | grep -E "Identifier|Authority|TeamIdentifier" || true

echo "→ Stopping any previous QuickPolish2..."
pkill -x QuickPolish2 || true
sleep 0.3

echo "→ Launching..."
"$BINARY" >/dev/null 2>&1 &
disown
echo "✅ QuickPolish2 launched (pid $!)"
echo
echo "   Logs:   tail -f ~/.quickpolish/quickpolish.log"
echo "   Hotkey: copy text with ⌘C, then press ⌃G"
