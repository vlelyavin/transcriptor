#!/usr/bin/env bash
set -euo pipefail

# Wipes all of Transcriptor's local state so the next launch behaves like a
# brand-new install: no downloaded models, no history, no settings, and the
# mandatory first-launch setup popup shown again.
#
# IMPORTANT: quit Transcriptor first, or macOS (cfprefsd) will rewrite the
# preferences on quit and undo this reset.

echo "Resetting Transcriptor state…"

# Two preference domains exist depending on how the app was launched:
#   - "Transcriptor"               → `swift run` (process-name domain)
#   - "com.vlelyavin.Transcriptor" → the packaged .app (bundle-id domain)
for domain in Transcriptor com.vlelyavin.Transcriptor; do
  defaults delete "${domain}" 2>/dev/null && echo "  cleared defaults: ${domain}" || true
done

# Downloaded models, recordings, imports, exports, and history.
SUPPORT_DIR="${HOME}/Library/Application Support/Transcriptor"
if [[ -d "${SUPPORT_DIR}" ]]; then
  rm -rf "${SUPPORT_DIR}"
  echo "  removed ${SUPPORT_DIR}"
fi

# Flush the preferences cache so the deletes take effect immediately instead of
# being re-serialized from cfprefsd's in-memory copy.
killall cfprefsd 2>/dev/null || true

echo "Done. Next launch will start from a clean, first-run state."
