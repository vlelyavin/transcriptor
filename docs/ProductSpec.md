# Sotto Product Spec

This document tracks the intended scope for the initial Sotto desktop product. The current repository state is an app shell only; unchecked items are not yet implemented unless noted otherwise.

## Core interaction

- [ ] Global voice-input shortcut
- [ ] Hold-to-talk / press-to-talk mode
- [ ] Toggle push-to-talk mode
- [ ] Non-activating overlay with live audio indicator
- [ ] Local recording save

## Audio import and export

- [ ] Import audio: `.mp3`, `.m4a`, `.wav`, `.webm`
- [ ] Export transcript to `.txt`

## Transcript history

- [ ] Transcript history
- [ ] History search
- [ ] Playback original audio
- [ ] Re-transcribe with another model
- [ ] Copy transcript

## Storage and lifecycle

- [ ] Storage cap in MB for history/audio/transcripts, excluding downloaded model files
- [ ] Model manager

## Model support

- [ ] Local Whisper-family models
- [ ] NVIDIA Parakeet model section

## Providers

- [ ] Cloud provider section for OpenAI
- [ ] Cloud provider section for Groq

## App surfaces

- [x] Native macOS Settings window
- [x] Main window shell
- [x] Placeholder History screen
- [x] Placeholder Import Audio screen
- [x] Placeholder Models screen
- [x] Placeholder Settings screen

## Current blockers

- Local transcription is blocked by missing model runtime integration, download management, and inference orchestration.
- Audio recording is blocked by missing capture/session infrastructure and UI wiring.
- Cloud providers are blocked by this scaffold intentionally excluding networking and credential flows.
- `xcodebuild` validation is blocked in the current environment because full Xcode is not installed or selected; `swift build` and `swift test` are the verified commands here.
