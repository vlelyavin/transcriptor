# Native Polish QA Notes — Round 2

Date: June 10, 2026
Branch: `claude/native-macos-hostile-polish`

Round 2 responds to the user review in `docs/NATIVE_MACOS_REVIEW_ROUND2.md`:
sidebar indistinguishable from content, no rich icons, no back/forward, no
search, settings pane unusable, window felt unresizable, `.ogg` unsupported.

## Captured screenshots (real `screencapture -l`, dark unless noted)

- `overview-dark.png` (1100×720) — colored sidebar icons, sidebar search
  field, back/forward chevrons, inset rounded grouped sections.
- `overview-narrow-dark.png` (660×500) — window accepts sizes well below the
  old 780×600 minimum; nothing clips.
- `overview-light.png` (1100×720) — light mode parity.
- `history-dark.png` (1100×720) — compact single-column mode.
- `history-wide-dark.png` (1280×760) — two-pane list + detail.
- `import-dark.png` — drop zone, `.ogg/.oga/.opus` listed, Telegram note,
  no webm row.
- `models-dark.png` — grouped model rows.
- `settings-window-dark.png` — standalone Settings window (General pane):
  System Settings-style searchable sidebar with colored icons, no sidebar
  collapse button.
- `settings-cloud-dark.png` — per-provider sections; disabled Save/Test/
  Remove buttons now carry an explanatory caption.
- `settings-recording-dark.png` — insertion + microphone + last-attempt rows.

## What changed relative to the user's complaints

| Complaint | Fix | Verified |
|---|---|---|
| Can't resize the window | Minimum dropped to 640×460, explicit `.windowResizability(.contentMinSize)`; window accepted 660×500 and 1280×760 frames | Screenshots at multiple sizes; live edge-drag still needs a human hand |
| Sidebar same color as content | Sidebar material + content grouped forms now contrast (see overview shots) | Screenshots dark + light |
| No back/forward buttons | History-stack navigation with toolbar chevrons | Visible in all main-window shots; logic unit-level (AppState.navigateBack/Forward) |
| No rich icons | System Settings-style colored rounded-square icons in both sidebars | Screenshots |
| No search | Sidebar search field (filters screens and settings panes, settings results open the Settings window) + Settings window search | Screenshots; `SettingsPane.matching(query:)` unit tested |
| Settings tab terrible / buttons dead | Settings is now a real `Settings` scene window (Cmd+, and gear). Save stays disabled only while the key field is empty and a caption now says so | Screenshots |
| Settings search doesn't work | Search is a plain TextField driving `SettingsPane.matching`; covered by `SettingsPaneSearchTests` | Unit tests |
| `.ogg` unsupported | `.ogg/.oga/.opus` imports decode through CoreAudio and convert to WAV working files; 7 `AudioImportServiceTests` against real Ogg Opus/Vorbis fixtures | Tests + import screenshot |
| Remove webm from the app | All webm UI, error cases, and content types removed; `.webm` now gets the generic honest unsupported-type error | `grep -ri webm Sources` is empty; test asserts the error |

## Validation

- `swift test`: 53 tests, 1 skipped (opt-in WhisperKit integration), 0 failures.
- `swift run TranscriptorSmokeChecks`: passed.
- `xcodebuild -scheme Transcriptor -destination 'platform=macOS' build`: succeeded.
- `./scripts/package_dmg.sh`: produces `dist/Transcriptor.app` + DMG.

## Still needs a human pass

- Live edge-drag window resizing (automation cannot post drag events without
  Accessibility permission).
- Typing into the Settings search field and sidebar search field (same
  reason); the filtering logic itself is unit tested.
- Keychain Save/Test against a real API key.
