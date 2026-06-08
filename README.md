# Sotto

Sotto is a native macOS speech-to-text desktop app with a local-first design. The current build includes a native UI shell, real local audio recording, configurable global voice-input hotkeys, a live recording overlay, pending-history handoff, and a truthful product surface for future local Whisper-family models and optional cloud providers.

## Product overview

- Native SwiftUI macOS app targeting macOS 14 and newer.
- Local-first architecture for on-device transcription workflows.
- Native shell for recording, history, model management, imports, providers, and settings.
- Honest availability states for anything not implemented yet.

## Build

Current environment-verified command:

```bash
swift build
```

When full Xcode is installed and selected, the package can also be built with:

```bash
xcodebuild -scheme Sotto -destination 'platform=macOS' build
```

## Run

```bash
swift run Sotto
```

## Test

```bash
swift test
```

Smoke checks are also available with:

```bash
swift run SottoSmokeChecks
```

## Current feature status

- App shell: implemented
- Smoke checks: implemented
- XCTest coverage for controller and storage logic: implemented
- Main window and sidebar navigation: implemented
- Native macOS Settings window: implemented with persisted mock preferences
- Real local audio recording to Application Support: implemented
- Global configurable hotkey: implemented
- Hold to Talk mode: implemented
- Toggle to Talk mode: implemented
- Live non-activating overlay: implemented
- Pending transcription history items for completed recordings: implemented
- Transcript history screen: implemented with search, filters, mock rows, and detail pane
- Import audio screen: implemented with drag-and-drop zone, shortcut, and mock recent imports
- Model manager screen: implemented with WhisperKit, Parakeet, and cloud sections
- Local Whisper-family models: planned, not implemented
- NVIDIA Parakeet section: visible but unavailable
- OpenAI provider section: visible but unavailable
- Groq provider section: visible but unavailable
- Real recording, transcription, and networking: intentionally not implemented

## Known platform requirements

- macOS 14 or newer
- Apple Swift 6.3 or newer
- Full Xcode is required for `xcodebuild` and `swift test`
- The current local machine must also accept the Apple/Xcode license with `sudo xcodebuild -license` before build commands will run again
- macOS will ask for Microphone permission the first time recording starts
- Global hotkeys use Carbon registration and work while Sotto is running, even when the main window is not focused
- Input device selection is not wired yet; recording currently uses the system default input device
- API keys must be stored in the macOS Keychain only when provider support is implemented

## Notes

- No secrets are committed.
- `docs/ProductSpec.md` contains the implementation checklist and roadmap.
- `AGENTS.md` contains repo-specific working rules for future contributors and coding agents.
- The Buy button remains a non-functional placeholder.

## Manual test steps

1. Run `swift run Sotto`.
2. Open Settings and choose a global shortcut in `Keyboard Shortcut`.
3. In `Recording`, choose `Hold to Talk` or `Toggle to Talk`.
4. Start recording once to trigger the macOS microphone permission prompt.
5. Verify the floating overlay appears without focusing the Sotto window.
6. Speak into the microphone and confirm the live level bars react.
7. Stop recording and confirm a new `Pending transcription` item appears in History with a local audio path and duration.
