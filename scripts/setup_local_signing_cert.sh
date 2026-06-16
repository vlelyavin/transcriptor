#!/usr/bin/env bash
#
# Create a STABLE, self-signed code-signing identity for LOCAL development so
# Microphone / Accessibility (TCC) grants survive every rebuild.
#
# Why this is needed: with no signing identity, scripts/build_release.sh ad-hoc
# signs the app. An ad-hoc signature's "designated requirement" is the binary's
# cdhash, which changes on every build — so macOS treats each build as a new app
# and WIPES its permissions. Signing with a fixed certificate makes the
# requirement certificate-based and identical across rebuilds, so the grants
# stick. (This identity is self-signed and UNTRUSTED — it only helps your own
# machine; it does nothing for distribution. For that you need a paid Apple
# Developer ID + notarization. See README "Distribution".)
#
# The cert + private key live in a dedicated keychain with a known password, so
# codesign can use it non-interactively (no GUI "Allow" prompt) on every build.
#
# Idempotent: re-running detects the existing identity and does nothing.
# To undo: scripts/setup_local_signing_cert.sh --remove
set -euo pipefail

IDENTITY="${LOCAL_CODESIGN_IDENTITY:-Transcriptor Local Dev}"
KEYCHAIN="${HOME}/Library/Keychains/transcriptor-codesign.keychain-db"
KEYCHAIN_PWD="${LOCAL_CODESIGN_KEYCHAIN_PASSWORD:-transcriptor-local}"

remove_identity() {
  echo "Removing local signing keychain and identity…"
  # Drop it from the search list, then delete the keychain file.
  local others
  others=$(security list-keychains -d user | sed -e 's/^[[:space:]]*//' -e 's/"//g' | grep -v "transcriptor-codesign.keychain" || true)
  # shellcheck disable=SC2086
  security list-keychains -d user -s ${others} >/dev/null 2>&1 || true
  security delete-keychain "${KEYCHAIN}" 2>/dev/null || true
  rm -f "${KEYCHAIN}" 2>/dev/null || true
  echo "Done. Rebuilds will fall back to ad-hoc signing."
}

if [[ "${1:-}" == "--remove" ]]; then
  remove_identity
  exit 0
fi

if security find-identity -p codesigning 2>/dev/null | grep -q "${IDENTITY}"; then
  echo "Local signing identity '${IDENTITY}' already present. Nothing to do."
  echo "Build a stable local install with:"
  echo "  LOCAL_CODESIGN_IDENTITY=\"${IDENTITY}\" bash scripts/build_release.sh"
  exit 0
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

CONFIG="${WORK_DIR}/req.cnf"
cat > "${CONFIG}" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = ${IDENTITY}
[ext]
basicConstraints = critical, CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

echo "Generating self-signed code-signing certificate…"
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "${WORK_DIR}/key.pem" \
  -out "${WORK_DIR}/cert.pem" \
  -days 3650 \
  -config "${CONFIG}" >/dev/null 2>&1

# -legacy so OpenSSL 3 writes a PKCS#12 that macOS `security import` accepts.
openssl pkcs12 -export -legacy \
  -inkey "${WORK_DIR}/key.pem" \
  -in "${WORK_DIR}/cert.pem" \
  -name "${IDENTITY}" \
  -out "${WORK_DIR}/identity.p12" \
  -passout pass:transcriptor-p12 >/dev/null 2>&1

# Fresh dedicated keychain (recreate so the run is deterministic).
security delete-keychain "${KEYCHAIN}" 2>/dev/null || true
security create-keychain -p "${KEYCHAIN_PWD}" "${KEYCHAIN}"
security set-keychain-settings "${KEYCHAIN}"            # no auto-lock timeout
security unlock-keychain -p "${KEYCHAIN_PWD}" "${KEYCHAIN}"

security import "${WORK_DIR}/identity.p12" \
  -k "${KEYCHAIN}" \
  -P transcriptor-p12 \
  -T /usr/bin/codesign \
  -T /usr/bin/security >/dev/null

# Authorize non-interactive use of the key by codesign (no GUI prompt).
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s -k "${KEYCHAIN_PWD}" "${KEYCHAIN}" >/dev/null 2>&1

# Add the keychain to the user search list (so codesign/find-identity see it),
# keeping the existing keychains.
EXISTING=$(security list-keychains -d user | sed -e 's/^[[:space:]]*//' -e 's/"//g')
if ! echo "${EXISTING}" | grep -q "transcriptor-codesign.keychain"; then
  # shellcheck disable=SC2086
  security list-keychains -d user -s "${KEYCHAIN}" ${EXISTING}
fi

echo
if security find-identity -p codesigning | grep -q "${IDENTITY}"; then
  echo "✅ Created stable local signing identity: '${IDENTITY}'"
  echo
  echo "Next: build a stable local install (one final permission re-grant, then"
  echo "grants persist across all future rebuilds):"
  echo "  LOCAL_CODESIGN_IDENTITY=\"${IDENTITY}\" bash scripts/build_release.sh"
else
  echo "⚠️  Identity created but not visible to codesign. Check:"
  echo "  security find-identity -p codesigning"
  exit 1
fi
