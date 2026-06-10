# Hostile Native macOS Review — Transcriptor

Date: June 10, 2026
Branch reviewed: `codex/native-ui-adaptive-parakeet-autoinsert` at `ed0a334`
Reviewer stance: hostile to the implementation, not the product.

Credit where due: the structural work landed. The app uses `NavigationSplitView`,
settings live in the main window, History collapses at narrow widths, Parakeet has a
real FluidAudio Core ML backend, and the insertion service handles permission, secure
field, and focus-loss fallbacks. That is why the review below is about why the app
*still* does not read as Apple-built — the remaining problems are mostly self-invented
chrome layered on top of correct structure.

## 1. What still does not feel native

1. **The sidebar opens with a brand card.** `SidebarHeaderView` puts an icon tile,
   an app-name headline, and a "Free local speech to text" tagline at the top of the
   sidebar. No Apple app does this. Mail, System Settings, Notes: the sidebar starts
   with content. The window title and the About box carry the brand. This single view
   sets the "third-party dashboard" tone before anything else renders.
2. **Settings nests a `NavigationSplitView` inside the detail pane of another
   `NavigationSplitView`.** That produces a second sidebar with its own column
   behavior, double material edges, and broken toolbar semantics. System Settings is
   one sidebar + one detail. In-app settings here should be a flat two-pane layout
   (fixed-width category `List` + detail), not a split view inside a split view.
3. **Custom search header in Settings.** A rounded `TextField` stacked above a
   "Settings" headline inside the category column is invented chrome. Native pattern
   is `.searchable` — or, for eight categories, no search at all.
4. **`largeTitle` heroes on utility screens.** Settings panes, Import Audio, and
   Models all open with `.largeTitle` headings plus a marketing-style subtitle
   sentence. System Settings uses the window title plus plain section headers.
   Utility screens should not shout.
5. **Capsule chips everywhere.** History detail renders status/source/model/provider
   as four custom capsules; Models and Cloud Providers render colored capsule status
   badges; Import renders format chips and a monospaced "Cmd + Shift + I" badge
   pill. Native macOS communicates this with secondary text and the occasional
   restrained status string. The chips are the single biggest remaining "designed by
   a coding agent" tell.
6. **`SectionCard` is still the page skeleton** for History detail, Import Audio, and
   Models: floating headline + sentence + `GroupBox`. Repeated three times per page it
   reads as a web dashboard. Native equivalent is a grouped `Form`/`List` with plain
   section headers.
7. **The overlay waveform uses five-color gradients** (red→pink, orange→yellow,
   blue→mint) and a 430 pt panel. Apple's dictation indicator is compact and uses one
   accent. The gradients plus the hint capsule ("Toggle to Talk") read as a demo
   widget, not system UI.
8. **Redundant in-content titles.** History draws its own "History" `title2` header
   inside the content even though the toolbar already shows the navigation title.
   Same disease as the hero titles.
9. **Import Audio is still a two-column brochure** at wide sizes: drop zone on the
   left, three stacked "fact" cards (Supported Formats / Storage / Automation) on the
   right. A native utility would be one column: drop area, one grouped info section,
   recent imports list.

## 2. Screens that fail or degrade at compressed widths

- `MainWindowView` forces `minWidth: 800`. Acceptable, but the brief targets 780–820;
  780 works once the panes below stop assuming width.
- `HistoryView` switches modes at 980 px, but in wide mode the `HSplitView` detail
  pane has `minWidth: 360` and the action bar is a single `HStack` of six buttons —
  at ~1000 px total the buttons collide before `ViewThatFits` flips to the vertical
  variant, leaving a stacked column of full-width buttons that looks broken rather
  than adaptive. Secondary actions belong in a `Menu`.
- `ImportAudioView` two-column layout holds until 930 px and then dumps three cards
  below a 260 pt drop zone — the page becomes a long scroll of cards.
- `SettingsView` wide mode (nested split view) wastes a full second toolbar/column
  divider; compact mode works but the back link ("All Settings") is a `.link`-style
  button instead of native back navigation chrome.

## 3. Custom styling to delete rather than polish

| Item | File | Verdict |
| --- | --- | --- |
| Brand header card | `UI/SidebarHeaderView.swift` | Delete; sidebar starts with the list |
| `SectionCard` headline+subtitle+GroupBox | `UI/SectionCard.swift` | Replace usages with grouped `Form`/`List` sections; delete the component |
| Capsule `detailTag` chips | `History/HistoryView.swift` | Delete; secondary text line |
| Format chips, shortcut badge pill | `ImportExport/ImportAudioView.swift` | Delete; plain footnote text |
| Colored capsule state badges | `Models/ModelsView.swift`, `Settings/SettingsView.swift` | Replace with plain secondary text; color only for true error/warning |
| Waveform gradients | `Overlay/RecordingOverlayView.swift` | One color per state, no gradients |
| Custom settings search header | `Settings/SettingsView.swift` | Delete |
| `largeTitle` + subtitle heroes | Settings/Import/Models views | Delete; rely on navigation title and section headers |

## 4. Files causing the non-native look

- `Sources/TranscriptorKit/UI/SidebarHeaderView.swift` — brand card.
- `Sources/TranscriptorKit/UI/SectionCard.swift` — dashboard card primitive used by
  History, Import, Models.
- `Sources/TranscriptorKit/Settings/SettingsView.swift` — nested split view, custom
  search header, `largeTitle` pane headers, capsule provider badges.
- `Sources/TranscriptorKit/History/HistoryView.swift` — chips, in-content title,
  card-based detail, six-button action row.
- `Sources/TranscriptorKit/ImportExport/ImportAudioView.swift` — hero title, fact
  cards, chips, badge pill, two-column brochure layout.
- `Sources/TranscriptorKit/Models/ModelsView.swift` — hero title, cards, colored
  capsules, stat grid that mimics a pricing table.
- `Sources/TranscriptorKit/Overlay/RecordingOverlayView.swift` — gradients, oversized
  panel, hint capsule.

## 5. Target native pattern per screen

- **Sidebar**: `List(.sidebar)` only, native selection, compact status footer.
  Material via `NSVisualEffectView .sidebar` (already present — keep).
- **Overview**: grouped `Form`/`List` of `LabeledContent` rows (already close; keep,
  align row wording).
- **Settings**: flat adaptive two-pane — fixed-width category `List` + grouped
  `Form` detail; single column with back navigation under ~700 px of pane width;
  pane header at `title2` weight max. Provider config stays `DisclosureGroup` inside
  a grouped Form, with `LabeledContent`, `SecureField`, plain status text.
- **History**: wide = list + detail two-pane; narrow = list, push-style detail.
  Rows: preview (body), one secondary metadata line. Detail: title (headline size),
  metadata line, transcript as the dominant grouped section, paths inside
  `DisclosureGroup`, secondary actions in a `Menu`.
- **Import Audio**: single column — restrained dashed drop area on system material,
  one `Choose Files…` button, grouped section for formats/storage (with `.webm`
  honestly marked unsupported), grouped recent-imports list.
- **Models**: grouped `Form`/`List`, one row per model with name, secondary spec
  line, trailing action button; details in `DisclosureGroup`; status as plain text,
  color only for failure.
- **Overlay**: compact (~340 pt) rounded panel, `.ultraThickMaterial`, single-tint
  level bars, clear state titles, `Done`/`Cancel` only in toggle mode,
  "Release the shortcut to finish" in hold mode. Background dimming stays subtle.

## 6. Prioritized fix plan

1. Shell: delete brand header, compact sidebar footer, `minWidth` 780.
2. Settings: replace nested split view with flat adaptive two-pane; remove search
   header and hero titles; calm provider badges.
3. History: remove in-content title and chips; native rows; `Menu` for secondary
   actions; grouped detail with transcript first and paths in a disclosure.
4. Import Audio: single-column utility layout; remove hero, chips, badge, fact cards.
5. Models: grouped rows, disclosure details, plain status text.
6. Overlay: shrink panel, drop gradients, keep state machine.
7. Delete `SectionCard` once no screen uses it.
8. Re-verify insertion tests cover: auto-transcribe queued when insertion enabled,
   completion triggers insertion, permission/secure-field/target-unavailable
   fallbacks.
9. Parakeet: backend is real (FluidAudio 0.15.2, Core ML, Apple Silicon). Keep both
   models presented as Beta with explicit Apple Silicon requirement and honest
   download sizes; no fake "Very Fast/Best" pricing-table claims without caveats.

## 7. Reference screenshots used

Native targets (`docs/reference/macos-native/`):
- `2026-06-09_10-21-57.png`, `2026-06-09_10-22-03.png`, `2026-06-09_10-22-10.png`,
  `2026-06-09_10-22-17.png` — System Settings: General, About, Accessibility,
  Appearance (sidebar density, grouped rows, header scale).
- `Screenshot 2026-06-09 at 11.00.10.png` … `11.01.25.png` — System Settings:
  Wallpaper, Spotlight, Sound, Screen Time, Lock Screen (grouped forms, restrained
  controls, back/forward detail navigation).
- `Screenshot 2026-06-10 at 03.02.52.png` — Mail (native dark translucent sidebar,
  list density, toolbar restraint).
- `Screenshot 2026-06-10 at 03.03.03.png` … `03.03.15.png` — System Settings:
  Wallpaper, Spotlight, Menu Bar, Sound, Lock Screen (current-OS grouped row style).

Anti-patterns (`docs/reference/`):
- `history.png`, `import-audio.png`, `models-whisper.png`,
  `models-cloud-parakeet.png` — marketing-style card/hero layouts that the app must
  not resemble.
