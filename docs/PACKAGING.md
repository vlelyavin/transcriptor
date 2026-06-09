# Packaging

## Release Artifacts

The supported local packaging flow is:

```bash
scripts/build_release.sh
scripts/package_dmg.sh
```

This produces:

- `dist/Transcriptor.app`
- `dist/Transcriptor.dmg`

## Unsigned Local Builds

If you do not provide a signing identity, the scripts create an unsigned app bundle and DMG. That is enough for local testing, but normal users may see Gatekeeper warnings until the app is signed and notarized.

## Optional Signing Hooks

The scripts accept these optional environment variables:

- `DEVELOPER_ID_APPLICATION`
- `TEAM_ID`
- `NOTARY_PROFILE`

Example:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
TEAM_ID="TEAMID" \
NOTARY_PROFILE="transcriptor-notary" \
scripts/package_dmg.sh
```

`TEAM_ID` is currently informational for release tooling and docs. `NOTARY_PROFILE` is used only if you already configured a notarytool keychain profile on your Mac.

## Packaging Requirements

- A packaged `Transcriptor.app` is required for launch-at-login registration.
- Microphone access must be declared in the generated `Info.plist`.
- Accessibility access is still user-granted at runtime for transcript insertion into other apps.
- No user data, models, recordings, or API keys are bundled into the app or DMG.

## GitHub Release Upload

If you want to publish the DMG manually with GitHub CLI:

```bash
gh release create v0.1.0 dist/Transcriptor.dmg --title "Transcriptor v0.1.0" --notes "Initial public release"
```

If the release already exists:

```bash
gh release upload v0.1.0 dist/Transcriptor.dmg --clobber
```

## GitHub Pages

The landing page source lives in `docs/site/`.

If GitHub Pages is configured for Actions, the included Pages workflow can publish it automatically. If you need to trigger it manually:

```bash
gh workflow run pages.yml
```

## Notarization Follow-Up

The repo now includes optional notarytool hooks, but a production release still needs:

- a real Developer ID Application certificate
- hardened runtime review
- notarization submission and staple verification
- a final Gatekeeper validation pass on a clean Mac
