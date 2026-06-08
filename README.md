# Sotto

Sotto is a native macOS speech-to-text desktop app with a local-first design. This initial scaffold focuses on a clean SwiftUI shell, feature planning, and a truthful product surface for future local Whisper-family models, optional cloud providers, a recording overlay, hotkeys, history, and storage controls.

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
swift run SottoSmokeChecks
```

## Current feature status

- App shell: implemented
- Smoke checks: implemented
- Main window and sidebar navigation: implemented
- Native macOS Settings window: implemented with persisted mock preferences
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
- Full Xcode is required for `xcodebuild`; this repository was scaffolded in an environment with Command Line Tools only, so validation here used `swift build` and `swift run SottoSmokeChecks`
- The current local machine must also accept the Apple/Xcode license with `sudo xcodebuild -license` before build commands will run again
- API keys must be stored in the macOS Keychain only when provider support is implemented

## Notes

- No secrets are committed.
- `docs/ProductSpec.md` contains the implementation checklist and roadmap.
- `AGENTS.md` contains repo-specific working rules for future contributors and coding agents.
