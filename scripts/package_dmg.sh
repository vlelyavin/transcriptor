#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
APP_NAME="Transcriptor"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
DMG_PATH="${DIST_DIR}/${APP_NAME}.dmg"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/transcriptor-dmg.XXXXXX")"

cleanup() {
  rm -rf "${STAGING_DIR}"
}
trap cleanup EXIT

"${ROOT_DIR}/scripts/build_release.sh"

if [[ ! -d "${APP_BUNDLE}" ]]; then
  echo "App bundle not found at ${APP_BUNDLE}" >&2
  exit 1
fi

rm -f "${DMG_PATH}"
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  codesign --force --sign "${DEVELOPER_ID_APPLICATION}" "${DMG_PATH}"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "${DMG_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait
  xcrun stapler staple "${DMG_PATH}"
  echo "Notarized and stapled — opens with no Gatekeeper warning."
else
  echo
  echo "NOTE: DMG is not notarized. Recipients clear the quarantine flag once:"
  echo "  xattr -dr com.apple.quarantine /Applications/${APP_NAME}.app"
fi

echo "Built DMG at ${DMG_PATH}"
