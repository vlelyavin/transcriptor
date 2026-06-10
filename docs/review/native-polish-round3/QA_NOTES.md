# Native Polish QA Notes — Round 3 (UX & Settings Overhaul)

Date: June 10, 2026
Branch: `claude/native-macos-hostile-polish`

Round 3 implements the consolidated-settings brief: settings move back into
the main window sidebar (one window, like System Settings), active model
auto-loads, menu bar gains an Active Model picker, sidebar/icons restyled to
the dark System Settings reference (`docs/reference/macos-native/2026-06-10_*`).

## Captured screenshots (real `screencapture -l`, two passes, dark unless noted)

- `overview-dark.png` — dark sidebar (darker than content), black icon tiles
  with thin border + white glyphs, Settings section in the sidebar, every
  Overview row has a chevron link button.
- `overview-light.png` — light parity.
- `overview-narrow-dark.png` (660×500) — bottom status bar occludes scrolling
  sidebar rows (withinWindow material backdrop).
- `settings-general-dark.png` — General pane in the MAIN window: menu bar
  toggle + Launch at login + honest packaged-app status.
- `settings-models-dark.png` — provider radio rows, local provider picker,
  default model picker, Auto-transcribe toggle.
- `settings-recording-dark.png` — input mode, microphone, transcript insertion.
- `settings-cloud-dark.png` — per-provider sections with explanatory captions.
- `history-dark.png`, `import-dark.png`, `models-dark.png` — app screens with
  the new sidebar; Import now has a live Auto-transcribe toggle.

## Changes vs the brief

| Requirement | Implementation | Verified |
|---|---|---|
| Model loads on launch | `AppState.autoLoadSelectedModelOnLaunch()` refreshes inventories then loads the selected model if downloaded; `selectLocalModel` also loads on switch | Code + launch log; Tiny stays unloaded when not selected (correct) |
| No separate Settings window | `Settings` scene removed; panes render via `SettingsPaneDetailView` inside the main split view; sidebar has a "Settings" section | Screenshots |
| Settings entry in app menu + gear | `CommandGroup(replacing: .appSettings)` Button (Cmd+,) + gear toolbar button + Transcriptor menu item, all call `openSettings` which selects the sidebar item | Build + code path (single function, no window plumbing left to break) |
| Overview options link to settings | Every row is `linkedRow` with a chevron button to its pane/screen; Recent History gets "Open History" | Screenshots |
| Auto-transcribe configurable | Toggle in Settings › Models; Import page row converted from read-only text to a live Toggle | Screenshots |
| Active model picker | Settings › Models picker (all catalog models) + menu bar Active Model submenu (downloaded models, checkmark, Manage Models…) | Screenshot; submenu click needs human pass |
| Sidebar darker than content | `NativeSidebarMaterial` adds a black scrim (0.28 dark / 0.05 light) over the sidebar material | Screenshots dark + light |
| Black icon tiles, thin border, white glyph | `SidebarIconView`: black rounded square, 0.5pt white(0.25) strokeBorder, white glyph | Screenshots match reference |
| Menu bar icon basics | Show/Hide Menu Bar Icon, Active Model, Open Transcriptor/History, Quit | Code; menu interaction needs human pass (no Accessibility for automation) |
| Launch at login | Existing toggle in General pane, searchable ("launch", "login"); disabled with honest status outside a packaged .app | Screenshot |
| Mic icon without ring | Toolbar uses `mic.fill` / `stop.fill` (was `mic.circle`) | Screenshots |
| Native search like System Settings | `SettingsPane.searchResults(matching:)` returns pane + matched individual settings; sidebar search renders pane row (icon) + indented setting rows that navigate to the pane | 5 new unit tests; rendering needs human typing pass |
| Native disclosure arrows | Model "Details" uses SwiftUI `DisclosureGroup` (system chevron); no custom disclosure remains (grep) | Models screenshot |

## Validation

- `swift test`: 57 tests, 1 skipped (opt-in WhisperKit integration), 0 failures.
- `swift run TranscriptorSmokeChecks`: passed.
- `swift build --product Transcriptor`: clean. (A type-check timeout exists in
  FluidAudio's CLI target when building ALL products; it does not affect the
  app, tests, or packaging.)

## Still needs a human pass

- Clicking through the menu bar Active Model submenu and Show/Hide toggle.
- Typing into the sidebar search field (automation lacks Accessibility); the
  result model is unit tested.
- Launch-at-login end-to-end from a packaged `Transcriptor.app`.
