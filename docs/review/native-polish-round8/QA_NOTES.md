# Native Polish QA Notes — Round 8 (consolidation + mandatory setup)

Date: June 13, 2026

Round 8 simplifies navigation (fewer pages), removes artificial page padding,
and makes downloading a transcription model a mandatory first-run step.

## Changes by brief item

| # | Item | Implementation |
|---|------|----------------|
| 1 | Move OpenAI/Groq config to the Models page; blue "API Key Needed" | Cloud provider configuration (status, model ID, send-audio consent, API key field, Save/Remove/Test/Reset, and Select) now renders inline on the **Models** screen (`ModelsView.cloudProviderSection`). The separate **Cloud Providers** settings pane was deleted entirely (`SettingsPane.cloudProviders` removed). The `API Key Needed` / `Privacy Consent Needed` status indicator and its dot are painted in the system **accent blue** (`Color.accentColor`), which stays legible in Light and Dark Mode. |
| 2 | Remove page-level horizontal padding | `SettingsContentWidth` no longer caps content at 620 pt — every page (`Overview`, `Import Audio`, `Models`, all Settings panes) stretches to the full detail width. The only remaining horizontal spacing is the grouped `Form`'s native section insets. Removed the now-dead `sidebarCollapsed` environment plumbing. |
| 3 | Import Audio text cleanup | Removed the "Telegram voice messages export…" line from the Import Details section. |
| 4 | Navigation row press styling | Added `StableRowButtonStyle` (keeps label foreground colors stable on press, unlike `.plain` which dimmed the text). Applied to Overview navigation rows and the Import Audio recent-import rows (the latter promoted to a `RecentImportRow` view with hover tint). Background lightens on hover via `.listRowBackground`; the chevron is indicator-only; the whole row is the click target. |
| 5 | Overview icon styling | The Overview hero glyph now uses the same beveled dark-tile treatment as the sidebar icons (dark top-to-bottom gradient + soft top highlight + drop shadow), scaled up, instead of the disconnected accent-blue squircle. |
| 6 | Simplification audit | See "Simplification summary" below. |
| 7 | Mandatory model download on first launch | The welcome sheet is now a **mandatory gate** (`WelcomeGuideView`). It cannot be dismissed (no Skip; `interactiveDismissDisabled`) until `isTranscriptionConfigured` is true. It surfaces the catalog's **recommended** model with a one-click **Download Model** button, shows live download progress in-flow, and **auto-selects** the model once it finishes (`finishModelSetupIfReady`, driven by `onChange(of: readyLocalModelIDs)`). The gate auto-presents on every launch while setup is still required (`shouldAutoPresentWelcomeGuide == requiresModelSetup`). |
| 8 | Final quality pass | Build clean; 66 tests pass (1 skipped). Cloud config only on Models; no separate remote-provider page; accent-blue indicator; full-width pages; generic Import text; stable row press; sidebar-style Overview icon; mandatory gate; no dangling navigation (search for "openai"/"groq"/"cloud"/"api key" now resolves to the Models screen via `NavigationScreen.searchTokens`). |

## Simplification summary (#6)

- **Removed the Cloud Providers settings page.** All cloud provider setup now
  lives on the Models page, so local and cloud transcription are configured in
  one place. This eliminates one navigation destination and the OpenAI/Groq
  enable-then-configure mental model.
- **Search still finds cloud setup.** `NavigationScreen.models` gained search
  tokens (`openai`, `groq`, `cloud`, `api key`, `provider`, `download`), so
  sidebar search routes those queries straight to Models instead of a dead
  settings pane.
- **No new pages or settings were added.** The remaining non-essential panes
  (Recording, Overlay, Storage, Models settings, Privacy) stay consolidated
  under **Advanced** and reachable via Overview deep links + search, as in prior
  rounds — the sidebar still shows only General, Keyboard Shortcut, and Advanced.

## Verification

- `swift build` (full package) and `swift build --product Transcriptor`: clean.
- `swift test`: **66 passing, 1 skipped, 0 failures**, including 4 new gating
  tests in `AppStateInsertionFlowTests`:
  - `testSetupGateRequiredWhenNothingConfigured`
  - `testSetupGateCannotBeDismissedUntilConfigured`
  - `testSetupGateDismissesOnceProviderIsReady`
  - `testSuppressSetupGateBlocksAutoPresentForQA`
- Updated `SettingsPaneSearchTests` for the removed pane (cloud search now
  resolves to the Models screen).

## Honest limitations

- **No screenshots this round.** The automation context had no live display
  surface — full-screen `screencapture` returned all-black, per-window/region
  capture was blocked, and the in-process snapshot path renders the toolbar but
  not the `NavigationSplitView` columns. Changes were verified by build, the
  test suite (including the new gating tests), and code review instead. Re-run
  the round-6/7 on-screen capture harness on an interactive session to refresh
  visuals.
- **Mandatory setup can trap an offline first-run user.** By design (per the
  brief) there is no Skip; a failed download shows **Retry Download**. A user
  with no network on first launch cannot proceed until a model downloads. Flag
  if you want an explicit escape hatch (e.g. "set up later" that still blocks
  transcription actions).
- **Recommended model size.** The first-run model is the catalog's
  `Recommended`-flagged WhisperKit model (Large V3 Turbo, ~632 MB) for quality.
  If you'd prefer the fastest path, point `recommendedSetupModel` at Tiny
  (~66 MB) or Base (English) (~105 MB).
- **Hover/press feedback** on rows can't be shown statically; verify
  interactively that row text stays stable and only the background tints.
