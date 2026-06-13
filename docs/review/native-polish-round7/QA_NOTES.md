# Native Polish QA Notes — Round 7 (native Settings parity)

Date: June 13, 2026

Round 7 is a broad consistency pass toward native macOS System Settings parity.
References: `docs/reference/reference_v5/` (`radio_style.png`,
`history_storage_limit.png`, `overview.png`, `native_overview.png`,
`history_item.png`, `native_settings_search.png`).

## Root causes and fixes

| # | Issue (reported) | Fix |
|---|---|---|
| 1 | History storage limit had no direct numeric entry | `storageSections` now renders `LabeledContent("History storage limit")` with a trailing `TextField` (numeric `format: .number`), an "MB" suffix, and a `Stepper`. A clamped binding enforces **20 MB … 2 048 MB (2 GB)** for both typed and stepped input. Matches `history_storage_limit.png`. |
| 2 | Radio buttons not native / inconsistent | The only literal radio group is "Preferred Transcription Provider". Replaced the SF-Symbol circle with a hand-drawn `RadioIndicator` matching the native control (bordered well off; accent disc + white center on). Kept per-row disabling + subtitles (which `Picker(.radioGroup)` can't express). Aligned the glyph to the first text baseline; tightened spacing and font to match nearby rows. |
| 3 | "Set Up Transcription" notice felt custom | Replaced the accent-tinted card with a standard grouped `LabeledContent` row (icon + title + secondary description + prominent `Set Up…` button), so it reads as a native Settings setup recommendation row. |
| 4 | Overview rows only navigated via the chevron | Introduced `OverviewNavigationRow`: the whole row is a `.plain` `Button`, highlights on hover via `.listRowBackground`, and the chevron is now a visual indicator only. |
| 5 | Label/description layout (descriptions split from their control by dividers) | Converted section-level explanatory captions to native Section **footers** (Transcript Insertion, Application, Microphone & Audio, Overlay, Local Provider, Default Local Model, Automation). Per-control descriptions (Save original audio, cloud Status, Send-audio consent, API Key status) now live inside the control's label as a stacked secondary line — one row, no divider. |
| 6 | OpenAI/Groq required a separate enable switch | Removed the "Enable <provider>" toggle. `providerRuntimeState` now derives availability purely from **API key present AND privacy consent** — a provider becomes usable exactly when both are satisfied, never before. Restyled the section: a Status row with a colored state dot, a "Send audio to <provider>" consent toggle with description, and an API-Key field whose label shows the Keychain status. |
| 7 | Single global "Reset Cloud Provider Defaults" | Removed it. Each provider now has its own **Reset** as a 4th action button (Save / Remove / Test / Reset). `AppState.resetCloudProvider(_:)` clears only that provider's key, consent, and model. |
| 8 | Empty gray gutter on the right of Overview when wide | `SettingsContentWidth` now **centers** the capped content column when the window is wider than the content, splitting extra width into balanced gutters (native) instead of one blank right strip. When the sidebar is collapsed the cap is still lifted (round 6) so content fills the window. |
| 9 | Icon styling | Reviewed against `native_overview.png`. The Overview hero is the app glyph in an accent squircle (native app-icon proportions); value rows are intentionally icon-less, matching native Settings value rows (leading icons are a top-level-category convention, not a value-row one). Sidebar tiles unchanged (System-Settings-style). Light touch — see limitations. |
| 10 | Search field styling / focus | Already a real bridged `NSSearchField` (`NativeSearchField`) — native rounded shape, magnifier, placeholder, focus ring. The "typing goes to the previous app" bug is fixed by the round-6 activation-policy promotion (launch the packaged app). Margins kept at the System-Settings inset. |
| 11 | History breadcrumbs + unavailable transcription path | No breadcrumb *trail* exists; the only back affordance is the compact master→detail back button, which is required for navigation in narrow windows (and disappears in the wide split layout). Restyled/kept. The unavailable state already (round 6) shows an **Open Models** button + a "Set Up Transcription…" context-menu item. |
| 12 | History section typography | `Transcript` / `Details` / `Transcript Versions` use the small, semibold, secondary section-header style matching the other pages (round 6, verified). |
| 13 | Audio file section | The two raw-path rows are one **Audio** row with a **View in Finder** button (round 6, verified). |

## Verification

- `swift build --product Transcriptor`: clean. `swift test`: **61 passing, 1 skipped, 0 failures**.
- Real on-screen `screencapture -l<windowid>` evidence in this folder:
  - `advanced-dark` — native radios (WhisperKit off / Parakeet selected; OpenAI/Groq disabled with reason), all descriptions as footers, storage numeric control.
  - `cloud-light` / `cloud-dark` — no enable switch; Status dot + label; consent toggle; API-Key status; Save/Remove/Test/**Reset** per provider.
  - `storage-dark` — numeric `History storage limit` field + MB + stepper (20…2048).
  - `overview-light` / `overview-dark` — native setup row; full-width navigation rows with chevron indicators.
  - `general-light` — grouped footers for accessibility and launch-at-login notes.
  - `history-detail-light` — small section headers, combined Audio + View in Finder, Open Models CTA.
- Dark/light captures use the QA appearance override, confirming no surface is hard-coded to one appearance.

## Honest limitations

- **Hover highlight** on Overview rows and **full-row click navigation** can't be
  shown in a static screenshot; verify interactively (hovering a row tints it;
  clicking anywhere on the row — not just the chevron — navigates).
- **Search keystroke routing** still requires the packaged app (`open
  dist/Transcriptor.app`), not `swift run`, per round 6.
- **Compact History back button** is kept by design: in the default-width window
  History is compact (detail < 980 pt), so a back control is needed. It is a
  single back button, not a breadcrumb trail, and it is absent in the wide split
  layout. If you want it gone entirely, widen the window or we can lower the
  split threshold in a follow-up.
- **Icons (#9)** were a light touch — the hero and sidebar tiles already track
  native conventions; no per-row icons were added because native value rows
  don't use them. Flag if you want category-style colored row icons.
