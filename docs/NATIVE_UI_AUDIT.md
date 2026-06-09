## Native UI Audit

Date: June 9, 2026
Branch audited: `main` / `codex/native-macos-polish-distribution` at `1f9fc52`

### 1. Views that still look non-native or overly custom

- `Sources/TranscriptorKit/UI/MainWindowView.swift`
  The shell uses `NavigationSplitView`, but the sidebar/background treatment is still flat `windowBackgroundColor` rather than a dark native material. The toolbar still behaves like an app-level utility bar instead of screen-aware native navigation.
- `Sources/TranscriptorKit/UI/OverviewView.swift`
  The overview reads like a dashboard summary made from custom cards instead of a compact Mac utility page with grouped rows and recent activity.
- `Sources/TranscriptorKit/UI/SectionCard.swift`
  This component drives a lot of the “third-party dashboard” feeling. Rounded custom cards are used where native grouped `Form`, `List`, `Section`, `LabeledContent`, or inset groups would fit better.
- `Sources/TranscriptorKit/History/HistoryView.swift`
  The layout is content-rich but too custom for a utility app. The split view and section cards work against responsive behavior.
- `Sources/TranscriptorKit/ImportExport/ImportAudioView.swift`
  This screen is the furthest from native: oversized hero text, colorful feature cards, and a marketing-style composition instead of a compact file utility layout.
- `Sources/TranscriptorKit/Models/ModelsView.swift`
  Better than before, but still card-heavy and visually louder than the System Settings references.
- `Sources/TranscriptorKit/Settings/SettingsHomeView.swift`
  This is not a real settings surface. It is a summary page that pushes the user into a separate Settings window, which conflicts with the requested in-app experience.
- `Sources/TranscriptorKit/Settings/SettingsView.swift`
  Functional, but currently optimized for a separate preferences window rather than an in-app, adaptive settings section.

### 2. Views that currently break or degrade at narrow widths

- `MainWindowView`
  The hard minimum size of `1080x720` avoids some breakage, but it hides the real responsiveness problem instead of solving it.
- `HistoryView`
  `HSplitView` with fixed-feeling list/detail widths will clip or feel cramped below roughly `980px`. Detail header, action rows, and metadata density are the main pressure points.
- `ImportAudioView`
  The hero area and `LazyVGrid` category cards break the visual hierarchy and become awkward well before `900px`.
- `SettingsView`
  Works better than the summary screen, but it assumes a wide two-column layout and leaves awkward empty space in the detail pane.
- `OverviewView`
  Three large stacked card sections are fine at wide sizes but feel oversized and wasteful when compressed.

### 3. Target minimum supported window sizes

- Main app window target minimum: `800 x 620`
- Main app two-column comfort width: `960+`
- History two-pane layout threshold: `~980px`
  Below that, History should collapse to a single-column flow with selection-driven detail.
- Settings nested sidebar layout threshold: `~920px`
  Below that, Settings should show a category list first, then category detail.

These targets are intended to preserve usability without clipping, not to preserve identical wide-screen layouts.

### 4. Native macOS structure to introduce

- App shell
  Use `NavigationSplitView` with a real sidebar `List`, stable selection, and a native material-backed sidebar container.
- Overview
  Replace dashboard cards with grouped sections and compact rows. Prefer `List`/`Section` or inset grouped content.
- History
  Keep searchable/filterable list behavior, but use native `List` rows and adaptive list/detail navigation. Hide secondary metadata in `DisclosureGroup` when space is tight.
- Import Audio
  Use a grouped utility layout: restrained drop zone, grouped format/storage rows, recent imports list.
- Models
  Use grouped sections and row-based controls, closer to System Settings than a “catalog card” view.
- Settings
  The main app should host the full settings UI. Use nested `NavigationSplitView` or adaptive list/detail settings categories, with `Form`, grouped `Section`, `Toggle`, `Picker`, `LabeledContent`, `SecureField`, and disclosure sections for provider configuration.

### 5. Why the sidebar currently reads gray instead of dark/native

- `MainWindowView` explicitly uses `Color(nsColor: .windowBackgroundColor)` for the sidebar container.
- The reference screenshots show a darker, translucent sidebar with clear separation from the detail area.
- SwiftUI-only background color is not enough here. A native-feeling result likely needs `NSVisualEffectView` bridging or a stronger material strategy so the sidebar adapts naturally in both light and dark mode.

### 6. Why automatic transcript insertion may fail in real use

- The current UI still makes auto-transcription optional through `autoTranscribeAfterCapture`, even though dictation insertion needs transcription immediately after capture.
- `TranscriptInsertionService.captureCurrentTargetIfNeeded()` only captures a target when Accessibility is already granted. If permission is missing or focus changes during toggle mode, the original target is easily lost.
- The app currently opens separate settings or overlay interactions that can interfere with the “main app stays in background while dictating into another app” mental model.
- The insertion path depends on one captured `AXUIElement` and a fallback paste path, but it does not expose enough user-facing diagnostics about why insertion fell back to copy or save-only.
- There is no strong “missing model/provider” dictation UX. A user can finish recording expecting insertion, then end up with a pending history item instead of a clear setup-required error.
- The current clipboard fallback behavior is technically present, but the product flow is not yet deterministic enough to feel like end-to-end dictation.

### 7. Viable Parakeet integration options

#### Official NVIDIA NeMo / Transformers path

- NVIDIA’s official model cards for `nvidia/parakeet-tdt-0.6b-v2` and `nvidia/parakeet-tdt-0.6b-v3` document Python-first NeMo/Transformers usage, not a native Swift runtime.
- This is viable for research, but not a good direct macOS app integration path by itself.

#### NVIDIA hosted / Riva path

- NVIDIA documents Parakeet in NeMo/Riva ecosystems, but this would move Transcriptor away from a local-first macOS runtime and would introduce server/runtime requirements that are outside this task’s goal.
- Not preferred for this app.

#### ONNX ASR local path

- `istupakov/onnx-asr` is MIT-licensed and explicitly claims Parakeet v2/v3 support, long-form recognition via VAD, and macOS x86/Arm CPU support.
- It is real and viable, but it is Python-based. It also warns that many models have a 20–30 second limit unless VAD-based long-form handling is used.
- This is the best fallback if a direct Swift integration is not practical in this pass.

#### Direct Swift / ONNX Runtime path

- Microsoft ships an ONNX Runtime Swift Package Manager wrapper for macOS, so a direct Swift integration is technically possible.
- The risk is implementation depth: Transcriptor would still need a full Parakeet preprocessing/decoding pipeline, model asset management, and likely custom decoding logic that `onnx-asr` already solved.
- This is technically viable but higher-risk than using an existing Apple-native ASR runtime.

#### Managed Python helper path

- A managed helper around `onnx-asr` is viable if we cannot integrate a direct Swift backend safely.
- It must be honest: setup/runtime packaging would need to be explicit, reproducible, and likely marked beta unless we embed or bootstrap a runtime without requiring terminal steps for normal users.

### 8. Additional viable Apple-native path discovered during audit

- `FluidInference/FluidAudio` is an Apache-2.0 Swift SDK for Apple platforms that publicly documents local Parakeet TDT v3 support via Core ML on macOS 14+.
- This path appears more native to this codebase than a Python helper and may be the best implementation route if its API, model management, and licensing fit cleanly.
- If it integrates cleanly, it is preferable to a Python helper for user experience and packaging.

### 9. Recommended implementation order

1. Rebuild the app shell and adaptive layout around native split-view behavior.
2. Move full settings into the main app and make `Cmd+,` navigate there.
3. Make History and Import adaptive and native-looking at `800px`-class widths.
4. Clean up Models UI.
5. Implement a real Parakeet provider using the best viable local backend.
6. Make dictation insertion deterministic end-to-end, with explicit setup and failure states.
