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

## Manual QA Focus For This Branch

- Resize the main window to roughly `800x620` and confirm the sidebar stays readable with no clipped labels.
- Open `History` at narrow width and verify the list-first/detail-second navigation flow works without overflow.
- Open `Import Audio` at narrow width and confirm the drop zone and grouped rows collapse to one column cleanly.
- Open `Settings` from the main sidebar and confirm all panes are usable without opening a separate preferences window.
- In `Settings > Recording`, review the last insertion debug section after testing dictation into TextEdit or Safari.
- If Accessibility permission is denied, confirm dictation still saves to history and reports a clipboard/manual-paste fallback.
- On Apple Silicon, download a Parakeet Local model and run a short WAV transcription smoke test before marking Parakeet as fully validated.

## Known Implementation Limitations

- `.webm` import remains blocked until a reliable decoder or transcoder is integrated.
- Parakeet Local now uses a real FluidAudio/Core ML backend on Apple Silicon, but it is still treated as beta until a full manual v2/v3 smoke transcription pass is completed.
- Input device selection still uses the system default input.
- The “Save original audio” setting is still partial because dictation audio must be retained for pending transcription and re-transcription safety.
