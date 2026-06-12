# Native Polish QA Notes — Round 5 (effortless workflow)

Date: June 12, 2026

Round 5 addresses the senior-UX brief: native sidebar/search/window polish,
aggressive-minimal configuration, first-launch onboarding, model-management
rules, an interactive voice-input result popup, and clickable recent imports.
References: `docs/reference/reference_v3/`.

## Root causes and fixes

| Issue (reported) | Root cause | Fix |
|---|---|---|
| Search field sends keystrokes to the previously active app | SwiftUI `TextField` + `onTapGesture` could not reliably take first responder / make the window key | Replaced with a real `NSSearchField` bridge (`NativeSearchField`) that activates the app and makes the window key on focus, and gives the native rounded look for free |
| Sidebar shows different shades + extra empty space | A separate `NativeSidebarMaterial` was layered behind the search inset and footer; window width was unbounded | Removed the extra materials (single unified sidebar material); removed the bottom footer; capped window width (`maxWidth: 980` + `windowResizability(.contentSize)`) |
| Disclosure arrows (History "Details", Models "Details") | `DisclosureGroup` | Always-expanded `GroupBox`/`VStack` sections |
| Too many settings categories | 8 always-visible panes | Sidebar shows General / Keyboard Shortcut / Advanced; everything else folds into Advanced (still reachable via deep links + search) |
| Could select an undownloaded model / enable auto-transcribe with no model | No guards | `selectLocalModel` + `ModelsView.isSelectable` require downloaded; `canEnableAutoTranscribe`/`isTranscriptionConfigured` gate the toggle and the auto path |
| Empty Overview, no first-run guidance | — | Native hero header + persistent setup banner + first-launch `WelcomeGuideView` sheet |
| Recent Imports not interactive | Static rows | Buttons → `openHistoryEntry` (`pendingHistoryEntryID`) opens the item's History detail |
| Popup just inserted/auto-hid; no review; bad unconfigured UX | Single auto-hiding overlay | New interactive `ResultOverlayView`: transcript **preview** (Show All/Copy/Save/Delete/Re-transcribe) when no focused field, and **recorder result** (Save/Delete/Configure Transcription) when transcription isn't configured |

## Flows implemented

- **Flow A (configured):** dictate → `.transcribing` spinner → if a focused field exists, paste + brief confirmation; otherwise show the interactive transcript preview.
- **Flow B (unconfigured):** dictate → recording kept (pending, not failed) → recorder result card with "Transcription isn't configured." and a Configure Transcription button. No spinner.

## Verification

- `swift test`: 60 passing, 1 skipped, 0 failures (added `ModelManagementRulesTests` + preview/unconfigured flow tests).
- `swift build --product Transcriptor`: clean. `TranscriptorSmokeChecks`: passed.
- Real `screencapture -l` screenshots in this folder: `overview-dark`, `overview-light`,
  `models-dark` (no disclosure arrow; Select disabled for not-downloaded),
  `settings-general-dark` (slim essentials), `settings-advanced-dark` (catch-all),
  `onboarding-dark` (welcome guide).

## Honest limitations

- The setup banner / guide "Set Up Transcription" CTA only render when nothing is
  configured. This QA machine already has a downloaded model, so the captured guide
  shows the "You're ready to go" state. The banner/CTA logic is covered by unit tests.
- Keyboard input into the `NSSearchField` and clicks on the floating result-card
  buttons could not be automated (Accessibility not granted to the harness). The
  native control + window-key activation is the canonical fix; a human should type
  once into search and dismiss one preview card to confirm end to end.

## Round 6 — appearance, window width, search focus, history detail

References: `docs/reference/reference_v4/white_collapsed.png`, `history_item.png`.

| Issue (reported) | Root cause | Fix |
|---|---|---|
| App stuck in light mode; ignores system dark/light | Process launched outside a fully-registered bundle came up as an accessory/background app, so it didn't participate in the system appearance and stayed in default aqua | New `AppDelegate` promotes the process with `NSApp.setActivationPolicy(.regular)` + `activate` on launch, so it inherits the system appearance. No appearance is hard-coded anywhere |
| Typing in search goes to the previously active app; window won't take focus | Same root cause — an accessory/background process can't make its window key, so keystrokes route to the prior frontmost app | The `.regular` activation policy lets the window become key; the existing `NativeSearchField` then takes first responder normally. **Launch the packaged `Transcriptor.app` (`open dist/Transcriptor.app`), not `swift run`** — an un-indexed raw executable can still mis-register |
| Empty gray gutter on the right when the sidebar is hidden | `SettingsContentWidth` always capped content at 620 pt, leaving the freed width blank | `MainWindowView` tracks `NavigationSplitView` `columnVisibility`; when `.detailOnly`, `SettingsContentWidth` lifts the cap so content fills the window (matches `white_collapsed.png`) |
| Initial window too wide | idealWidth 880 | Reduced ~20% → idealWidth 700, minWidth 640 |
| Can't transcribe a history item with no model, and no way to get to Models | The Transcribe action is correctly hidden when nothing is configured, but there was no redirect | Unconfigured items now show an "Open Models" button in the detail banner and a "Set Up Transcription…" context-menu item, both routing to the Models page |
| History detail headers/labels didn't match other pages | `GroupBox` titles render heavy; two raw audio paths were printed in full | `Transcript`/`Details`/`Transcript Versions` now use the grouped-form section header style (small, semibold, secondary). The two audio rows are merged into one **Audio** row with a **View in Finder** button instead of a printed path |

### Round 6 verification

- `swift build --product Transcriptor`: clean. `swift test`: 61 passing, 1 skipped, 0 failures.
- Real on-screen `screencapture -l` evidence in this folder: `r6-history-dark`,
  `r6-history-detail-dark` / `-light` (restyled headers, combined Audio + View in
  Finder, Open Models CTA), `r6-overview-light` (hero + setup banner),
  `r6-settings-general-light`.
- Dark/light captures use the QA appearance override, which proves no surface is
  hard-coded to one appearance. The activation-policy promotion is the actual
  inheritance fix and is best confirmed by launching the packaged app while the
  system is in dark mode.
- Not auto-verifiable (AppleScript can't drive SwiftUI's split-view toggle / first
  responder reliably): the **collapsed-sidebar stretch** and **search keystroke
  routing**. Confirm manually by hiding the sidebar (content should fill the width)
  and typing into search after launching `dist/Transcriptor.app`.
