# Transcriptor

Transcriptor is a free local-first macOS speech-to-text app for fast dictation, audio transcription, and transcript history.

> Screenshot placeholders: polished app screenshots can be added here once release-ready captures are exported from the latest native UI.

## What Transcriptor Does

- Global voice input shortcut
- Hold-to-talk and toggle-to-talk modes
- Local Whisper transcription with downloadable on-device models
- Transcript history with search, playback, re-transcription, copy, and export
- Audio import for `.mp3`, `.m4a`, and `.wav`
- Automatic insertion into the active text field after transcription
- Native menu bar icon and voice input controls
- Launch at login for packaged app builds
- Optional OpenAI and Groq cloud transcription

## Privacy

- Local Whisper models keep audio on your Mac.
- Cloud providers only receive audio after you explicitly enable them and confirm the privacy warning.
- OpenAI and Groq API keys are stored in the macOS Keychain.
- Recordings, imports, and transcripts stay in Transcriptor-managed local storage unless you export them.

## Install

1. Download the latest DMG from the GitHub Pages install page or the latest GitHub Release.
2. Open `Transcriptor.dmg`.
3. Drag `Transcriptor.app` into `Applications`.
4. Launch Transcriptor from `Applications`.

Unsigned local builds may show a Gatekeeper warning until the app is signed and notarized. Packaging details live in [docs/PACKAGING.md](docs/PACKAGING.md).

## First Run

1. Grant microphone access when macOS asks.
2. Open `Models` and download a local Whisper model such as `Tiny`.
3. Open `Settings > Keyboard Shortcut` and choose your voice input shortcut.
4. If you want automatic text insertion into other apps, grant Accessibility access in `Settings > Recording`.
5. Start dictating with the toolbar button, menu bar item, or global shortcut.

## Features

### Voice input

- Global shortcut works while Transcriptor is running
- Hold-to-talk and toggle-to-talk recording modes
- Centered overlay with live waveform, elapsed time, and done/cancel flow
- Automatic insertion back into the previously focused app when permitted

### Transcription

- Local WhisperKit-backed transcription
- Download, load, delete, and switch models from the app
- Re-transcribe saved history items with a different provider or model
- Optional OpenAI and Groq cloud transcription with explicit consent

### History

- Durable local history across app restarts
- Search by transcript text, preview, and model name
- Playback original audio
- Copy transcript
- Export transcript to `.txt`
- Storage cap and oldest-first pruning controls

## FAQ

### Why does Transcriptor ask for Accessibility permission?

Accessibility permission is only needed if you want Transcriptor to insert the final transcript directly into another app's text field. Without it, Transcriptor still saves the transcript to history and can optionally copy it to the clipboard.

### Why does the first local model download take time?

The first download can be large, and the first model load may take longer while Core ML prepares the model for your Mac.

### What happens to my recordings and transcripts?

They are stored locally inside Transcriptor-managed Application Support folders so history survives app restarts. You can delete individual items or clear everything from History.

### How do I delete history?

Open `History`, select an item, and use the delete action. There is also a delete-all action with confirmation.

### Why might NVIDIA Parakeet or WebM import be unavailable?

Parakeet remains disabled until a validated native macOS runtime is integrated. `.webm` import remains blocked until the app ships a real decoder or transcoder instead of pretending support exists.

### Why can launch at login say “Needs Packaged App”?

That status appears when you run Transcriptor from `swift run` or a raw development executable. Launch at login only works from a packaged `Transcriptor.app`.

## Developer Docs

- Development and test commands: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)
- Packaging and release notes: [docs/PACKAGING.md](docs/PACKAGING.md)
- Product checklist and status: [docs/ProductSpec.md](docs/ProductSpec.md)
