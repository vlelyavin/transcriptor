# Native Polish QA Notes — Round 4 (native styling fidelity)

Date: June 11, 2026

Round 4 addresses the second hostile review: backgrounds, icon tiles, the
toolbar separator, content gaps, sidebar grouping, and the still-broken sidebar
search. References used: `docs/reference/reference_v2/` (`native-settings.png`,
`native_gap.png`) plus the existing `docs/reference/macos-native/` set.

## Root causes and fixes

| Issue (reported) | Root cause | Fix |
|---|---|---|
| Sidebar reads gray/lighter, content darker (inconsistent) | Round-3 forced a black scrim over a `.behindWindow` sidebar material, so the sidebar picked up the desktop wallpaper and the scrim flattened it to gray while the content stayed opaque dark | Removed the custom scrim and `.scrollContentBackground(.hidden)`; the List now renders the genuine native `.sidebar` vibrancy. `HistoryView` no longer overrides with `underPageBackgroundColor`. Sidebar and content now match System Settings. |
| Icon tiles: pure black with a hard solid border | `SidebarIconView` used `Color.black` + a uniform `strokeBorder` | Tiles are now a subtle dark **gradient** (`white 0.34 → 0.22`, not pure black) with a soft top-edge highlight border (gradient stroke `white 0.22 → 0.04`) and a 0.5pt drop shadow — the macOS bevel, not a hard outline. |
| Toolbar has a useless separator line on top | `NSWindow.titlebarSeparatorStyle` defaulted to `.automatic` | A `WindowChromeConfigurator` (`NSViewRepresentable`) sets `titlebarSeparatorStyle = .none`, so the toolbar blends into content like System Settings. |
| Strange gap on both sides of content | `.formStyle(.grouped)` caps content width (~570pt) and **centers** it, producing large symmetric gaps on wide windows | New `SettingsContentWidth` modifier pins form content to a fixed 620pt column hugging the leading edge (empty space accrues on the right only). Applied to Overview, Import, Models, and every settings pane; History stays full width. |
| Extra "Settings" label in the sidebar | An explicit `Section("Settings")` header | Replaced with a headerless second `Section`, so the two groups are separated by the native inter-group vertical gap (no label), like System Settings categories. |
| **Sidebar search still doesn't work** | `.searchable(placement: .sidebar)` was attached to the `List` whose section structure changes when the query becomes non-empty. SwiftUI drops the field's first-responder focus when the searchable list rebuilds, so keystrokes never accumulate — the field looks present but typing does nothing. The result-building **logic was correct** (verified by injecting a query: see `after2-search-auto.png`). | Replaced `.searchable` with a real `TextField` + `@FocusState` placed in the List's **top safe-area inset (outside the List)**. A field outside the structure-changing List cannot lose focus when results render. Live binding filters as you type; selecting a result navigates and clears the query (`onChange` of the selection). |

## Verification

- `swift test`: 57 passed, 1 skipped, 0 failures.
- `swift build --product Transcriptor`: clean.
- Real `screencapture -l` screenshots (this folder), dark + light:
  - `before-*` vs `after2-*` / `audit-*` show each fix.
  - Every screen: Overview, History (compact + `audit-history-wide-dark`), Import,
    Models, and all eight settings panes (General, Recording, Keyboard Shortcut,
    Overlay, Models, Storage, Cloud Providers, Privacy).
  - `after2-search-auto.png` — search filters to the matching panes **and** the
    underlying individual settings (e.g. "auto" → Models / Auto-transcribe and
    Storage / Auto-delete oldest history).

## Honest limitation

- Typing into the search field could not be exercised by automation: synthetic
  keystrokes/clicks require Accessibility permission, which is not granted to the
  test harness (`System Events` returns `-25200` for `click at`). The fix uses
  the canonical `TextField` + `@FocusState` pattern and the result rendering is
  verified by query injection (`TRANSCRIPTOR_QA_SEARCH`), but a human should
  click the field and type once to confirm end-to-end.
