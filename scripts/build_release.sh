#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
APP_NAME="Transcriptor"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
BIN_PATH="$(cd "${ROOT_DIR}" && swift build -c release --show-bin-path)"
EXECUTABLE_PATH="${BIN_PATH}/${APP_NAME}"
INFO_PLIST="${CONTENTS_DIR}/Info.plist"

if [[ ! -x "${EXECUTABLE_PATH}" ]]; then
  echo "Release executable not found at ${EXECUTABLE_PATH}" >&2
  exit 1
fi

rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${EXECUTABLE_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod 755 "${MACOS_DIR}/${APP_NAME}"

# App icon (dock + installer). Regenerate if missing.
ICON_SRC="${ROOT_DIR}/Sources/Transcriptor/Resources/AppIcon.icns"
if [[ ! -f "${ICON_SRC}" ]]; then
  ( cd "${ROOT_DIR}" && swift Scripts/generate_app_icon.swift )
fi
if [[ -f "${ICON_SRC}" ]]; then
  cp "${ICON_SRC}" "${RESOURCES_DIR}/AppIcon.icns"
fi

cat > "${INFO_PLIST}" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>Transcriptor</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>com.vlelyavin.Transcriptor</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Transcriptor</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.4.1</string>
  <key>CFBundleVersion</key>
  <string>5</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>Transcriptor uses the microphone to record dictation for speech-to-text transcription.</string>
</dict>
</plist>
PLIST

if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  codesign \
    --force \
    --timestamp \
    --options runtime \
    --sign "${DEVELOPER_ID_APPLICATION}" \
    "${APP_BUNDLE}"
else
  # Ad-hoc sign so Gatekeeper reports the normal "unidentified developer"
  # prompt (clearable via right-click -> Open) instead of "is damaged".
  codesign --force --deep --sign - "${APP_BUNDLE}"
fi

echo "Built app bundle at ${APP_BUNDLE}"
