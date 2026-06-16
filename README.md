# Transcriptor

Transcriptor is a free local-first macOS speech-to-text app for fast dictation, audio transcription, and transcript history.

> Screenshot placeholders: polished app screenshots can be added here once release-ready captures are exported from the latest native UI.

## What Transcriptor Does

- Global voice input shortcut
- Hold-to-talk and toggle-to-talk modes
- Local Whisper transcription with downloadable on-device models
- Parakeet Local beta on Apple Silicon through a real local Core ML backend
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

1. Download `Transcriptor.dmg` from the [latest GitHub Release](https://github.com/vlelyavin/transcriptor/releases/latest).
2. Open the DMG and drag `Transcriptor.app` into `Applications`.
3. Launch Transcriptor from `Applications`.

**If macOS says the app "is damaged" or "can't be opened":** the current builds are not yet notarized by Apple, so macOS quarantines them after download. Clear the quarantine flag once — this is safe, it only removes the "downloaded from the internet" marker:

```sh
xattr -dr com.apple.quarantine /Applications/Transcriptor.app
```

Then open the app normally. A notarized build (see [Building and Distribution](#building-and-distribution)) removes this step entirely. Packaging details also live in [docs/PACKAGING.md](docs/PACKAGING.md).

## First Run

1. Grant microphone access when macOS asks.
2. Open `Models` and download a local model such as `Tiny`.
3. Open `Settings` in the main sidebar and choose your voice input shortcut in `Keyboard Shortcut`.
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
- Local Parakeet beta for Apple Silicon, with in-app model management
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

Parakeet Local is a beta Apple Silicon-only path in the current build, and it still needs a large first-run model download before it is usable. `.webm` import remains blocked until the app ships a real decoder or transcoder instead of pretending support exists.

### Why can launch at login say “Needs Packaged App”?

That status appears when you run Transcriptor from `swift run` or a raw development executable. Launch at login only works from a packaged `Transcriptor.app`.

## Building and Distribution

Build a packaged app and a distributable disk image from the CLI:

```sh
bash scripts/build_release.sh   # compiles release → dist/Transcriptor.app
bash scripts/package_dmg.sh     # builds the app + packages it → dist/Transcriptor.dmg
```

How the app is signed — and therefore how smooth the install is for other people — depends on what's available:

| Tier | Cost | What users see | How |
| --- | --- | --- | --- |
| **Notarized (Developer ID)** | Apple Developer Program, $99/year | Double-click to open, no warnings | Set `DEVELOPER_ID_APPLICATION` + `NOTARY_PROFILE`; `package_dmg.sh` signs, notarizes, and staples |
| **Ad-hoc (default)** | Free | Works, but each user clears quarantine once (`xattr -dr com.apple.quarantine …`) | Nothing — this is the fallback |

Notarization is the **only** way to get a fully warning-free install, and it needs the paid membership (the notary service itself is free once you're enrolled). Because Transcriptor relies on the Accessibility API, global hotkeys, and inserting text into arbitrary apps, it is distributed **directly** (Developer ID + notarization), not via the sandboxed Mac App Store. To enable notarization:

```sh
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
xcrun notarytool store-credentials transcriptor-notary \
  --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
NOTARY_PROFILE="transcriptor-notary" bash scripts/package_dmg.sh
```

### Stable permissions during local development

Ad-hoc signing changes the app's signature on every build, so macOS resets its Microphone and Accessibility grants each time. Sign local builds with a fixed self-signed certificate so the grants persist:

```sh
bash scripts/setup_local_signing_cert.sh   # one-time: create the cert
bash scripts/build_release.sh              # auto-signs with it from now on
```

The certificate is self-signed and only affects your own machine — it does nothing for distribution (other Macs don't trust it). Undo with `scripts/setup_local_signing_cert.sh --remove`.

## Developer Docs

- Development and test commands: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)
- Packaging and release notes: [docs/PACKAGING.md](docs/PACKAGING.md)
- Product checklist and status: [docs/ProductSpec.md](docs/ProductSpec.md)
