# Sotto

Sotto is a native macOS speech-to-text desktop app with a local-first design. The current build includes native recording, global hotkeys, a live overlay, durable local history, managed audio import, playback, transcript copy/export, and real on-device Whisper-family transcription through WhisperKit.

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
xcodebuild -scheme Sotto -destination 'platform=macOS' build
```

## Run

```bash
swift run Sotto
```

## Test

```bash
swift test
swift run SottoSmokeChecks
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
- NVIDIA Parakeet section: visible but unavailable
- OpenAI provider section: visible but unavailable
- Groq provider section: visible but unavailable

## Supported local models

Sotto currently manages these WhisperKit-backed local models:

- `Tiny` via `openai_whisper-tiny`
- `Base (English)` via `openai_whisper-base.en`
- `Small (English)` via `openai_whisper-small.en_217MB`
- `Large V3 Turbo` via `openai_whisper-large-v3-v20240930_turbo_632MB`
- `Distil Large V3` via `distil-whisper_distil-large-v3_594MB`

`Tiny` was downloaded, loaded, and transcribed successfully in this environment through the opt-in integration test above. The remaining mapped Whisper models use the same manager/runtime path but were not all exhaustively downloaded in this run because of size/time.

## Model download notes

- Local model files are downloaded from Argmax's public WhisperKit model repository.
- Downloads are stored under `~/Library/Application Support/Sotto/Models`.
- Model cache is excluded from Sotto's history storage cap.
- The first load of a model can take noticeably longer than later loads because Core ML may specialize model assets for the local machine.

## Local privacy behavior

- Local Whisper transcription does not upload recording or import audio.
- Recordings, imports, transcripts, and metadata stay in Sotto-managed local storage unless you explicitly export a transcript.
- Cloud providers remain disabled for real transcription in this build.

## Performance expectations

- `Tiny` is the fastest model and the easiest first download for validation.
- `Base (English)` and `Small (English)` are practical laptop-sized options for English dictation.
- `Large V3 Turbo` and `Distil Large V3` offer higher-quality local transcription at larger download sizes and longer initial load times.

## Troubleshooting model downloads

- If a download button fails immediately, check free disk space first.
- If a transcription request says the model is not ready, download it in `Models` and load it once.
- If the first load feels slow, let Core ML finish specializing the model before retrying.
- If a local transcript fails after import, verify the audio file still exists in Sotto-managed Application Support storage.

## Known platform requirements

- macOS 14 or newer
- Apple Swift 6.3 or newer
- Full Xcode is required for `xcodebuild`
- macOS will ask for Microphone permission the first time recording starts
- Global hotkeys use Carbon registration and work while Sotto is running, even when the main window is not focused
- Input device selection is not wired yet; recording currently uses the system default input device
- Audio imports are copied into `~/Library/Application Support/Sotto`
- `.webm` import is not fully supported because this build does not yet ship a reliable WebM decoder/transcoder
- API keys must be stored in the macOS Keychain only when provider support is implemented

## Manual test steps

1. Run `swift run Sotto`.
2. Open `Models` and download `Tiny`.
3. Load `Tiny`, then set it as the preferred model if it is not already selected.
4. In `Settings > Models`, optionally enable `Auto-transcribe after recording or import`.
5. Record a short dictation or import a `.mp3`, `.m4a`, or `.wav`.
6. Open the item in `History` and click `Transcribe Now`.
7. Confirm the status changes from pending to transcribing to completed, and that transcript text plus model/provider metadata appear in the detail pane.
8. Use `Re-transcribe` with another downloaded Whisper model and confirm the transcript updates while older transcript versions remain listed below.
9. Use `Copy Transcript`, `Export .txt`, and `Play` to verify transcript actions and playback.

## Notes

- No secrets are committed.
- `docs/ProductSpec.md` contains the implementation checklist and roadmap.
- `AGENTS.md` contains repo-specific working rules for future contributors and coding agents.
- The Buy button remains a non-functional placeholder.
