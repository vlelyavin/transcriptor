# Native Polish QA Notes — claude/native-macos-hostile-polish

Date: June 10, 2026

## Screenshot status

Captured programmatically after Screen Recording permission was granted: the app
was launched per screen/size with `TRANSCRIPTOR_QA_*` environment overrides (see
`TranscriptorApp.applyQAOverridesIfRequested`), the window frame was preset via
the `NSWindow Frame` autosave default, the window ID was resolved with
`CGWindowListCopyWindowInfo`, and each shot was taken with `screencapture -l`.

Screenshots in this directory:

- `overview-wide-1280-dark.png`, `overview-narrow-780-dark.png`,
  `overview-wide-1280-light.png`
- `history-wide-1280-dark.png`, `history-narrow-780-dark.png`
- `import-wide-1280-dark.png`, `import-narrow-780-dark.png`
- `models-wide-1280-dark.png`, `models-narrow-780-dark.png`
- `settings-general-1280-dark.png`, `settings-recording-1280-dark.png`,
  `settings-cloud-1280-dark.png`, `settings-narrow-780-dark.png`
- `overlay-recording-dark.png` (toggle mode: Listening, duration, level bars,
  Cancel/Done)

Screenshot review found and fixed one real bug: at narrow widths History opened
directly in the detail pane and the back button bounced straight back to detail
(`selectedEntry` fell back to the first entry). Compact detail visibility is now
an explicit navigation state.

## What was verified without screenshots

- `swift build` and `swift test` pass (42 tests, 1 skipped opt-in WhisperKit
  integration test).
- `swift run TranscriptorSmokeChecks` passes.
- The app launches from `.build/debug/Transcriptor` and creates its main window
  (verified via the window list: a single 972×695 window appeared).
- All layout thresholds and constraints were re-derived from code review, not
  visual inspection — see per-screen notes.

## Per-screen manual checklist

### App shell / sidebar (all widths)
- [ ] Sidebar has no brand header; the first row is "Overview".
- [ ] Sidebar uses the translucent `.sidebar` NSVisualEffectView material and
      native selection highlight in both light and dark mode.
- [ ] Sidebar footer shows one line: mic state left, shortcut right; no clipping
      at the 190 pt minimum column width.
- [ ] Window resizes down to 780×600 without clipping any screen.
- [ ] Toolbar has exactly two items: voice input toggle and Settings gear.
- [ ] Gear and `Cmd+,` both select the in-app Settings screen.

### Overview
- [ ] Grouped rows only: shortcut, input mode, state, overlay, insertion status,
      provider, selected model, ready model count, auto-transcribe, storage rows,
      recent history.
- [ ] Insertion row reads "On — needs Accessibility access" when insertion is
      enabled without the permission.

### History (wide ≥980 pt)
- [ ] Two panes: list (segmented filter + count line above) and detail.
- [ ] Rows: two-line preview plus two single-line secondary metadata lines; no
      icon chips, no capsules.
- [ ] Detail: title3 filename, two secondary metadata lines, action row with
      Transcribe/Play/Copy plus an ellipsis Menu (Re-transcribe With…,
      Export…, Delete…). Nothing overflows at 1000 pt window width.
- [ ] Transcript appears in a GroupBox directly under the actions.
- [ ] "Details" (paths, sizes) and "Transcript Versions" are collapsed
      DisclosureGroups by default.

### History (narrow <980 pt)
- [ ] List fills the pane; selecting a row replaces it with the detail view and
      a "‹ History" back button. No horizontal overflow at 780 pt.

### Import Audio
- [ ] Single column at every width: drop zone section, optional feedback row,
      "Import Details" grouped rows, "Recent Imports" grouped rows.
- [ ] No hero title, no colored cards, no format chips, no shortcut badge.
- [ ] Drop zone: dashed 1 pt border, quiet background, down-arrow SF Symbol,
      single "Choose Files…" button; accent tint only while drag-targeted.
- [ ] `.webm` listed as "Not supported — no decoder in this build".

### Models
- [ ] Grouped form: Current Selection, WhisperKit Models, NVIDIA Parakeet
      Models (footer states Beta + Apple Silicon + >1 GB download), Cloud
      Models.
- [ ] Model rows: name + spec line, plain status text, small Select/Download/
      Load/trash controls; per-row "Details" disclosure for speed/accuracy/
      notes.
- [ ] Color appears only for failed/unavailable states and credential errors.

### Settings
- [ ] Wide (detail ≥700 pt): fixed 210 pt category list + divider + grouped
      form detail. No nested sidebar/toolbar artifacts.
- [ ] Narrow: category list first, then single-column pane with "‹ All
      Settings" back button.
- [ ] Search filters categories from the native search field.
- [ ] All eight panes present: General, Recording, Keyboard Shortcut, Overlay,
      Models, Storage, Cloud Providers, Privacy.
- [ ] Cloud Providers: disclosure per provider, SecureField + Save/Remove/Test,
      Keychain status line, privacy acknowledgment toggle. Status is plain
      text (orange/red only for action-needed/unavailable).
- [ ] Recording pane shows insertion toggles, Accessibility status, and the
      Last Insertion Attempt rows.

### Voice input overlay
- [ ] 340 pt panel, ultra-thick material, 16 pt corner radius, hairline
      separator stroke; centered on the active screen with a dimmed backdrop.
- [ ] Single-tint level bars (accent while recording, gray otherwise); no
      gradients, no RMS/peak numbers.
- [ ] Toggle mode: Cancel + prominent Done buttons. Hold mode: no buttons,
      subtitle "Release the shortcut to finish dictation."
- [ ] States observed: Listening, Finishing, Transcribing, Inserting, Saved,
      Voice Input Failed, Setup Required (gear icon, orange, ~3.5 s).
- [ ] Overlay auto-hides after saved/error/setup states; never sticks.

### Dictation insertion flow (manual end-to-end)
- [ ] Focus a TextEdit document, press the shortcut, speak, stop.
- [ ] With a downloaded model: transcription starts immediately (even with
      auto-transcribe off) and the text is inserted into TextEdit; history
      gains the entry.
- [ ] Without Accessibility: overlay reports the fallback; transcript is in
      history (and clipboard if enabled).
- [ ] With no model/provider ready: overlay shows "Setup Required" and the
      history entry is marked failed with the reason.
- [ ] Password field focused: transcript is not typed into the secure field.

## What could not be visually verified in this pass

- Actual rendering of materials/translucency in light vs dark mode.
- Exact spacing/typography at the three target widths.
- The dimming panel and overlay animation timing.
- Drag-and-drop highlight states.

Everything in "Per-screen manual checklist" was implemented and code-reviewed;
the unchecked boxes are the visual confirmation pass that requires a session
with Screen Recording permission.
