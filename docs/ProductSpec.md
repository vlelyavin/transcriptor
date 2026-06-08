# Sotto Product Spec

This document tracks the intended scope for the initial Sotto desktop product. The repository now includes a richer native UI shell with persisted mock settings, but unchecked items are still not functionally implemented unless noted otherwise.

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
- [x] History screen with search, filters, mock rows, and detail pane
- [x] Import Audio screen with drag-and-drop zone, supported format chips, shortcut display, and mock recent imports
- [x] Models screen with WhisperKit, NVIDIA Parakeet, and Cloud Models sections
- [x] Settings hub entry in the main window
- [x] Native Settings window with General, Recording, Keyboard Shortcut, Overlay, Models, Storage, Cloud Providers, and Privacy sections

## UI completion in this task

- [x] Sidebar-based main navigation for Sotto
- [x] Import Audio command with `Cmd+Shift+I`
- [x] UserDefaults-backed mock preferences for recording mode, model selection, storage settings, provider toggles, and launch-at-login placeholder state
- [x] Buy button placeholder kept visibly non-functional

## Current blockers

- Local transcription is blocked by missing model runtime integration, download management, and inference orchestration.
- Audio recording is blocked by missing capture/session infrastructure and UI wiring.
- Cloud providers are blocked by this scaffold intentionally excluding networking and credential flows.
- Build validation in the current environment is blocked until the Apple/Xcode license is accepted with `sudo xcodebuild -license`.
