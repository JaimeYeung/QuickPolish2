#!/usr/bin/env bash
#
# One-time setup: create a self-signed code-signing certificate in the login
# keychain so every subsequent `scripts/run.sh` can sign the binary with the
# SAME identity. That keeps the codesign designated-requirement stable across
# rebuilds, which keeps macOS Accessibility / Input Monitoring grants alive.
#
# Safe to run multiple times — it is a no-op if the cert already exists.
set -euo pipefail

CERT_NAME="QuickPolishLocal"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity "$KEYCHAIN" | grep -q "\"$CERT_NAME\""; then
  echo "✅ Certificate '$CERT_NAME' already exists in login keychain."
  exit 0
fi

echo "→ Creating self-signed code-signing cert '$CERT_NAME'..."

# Prefer macOS's bundled LibreSSL at /usr/bin/openssl. Homebrew/conda OpenSSL 3
# builds produce PKCS12 bundles that Security.framework rejects with
# "MAC verification failed" on import, and the specific legacy-cipher flags
# needed to work around it vary between distributions. LibreSSL Just Works.
if [ -x /usr/bin/openssl ]; then
  OPENSSL=/usr/bin/openssl
else
  OPENSSL=$(command -v openssl)
fi
echo "   using openssl: $OPENSSL ($($OPENSSL version))"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

pushd "$tmpdir" >/dev/null

# OpenSSL config: single-file so we can embed the codeSigning EKU cleanly.
cat > openssl.cnf <<'EOF'
[ req ]
distinguished_name = dn
x509_extensions    = v3_ext
prompt             = no

[ dn ]
CN = QuickPolishLocal

[ v3_ext ]
basicConstraints     = critical, CA:FALSE
keyUsage             = critical, digitalSignature
extendedKeyUsage     = critical, codeSigning
subjectKeyIdentifier = hash
EOF

"$OPENSSL" req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -config openssl.cnf \
  -keyout key.pem -out cert.pem >/dev/null 2>&1

# macOS `security import` only understands the legacy PKCS12 encoding
# (PBE-SHA1-3DES + SHA1 MAC) AND refuses to import p12 bundles with an empty
# password regardless of what openssl did — it reports the refusal as the
# misleading "MAC verification failed". Use a throwaway password and hand it
# to `security import` explicitly.
P12_PASS="quickpolish"

p12_args=(
  -export
  -inkey key.pem -in cert.pem
  -out bundle.p12
  -name "$CERT_NAME"
  -passout "pass:$P12_PASS"
  -keypbe PBE-SHA1-3DES
  -certpbe PBE-SHA1-3DES
  -macalg SHA1
)
if "$OPENSSL" pkcs12 -help 2>&1 | grep -q -- -legacy; then
  p12_args+=( -legacy )
fi
"$OPENSSL" pkcs12 "${p12_args[@]}"

# Import private key + cert into the login keychain and allow codesign to use
# it without a password prompt on every build.
security import bundle.p12 \
  -k "$KEYCHAIN" \
  -P "$P12_PASS" \
  -T /usr/bin/codesign \
  -T /usr/bin/security \
  -A

# Let codesign read the private key without a GUI password prompt.
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s -k "" "$KEYCHAIN" >/dev/null 2>&1 || true

popd >/dev/null

echo "✅ Certificate '$CERT_NAME' installed."
echo
echo "Next: run ./scripts/run.sh — it will build, sign, and launch QuickPolish."
echo
echo "On first launch, macOS may still prompt for Accessibility/Input Monitoring."
echo "Grant it once; thanks to stable signing, the grant will persist across rebuilds."
