# Transcriptor Product Spec

This document tracks the intended scope for the initial Transcriptor desktop product. Checked items below are implemented in the current native macOS build unless a follow-up note says otherwise.

## Native polish and distribution follow-up

This branch focuses on the final product-facing pass needed before broader distribution:

- [x] Redesign the main window to feel closer to a native macOS sidebar/detail app
- [x] Move the full Settings experience into the main app and keep it close to macOS System Settings
- [x] Remove the Buy placeholder from all user-facing surfaces
- [x] Redesign the voice input overlay into a centered dictation experience
- [x] Add automatic transcript insertion into the active text field with Accessibility-aware fallback behavior
- [x] Add a menu bar status item that reflects idle, recording, transcribing, and failed states
- [x] Replace the launch-at-login preference placeholder with real Service Management support or an honest packaged-app limitation state
- [x] Rewrite README.md as a user-facing install and usage guide
- [x] Move developer and packaging details into dedicated docs
- [x] Add DMG packaging scripts and release-distribution documentation
- [x] Add a GitHub Pages landing page and distribution workflows if repository permissions allow

## Final QA status matrix

| Feature | Status | Notes |
| --- | --- | --- |
| Global voice-input shortcut | Done | Carbon-based global hotkey with configurable capture and conflict warnings. |
| Hold-to-talk and toggle-to-talk | Done | Both modes record through the same voice input state machine. |
| Recording overlay | Done | The overlay is centered, dimmed, and covers listening, finishing, transcribing, inserting, saved, and error states. |
| Local recording save | Done | Recordings are saved under Application Support and queued into history. |
| Import audio: `.mp3`, `.m4a`, `.wav` | Done | Drag-and-drop plus file-picker import copy files into app-managed storage. |
| Import audio: `.webm` | Blocked | Stored as a failed import until a real WebM decoder/transcoder is integrated. |
| Transcript history, search, playback, copy/export, re-transcribe | Done | Durable local metadata, transcript actions, playback, and versioned re-transcription are in place. |
| Storage cap and pruning | Done | Current usage is visible and oldest-first pruning is enforced when enabled. |
| Automatic transcript insertion | Partial | The insertion service now captures the original app and focused target, blocks wrong-target insertion, and falls back to clipboard/history safely. Unit coverage is in place, but this branch still needs a final manual cross-app QA pass with Accessibility permission granted. |
| Menu bar status item | Done | A native menu bar item reflects voice input state and exposes quick actions. |
| Launch at login | Partial | Packaged `Transcriptor.app` builds can use Service Management. Raw `swift run` and command-line development builds truthfully report “Needs Packaged App”. |
| Save original audio toggle | Partial | The preference persists, but dictation audio is still retained for safe pending/re-transcription workflows. |
| Input device selection | Partial | The app currently records from the system default input device only. |
| Local Whisper-family transcription | Done | WhisperKit-backed local model download, load, transcribe, and delete flows are implemented. |
| OpenAI and Groq cloud transcription | Done | Keychain-backed keys, configurable model IDs, explicit privacy gating, and provider errors are implemented. |
| NVIDIA Parakeet local provider | Partial | A real local FluidAudio/Core ML provider is integrated for Apple Silicon, with model management and transcription wiring. It should be treated as beta until a full v2/v3 manual smoke transcription is completed in this branch. |
| In-app Settings | Done | Settings now live directly inside the main window with a native sidebar/detail layout and grouped preference sections. |

## Core interaction

- [x] Global voice-input shortcut
- [x] Hold-to-talk / press-to-talk mode
- [x] Toggle push-to-talk mode
- [x] Non-activating overlay with live audio indicator
- [x] Local recording save

## Audio import and export

- [x] Import audio: `.mp3`, `.m4a`, `.wav`
- [ ] Import audio: `.webm`
- [x] Export transcript to `.txt`

## Transcript history

- [x] Transcript history
- [x] History search
- [x] Playback original audio
- [x] Re-transcribe with another model
- [x] Copy transcript

## Storage and lifecycle

- [x] Storage cap in MB for history/audio/transcripts, excluding downloaded model files
- [x] Durable local history persistence across app restarts
- [x] Delete history item
- [x] Delete all history with confirmation
- [x] Model manager

## Model support

- [x] Local Whisper-family models
- [x] NVIDIA Parakeet model section

## Providers

- [x] Cloud provider section for OpenAI
- [x] Cloud provider section for Groq
- [x] OpenAI API key storage in macOS Keychain
- [x] Groq API key storage in macOS Keychain
- [x] OpenAI cloud transcription with configurable model ID
- [x] Groq cloud transcription with configurable model ID
- [x] Explicit cloud privacy consent before audio upload
- [x] Re-transcription via available cloud providers
- [x] Block oversize cloud uploads with a clear error instead of truncating audio

## App surfaces

- [x] Native in-app Settings surface
- [x] Main window shell
- [x] History screen with search, filters, real persisted rows, progress, and detail pane
- [x] Import Audio screen with drag-and-drop zone, supported format chips, shortcut display, and recent persisted imports
- [x] Models screen with WhisperKit, Parakeet, and Cloud Models sections
- [x] Settings hub entry in the main window
- [x] In-app Settings with General, Recording, Keyboard Shortcut, Overlay, Models, Storage, Cloud Providers, and Privacy sections

## UI completion

- [x] Sidebar-based main navigation for Transcriptor
- [x] Import Audio command with `Cmd+Shift+I`
- [x] UserDefaults-backed preferences for recording mode, model selection, storage settings, provider toggles, and cloud privacy state
- [ ] Launch-at-login Service Management integration
- [x] Search History command with `Cmd+F`
- [x] Voice Input start/stop menu command
- [x] Open Settings command with `Cmd+,`
- [x] Menu bar status item with voice input controls
- [x] Automatic transcript insertion into the active app with Accessibility-aware fallback
- [x] Launch-at-login status surfaced honestly in Settings

## Voice input completion

- [x] AudioRecorderService with microphone permission flow, local file saving, duration, file size, and live level data
- [x] VoiceInputController explicit states: idle, requestingPermission, recording, stopping, pendingTranscription, failed
- [x] Configurable global shortcut capture and Carbon-based registration
- [x] Hold to Talk behavior
- [x] Toggle to Talk behavior
- [x] Non-activating floating recording overlay
- [x] Pending transcription history handoff after recording stops
- [x] Tests for controller transitions, recording mode behavior, and recording storage path generation

## Durable history completion

- [x] SwiftData-backed persistence for history records
- [x] Application Support layout for `Recordings`, `Imports`, `Metadata`, and reserved `Models`
- [x] File-picker and drag-and-drop audio import into app-managed storage
- [x] Local playback for stored recordings and imports
- [x] Native transcript copy and `.txt` export
- [x] Search by transcript text, filename, preview, and model name
- [x] Storage usage display and oldest-first pruning when auto-delete is enabled
- [x] Blocking new imports when storage is over cap and auto-delete is disabled
- [x] Tests for persistence CRUD, storage usage, pruning order, transcript export formatting, and missing-file playback

## Local transcription completion

- [x] Provider abstraction with `TranscriptionProvider`, `LocalTranscriptionProvider`, `TranscriptionJob`, `TranscriptionResult`, `TranscriptionProgress`, and `TranscriptionError`
- [x] Async transcription queue with cancellation, persisted history status updates, and queue progress surfaced in History
- [x] WhisperKit integration pinned to Argmax OSS Swift `1.0.0`
- [x] Real model manager flows for download, load, and delete
- [x] Local transcription for new or existing pending recordings/imports once a local model is downloaded
- [x] Re-transcription with transcript version preservation
- [x] Settings for default local model, auto-transcribe after recording/import, and preferred local provider
- [x] Tests for model catalog mapping, provider-backed queue transitions, cancellation, and re-transcription version preservation

### Implemented local Whisper catalog

- [x] Tiny mapped to `openai_whisper-tiny`
- [x] Base (English) mapped to `openai_whisper-base.en`
- [x] Small (English) mapped to `openai_whisper-small.en_217MB`
- [x] Large V3 Turbo mapped to `openai_whisper-large-v3-v20240930_turbo_632MB`
- [x] Distil Large V3 mapped to `distil-whisper_distil-large-v3_594MB`

### Environment verification in this task

- [x] `Tiny` downloaded, loaded, and transcribed a short public sample successfully in the local environment
- [x] Standard `swift test` remains fast by keeping the real Whisper integration test opt-in

### Parakeet Local beta status

- [x] FluidAudio `0.15.2` integrated as the verified local Parakeet runtime
- [x] Parakeet v2 (English) catalog entry maps to the local provider
- [x] Parakeet v3 (Multilingual) catalog entry maps to the local provider
- [x] Model inventory, download, load, delete, and provider-selection flows are wired into the app
- [ ] Full manual Parakeet smoke transcription completed in this branch

## Permissions and follow-up notes

- Microphone access is required before audio recording can start.
- Accessibility access is required only when Transcriptor inserts text into another app.
- The app exposes a direct shortcut to the macOS Microphone privacy pane when access is denied.
- The app exposes direct shortcuts to the macOS Accessibility and Login Items settings panes.
- Global hotkeys are registered while Transcriptor is running and do not require the main window to stay focused.
- Carbon hotkeys do not normally require Accessibility permission for this use case.
- Local model downloads require network access to Argmax's public WhisperKit model repository.
- Input device selection is a documented follow-up. The current build records from the system default microphone.
- Imported audio is copied into Transcriptor-managed local storage under Application Support so history survives app restarts.
- Finder imports rely on standard user-granted file access from the open panel or drag and drop before files are copied into app-managed storage.
- Launch at login works only from a packaged `Transcriptor.app`. Development executables still show an honest blocked state instead of pretending registration succeeded.

## Current blockers

- Parakeet Local currently targets Apple Silicon only because the verified FluidAudio/Core ML backend used here is not a universal Intel plus Apple Silicon packaging story yet.
- Parakeet Local is still considered beta until a full manual smoke transcription pass is completed with a downloaded v2 or v3 model in this branch.
- `.webm` import remains blocked because this build does not yet include a reliable WebM decoder/transcoder dependency. WebM files are stored as failed import records instead of being falsely treated as supported.

## Cloud transcription completion

- [x] OpenAI credentials stored only in Keychain
- [x] Groq credentials stored only in Keychain
- [x] Provider-specific model IDs persist locally and remain user-editable
- [x] Cloud providers expose API-key save, remove, and test flows in Settings
- [x] Cloud providers require explicit provider enablement plus privacy acknowledgment
- [x] History re-transcription menu includes ready cloud providers
- [x] Tests cover request construction, missing-key handling, provider selection, cloud privacy gating, and local Parakeet provider selection rules

### Cloud provider notes

- OpenAI is wired to `POST /v1/audio/transcriptions` with `gpt-4o-mini-transcribe` as the default model ID, based on OpenAI's current speech-to-text docs.
- Groq is wired to `POST /openai/v1/audio/transcriptions` with `whisper-large-v3-turbo` as the default model ID, based on Groq's current speech-to-text docs.
- This build currently blocks cloud uploads above 25 MB with a clear error message. It does not silently truncate audio and it does not yet implement chunk stitching.
- Manual end-to-end cloud verification still requires user-provided credentials and was not run in this environment.
