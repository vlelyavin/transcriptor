# Development

## Build

```bash
swift build
xcodebuild -scheme Transcriptor -destination 'platform=macOS' build
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

## Manual WhisperKit Integration Check

```bash
RUN_MANUAL_WHISPER_INTEGRATION=1 swift test --filter WhisperKitManualIntegrationTests/testTinyModelTranscribesPublicSampleAudio
```

This opt-in test downloads and uses a real local Whisper model. It is intentionally excluded from the fast default suite.

## Local Packaging

```bash
scripts/build_release.sh
scripts/package_dmg.sh
```

Artifacts land in `dist/`:

- `dist/Transcriptor.app`
- `dist/Transcriptor.dmg`

## Notes For Contributors

- The repo currently builds a runnable macOS executable through SwiftPM.
- `scripts/build_release.sh` wraps that executable into a proper `Transcriptor.app` bundle for distribution.
- Launch at login only works from the packaged app bundle, not from `swift run` or raw build products.
- API keys must stay in Keychain only.
- Do not commit downloaded models, recordings, exports, or generated DMGs.

## Known Implementation Limitations

- `.webm` import remains blocked until a reliable decoder or transcoder is integrated.
- NVIDIA Parakeet remains blocked until a validated native macOS runtime exists.
- Input device selection still uses the system default input.
- The “Save original audio” setting is still partial because dictation audio must be retained for pending transcription and re-transcription safety.
