# Native macOS Review — Round 2 (Hostile)

Date: June 10, 2026
References analyzed: `docs/reference/macos-native/` (System Settings dark mode:
VPN/Battery/About/Wallpaper panes; Finder list view; Mail three-pane).
Current state analyzed: `docs/reference/current/` (six screenshots of the app
as built on `claude/native-macos-hostile-polish`).

Verdict: the round-1 pass removed marketing chrome but the result is still a
flat, gray, single-tone window that nobody would mistake for an Apple app. The
gaps below are ranked by how loudly they scream "not native".

## What the native references actually do

1. **Sidebar is a different surface than content.** In System Settings dark
   mode the sidebar is a translucent, near-black desktop-tinted material; the
   content pane is a lighter elevated gray. The boundary is obvious without a
   divider. Finder and Mail do the same.
2. **Sidebar rows have colorful icons.** Every System Settings row has a
   filled, rounded-square colored container (blue, green, purple, gray) with a
   white SF Symbol glyph. Finder uses tinted symbols. Color is how Apple makes
   a sidebar feel rich; text-plus-thin-outline-glyph is what ours does.
3. **Search lives at the top of the sidebar** (System Settings) or in the
   toolbar's right side (Finder, Mail). It is always visible, always works.
4. **Back/forward chevrons sit at the top-left of the detail pane.** System
   Settings and Finder both ship history navigation. Ours has none.
5. **Content is inset, rounded, elevated groups** with generous row height —
   not full-width hairline-separated tables. The window background is darker
   than the group cards, giving depth.
6. **Settings are never a sidebar destination inside the main window.** Apps
   put preferences in a separate window (Cmd+,). Our Settings screen nests a
   second sidebar inside the detail pane — a structure no Apple app uses.

## Gaps in the current build (from `docs/reference/current/`)

| # | Current behavior | Native expectation |
|---|---|---|
| 1 | Sidebar and content are the same flat dark gray; sidebar even reads *lighter* than content | Translucent darker sidebar, elevated content groups |
| 2 | Monochrome outline glyphs in sidebar | Colored rounded-square icon containers |
| 3 | No search anywhere in the shell; History/Settings search fields are inconsistent and settings search filters nothing | Sidebar search (System Settings pattern) that works |
| 4 | No back/forward buttons | Chevron history navigation in the toolbar |
| 5 | Window reported as not resizable by the user | Standard resizable window with sane minimum |
| 6 | Settings is a third-level sidebar inside the main window; Save/Remove/Test buttons render disabled with no explanation; search dead | Separate Settings window (Cmd+, and gear), grouped panes, controls that are enabled or explain why not |
| 7 | Overview/Models rows are full-width flat tables | Inset rounded grouped sections |
| 8 | `.webm` advertised as a known-unsupported format row | Don't advertise what you can't do; support what users actually drop (Telegram `.ogg`) |

## Decisions for this pass

- **Settings moves to its own window** via the SwiftUI `Settings` scene:
  gear button and Cmd+, open it. Layout mirrors System Settings: searchable
  category sidebar with colored icons + grouped detail form. Settings leaves
  the main-window sidebar entirely.
- **Sidebar**: System Settings-style search field pinned at top, colored
  icon containers per row, real `.sidebar` material contrast against an
  elevated detail surface.
- **Back/forward navigation** over visited screens, top-left toolbar.
- **OGG support**: CoreAudio on current macOS decodes Ogg-Opus and Ogg-Vorbis
  natively (verified with `AVAudioFile` against real files). Imports accept
  `.ogg`/`.oga`/`.opus` (Telegram voice messages) and are transcoded to WAV
  working copies so every provider consumes them identically. All `.webm`
  special-casing is deleted; unknown extensions get the generic honest error.
- **Every page** re-checked against the references at the end of the pass with
  fresh screenshots before claiming completion.
