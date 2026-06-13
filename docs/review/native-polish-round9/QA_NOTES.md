# Native Polish QA Notes — Round 9 (History detail, cloud setup, mandatory permissions)

Date: June 13, 2026

Round 9 makes the History Item page fully native, rebuilds the cloud-provider
setup to native proportions with a stricter (validated) readiness model, hardens
the mandatory setup flow to also require Accessibility access, and removes a
duplicate settings page.

## Changes by brief item

| # | Item | Implementation |
|---|------|----------------|
| 1 | Remove History Item breadcrumbs | The in-content "‹ History" back button is gone. In the narrow single-column layout, back navigation moved to a native toolbar chevron (`ToolbarItem(.navigation)`); in the wide split layout there's no back affordance at all. The detail starts directly with its content. |
| 2 | Section label styling | The detail pane was rebuilt as a grouped `Form` (`.formStyle(.grouped)`), so "Transcript", "Details", and "Transcript Versions" are now real `Section` headers — byte-for-byte the same style as every other page. The old `GroupBox` + custom `historySectionHeader` is removed. |
| 3 | Details key/value table + Finder button | The Details section uses native `LabeledContent` rows (keys left, values right) matching the Current Selection / About-style table. "Open in Finder" is a gray secondary button (`.buttonStyle(.bordered)`, small). No raw file paths are shown. |
| 4 | More button | The action-bar `Menu` label is now `Text("More…")` — text, no icon. |
| 5 | Provider setup layout + no key in errors | The OpenAI/Groq sections were rebuilt to the native network-panel shape: a top **Status** line carrying the red/green dot + the "send audio" consent switch, then the connection message, Model ID, API Key, and actions below. Provider error text is run through `redactingAPIKeys()` (in the cloud provider), which strips any `sk-…`/`gsk_…` token — including masked variants — so a raw or partially-masked key never reaches the UI, logs, or history. |
| 6 | Status indicator logic + colors | The status dot is **green only when fully ready, red otherwise** — no blue anywhere. Readiness now requires, in order: consent → stored key → a **passing key test**. `ProviderRuntimeState` gained `.needsValidation`; `providerRuntimeState(for:)` never returns `.ready` before validation has passed. |
| 7 | Provider form behavior | Consent is the first gate: Model ID, API Key, Save, and Test are **disabled until consent is on**. The API Key field has **no icons**; the stored-key status is plain gray text ("Stored in Keychain" / "No key stored"). |
| 8 | Test validates the entered key | `testAPIKey(for:enteredKey:)` now validates the **freshly entered** key (storing it first) when the field is non-empty, and only falls back to the stored key when the field is empty. Saving or removing a key, or changing it, resets the validated flag — so "Ready" can never reflect a stale key. The validated flag is **persisted** (`ProviderSettings.openAICredentialValidated` / `groqCredentialValidated`) so a validated provider stays ready across launches without re-testing (and so the mandatory gate doesn't re-trap cloud-only users every launch). |
| 9 | Mandatory model + Accessibility | Initial setup now requires **both** a configured model **and** Accessibility access. `AppState.requiresSetup = requiresModelSetup || requiresAccessibilitySetup`; the gate can't be dismissed until both pass. The welcome sheet shows two requirement cards (model download + Accessibility) with green checks, an explanation of *why* Accessibility is needed, and a one-click "Grant Accessibility Access" button. The sheet re-checks permission when the app reactivates (`didBecomeActiveNotification`). |
| 10 | Settings simplification | See "Simplification summary" below. |
| 11 | Models page status layout | Each model row now shows the name on the main line, a small **red/green status dot beneath it** (red = not downloaded, green = downloaded/usable; neutral during transitional states), and the action button on the trailing edge. The "Not Downloaded"/"Loaded" text statuses are gone — the dot and the available action carry the meaning. |
| 12 | Description/metadata cleanup | "WhisperKit" (the engine library) is removed from user-facing text: the section is now "Whisper Models", the per-model caption no longer prints the engine, and weight/language moved into a per-model key/value metadata table (Size, Language, Speed, Accuracy, Best for) styled like the Current Selection rows. The on-device provider now displays as "On-device (Whisper)". |
| 13 | Hidden/duplicate models page | The Models **settings pane** (`SettingsPane.models`, reachable only via Overview) duplicated the Models **screen**, so it was removed entirely. Its one unique control (auto-transcribe) now lives on the Models screen. The duplicate transcription block was also removed from Advanced. Overview's transcription rows now deep-link to the Models screen. Search for "auto-transcribe"/"automation" resolves to the Models screen via `NavigationScreen` tokens. |
| 14 | History status-message audit | Removed the decorative "This item has not been transcribed yet…" banner (the Transcribe button is right there). The summary line is now just status + source (model/provider live in the Details table, not duplicated). Internal engine names ("WhisperKit") are humanized to "On-device (Whisper)" at display, including for legacy stored entries. Actionable banners (missing audio, errors, not-set-up-with-Open-Models) are kept. |
| 15 | Final quality pass | Full package + app product build clean; **72 tests pass, 1 skipped, 0 failures** (up from 67). |

## Simplification summary (#10, #13)

- **Removed the Models settings pane.** It duplicated the Models screen
  (provider/model selection). All of it now lives on the one Models screen; the
  only unique setting (auto-transcribe) was moved there. Sidebar still shows just
  General / Keyboard Shortcut / Advanced.
- **Removed the duplicate transcription block from Advanced.** Advanced no longer
  carries provider/model/automation settings — those have a dedicated home.
- **Removed the cloud "enable" mental model entirely** (already underway): a
  provider is configured by consent + key + test, with no separate enable switch.
- No new pages or settings were added.

## New / updated tests

- `AppStateInsertionFlowTests`: `testCloudProviderNotReadyUntilKeyIsValidated`,
  `testSavingNewKeyResetsValidation`, `testRemovingKeyResetsValidation`,
  `testConsentRequiredBeforeKey`; `makeReadyCloudContext` now marks the key
  validated.
- `CloudProviderErrorRedactionTests`: asserts a 401 whose body echoes the API key
  never leaks the key (or its masked prefix) in the thrown error.
- `SettingsPaneSearchTests`: updated for the removed Models pane; added
  `testAutoTranscribeSearchResolvesToModelsScreen`.

## Honest limitations

- **No screenshots this round.** As in round 8, the automation context has no
  live display surface (full-screen capture is black, per-window capture is
  blocked, and the in-process snapshot can't render the `NavigationSplitView`
  columns). Verified by build + the 72-test suite + code review. Run the app
  (`open dist/Transcriptor.app`) to verify visuals interactively:
  History detail (native sections, Details table, gray "Open in Finder",
  "More…"), cloud provider rows (red/green dot, consent-gated fields, no key in
  errors), Models rows (status dot + metadata table), and the two-step mandatory
  gate.
- **Mandatory Accessibility is a hard gate by design.** A user who can't or won't
  grant Accessibility cannot pass setup. In a non-bundled dev run
  (`swift run`) Accessibility may be ungrantable, which would trap setup — QA
  runs set `suppressSetupGate`, and the release bundle prompts normally. Flag if
  you'd prefer a softer "continue in clipboard-only mode" escape hatch.
- **Cloud readiness now requires a successful Test.** This is stricter (matches
  the brief) — a stored, consented key that has never been tested reads as
  "Not Verified" until the user clicks Test. The result is persisted so it only
  has to happen once per key.
