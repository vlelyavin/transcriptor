# Transcriptor

Transcriptor is a native macOS speech-to-text desktop app with a local-first design. The current build includes native recording, global hotkeys, a live overlay, durable local history, managed audio import, playback, transcript copy/export, and real on-device Whisper-family transcription through WhisperKit.

## Product overview

- Native SwiftUI macOS app targeting macOS 14 and newer.
- Local-first architecture for on-device transcription workflows.
- Real local model downloads and local Whisper transcription.
- Native shell for recording, history, model management, imports, providers, and settings.
- Honest availability states for unsupported runtimes and cloud providers.

## Build

Current environment-verified commands:

```bash
swift build
xcodebuild -scheme Transcriptor -destination 'platform=macOS' build
```

Unsigned release-style local app build:

```bash
xcodebuild -scheme Transcriptor -configuration Release -derivedDataPath ./Build -destination 'platform=macOS' build
open ./Build/Build/Products/Release/Transcriptor.app
```

## Run

```bash
swift run Transcriptor
```

## Test

```bash
swift test
swift run TranscriptorSmokeChecks
```

Opt-in real local transcription integration check:

```bash
RUN_MANUAL_WHISPER_INTEGRATION=1 swift test --filter WhisperKitManualIntegrationTests/testTinyModelTranscribesPublicSampleAudio
```

## Current feature status

- App shell: implemented
- Native macOS Settings window: implemented
- Real local audio recording to Application Support: implemented
- Global configurable hotkey: implemented
- Hold to Talk mode: implemented
- Toggle to Talk mode: implemented
- Live non-activating overlay: implemented
- Durable history persistence across app restarts: implemented
- Audio import to managed local storage: implemented for `.mp3`, `.m4a`, and `.wav`
- `.webm` import: visibly blocked and stored as a failed item until a real decoder/transcoder is added
- Playback for stored recordings and imports: implemented
- Transcript copy and `.txt` export for completed entries: implemented
- Storage usage display and retention pruning: implemented
- Local Whisper model manager: implemented with download, load, delete, and persisted selection state
- Real local Whisper-family transcription: implemented
- Re-transcription with preserved transcript history: implemented
- OpenAI cloud transcription: implemented with Keychain-backed API key storage, configurable model ID, and explicit privacy consent
- Groq cloud transcription: implemented with Keychain-backed API key storage, configurable model ID, and explicit privacy consent
- NVIDIA Parakeet section: visible and truthfully blocked pending a validated native macOS runtime
- Launch at login: preference-only for now; Service Management wiring is still pending
- Save original audio toggle: preference persists, but dictation audio is still retained for safe pending and re-transcription flows

## Supported local models

Transcriptor currently manages these WhisperKit-backed local models:

- `Tiny` via `openai_whisper-tiny`
- `Base (English)` via `openai_whisper-base.en`
- `Small (English)` via `openai_whisper-small.en_217MB`
- `Large V3 Turbo` via `openai_whisper-large-v3-v20240930_turbo_632MB`
- `Distil Large V3` via `distil-whisper_distil-large-v3_594MB`

`Tiny` was downloaded, loaded, and transcribed successfully in this environment through the opt-in integration test above. The remaining mapped Whisper models use the same manager/runtime path but were not all exhaustively downloaded in this run because of size/time.

## Model download notes

- Local model files are downloaded from Argmax's public WhisperKit model repository.
- Downloads are stored under `~/Library/Application Support/Transcriptor/Models`.
- Model cache is excluded from Transcriptor's history storage cap.
- The first load of a model can take noticeably longer than later loads because Core ML may specialize model assets for the local machine.

## Local privacy behavior

- Local Whisper transcription does not upload recording or import audio.
- Recordings, imports, transcripts, and metadata stay in Transcriptor-managed local storage unless you explicitly export a transcript.
- Cloud transcription is opt-in and only works after you enable the provider, store its API key in Keychain, and acknowledge that audio is sent to that provider.

## Cloud provider status

- OpenAI uses `gpt-4o-mini-transcribe` by default and can be pointed at another model ID from Settings if the API changes.
- Groq uses `whisper-large-v3-turbo` by default and can be pointed at another Groq-supported model ID from Settings if the API changes.
- Direct file uploads are currently capped at 25 MB in this build for both OpenAI and Groq. Larger files fail with a clear error instead of being truncated, because provider-side chunk stitching is not implemented yet.
- API keys are stored only in the macOS Keychain. They are not stored in `UserDefaults`, source files, logs, or git.
- Manual end-to-end cloud verification still requires user-provided OpenAI and/or Groq keys. No cloud transcription was run in this environment because no test credentials were provided.

## NVIDIA Parakeet status

- The UI keeps both Parakeet cards visible for roadmap parity.
- Transcriptor does not currently enable Parakeet transcription because NVIDIA's official Parakeet releases are published for Python/NeMo-style runtimes, and this repo does not yet have a validated native macOS Swift/Core ML runtime for those models.
- Unofficial third-party Core ML conversions exist on the internet, but they are intentionally not presented as supported until they are validated and integrated as a reproducible dependency.

## Performance expectations

- `Tiny` is the fastest model and the easiest first download for validation.
- `Base (English)` and `Small (English)` are practical laptop-sized options for English dictation.
- `Large V3 Turbo` and `Distil Large V3` offer higher-quality local transcription at larger download sizes and longer initial load times.

## Troubleshooting model downloads

- If a download button fails immediately, check free disk space first.
- If a transcription request says the model is not ready, download it in `Models` and load it once.
- If the first load feels slow, let Core ML finish specializing the model before retrying.
- If a local transcript fails after import, verify the audio file still exists in Transcriptor-managed Application Support storage.

## Known platform requirements

- macOS 14 or newer
- Apple Swift 6.3 or newer
- Full Xcode is required for `xcodebuild`
- macOS will ask for Microphone permission the first time recording starts
- If Microphone access was denied earlier, re-enable it in `System Settings > Privacy & Security > Microphone`
- Global hotkeys use Carbon registration and work while Transcriptor is running, even when the main window is not focused
- Carbon hotkeys do not normally require Accessibility permission for this build
- Input device selection is not wired yet; recording currently uses the system default input device
- Audio imports are copied into `~/Library/Application Support/Transcriptor`
- `.webm` import is not fully supported because this build does not yet ship a reliable WebM decoder/transcoder
- OpenAI and Groq require working internet access, a provider API key stored in Keychain, and an explicit privacy acknowledgment before audio upload is allowed
- Direct cloud upload is currently limited to 25 MB per file in this build

## Manual QA checklist

1. First launch:
   Run `swift run Transcriptor` and confirm the main window opens with Overview, History, Import Audio, Models, and Settings navigation.
2. Microphone permission:
   Start voice input once and confirm macOS prompts for microphone access. If denied, verify `Settings > Recording` shows the denied state and the button to open Microphone privacy settings.
3. Set shortcut:
   Open `Settings > Keyboard Shortcut`, record a new global shortcut, and confirm obvious conflicts show warnings.
4. Hold-to-talk:
   Set `Hold to Talk`, hold the shortcut, and confirm recording only continues while the shortcut is held.
5. Toggle-to-talk:
   Set `Toggle to Talk`, press once to start and once again to stop, and confirm the state changes cleanly.
6. Overlay:
   Confirm the overlay does not steal focus, reacts to live mic levels, shows elapsed time, and dismisses after save or error.
7. Record and transcribe:
   Download and load `Tiny`, record a short dictation, and confirm the history row moves from pending to transcribing to completed.
8. Import audio:
   Drag in or pick a `.mp3`, `.m4a`, or `.wav`, confirm the hover state, recent imports row, and durable history entry.
9. Copy and export transcript:
   Open a completed history item, use `Copy Transcript` and `Export .txt`, and confirm the default export filename includes the date and title.
10. Re-transcribe:
   Use `Re-transcribe` with another downloaded Whisper model and confirm the current transcript updates while older transcript versions remain listed.
11. Storage cap pruning:
   Lower the storage cap in `Settings > Storage`, confirm usage is displayed, and verify pruning or warning behavior matches the auto-delete toggle.
12. Cloud provider missing-key behavior:
   Set OpenAI or Groq as preferred without a stored key and confirm Transcriptor shows a missing-key or privacy-consent message instead of pretending the provider is ready.

Cloud provider manual steps once you have your own keys:

1. Open `Settings > Cloud Providers`.
2. Enable `OpenAI` or `Groq`.
3. Paste the API key into the secure field, click `Save`, then `Test Key`.
4. Acknowledge the privacy toggle for the provider you want to use.
5. In `Settings > Models`, set that provider as the preferred transcription provider.
6. Record or import an audio file under 25 MB, then transcribe it from `History`.
7. Verify the resulting history item shows the cloud provider name and configured model ID.

## Packaging notes

- Unsigned local app:
  Use the Release `xcodebuild` command above, then open `./Build/Build/Products/Release/Transcriptor.app`.
- Signing still needed for distribution:
  A distributable build still needs an Apple Developer signing identity, a proper bundle identifier strategy, hardened runtime review, notarization, and staple/upload workflow.
- Permissions and entitlements to plan for:
  Microphone usage description is required for shipping builds.
  If you sandbox the app, you will likely need audio input plus outgoing network access for model downloads and cloud providers.
  Sandboxed import/export flows should continue using user-selected file access rather than broad filesystem entitlements.
- Not yet distribution-ready:
  Launch at login is still preference-only, `.webm` remains blocked, and NVIDIA Parakeet remains unavailable pending a validated native runtime.

## Notes

- No secrets are committed.
- `docs/ProductSpec.md` contains the implementation checklist and roadmap.
- `AGENTS.md` contains repo-specific working rules for future contributors and coding agents.
- The Buy button remains a non-functional placeholder.
