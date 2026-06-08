# Sotto Product Spec

This document tracks the intended scope for the initial Sotto desktop product. The repository now includes a richer native UI shell with persisted mock settings, but unchecked items are still not functionally implemented unless noted otherwise.

## Core interaction

- [x] Global voice-input shortcut
- [x] Hold-to-talk / press-to-talk mode
- [x] Toggle push-to-talk mode
- [x] Non-activating overlay with live audio indicator
- [x] Local recording save

## Audio import and export

- [x] Import audio: `.mp3`, `.m4a`, `.wav`, `.webm`
- [ ] Export transcript to `.txt`

## Transcript history

- [x] Transcript history
- [x] History search
- [ ] Playback original audio
- [ ] Re-transcribe with another model
- [ ] Copy transcript

## Storage and lifecycle

- [x] Storage cap in MB for history/audio/transcripts, excluding downloaded model files
- [x] Model manager

## Model support

- [ ] Local Whisper-family models
- [x] NVIDIA Parakeet model section

## Providers

- [x] Cloud provider section for OpenAI
- [x] Cloud provider section for Groq

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

## Voice Input completion in this task

- [x] AudioRecorderService with microphone permission flow, local file saving, duration, file size, and live level data
- [x] VoiceInputController explicit states: idle, requestingPermission, recording, stopping, pendingTranscription, failed
- [x] Configurable global shortcut capture and Carbon-based registration
- [x] Hold to Talk behavior
- [x] Toggle to Talk behavior
- [x] Non-activating floating recording overlay
- [x] Pending transcription history handoff after recording stops
- [x] Tests for controller transitions, recording mode behavior, and recording storage path generation

## Permissions and follow-up notes

- Microphone access is required before audio recording can start.
- Global hotkeys are registered while Sotto is running and do not require the main window to stay focused.
- Input device selection is a documented follow-up. The current build records from the system default microphone.

## Current blockers

- Local transcription is blocked by missing model runtime integration, download management, and inference orchestration.
- Cloud providers are blocked by this scaffold intentionally excluding networking and credential flows.
- Build validation in the current environment is blocked until the Apple/Xcode license is accepted with `sudo xcodebuild -license`.
