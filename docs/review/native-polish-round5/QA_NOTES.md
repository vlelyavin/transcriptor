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
