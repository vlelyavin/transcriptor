import AppKit
import SwiftUI

public struct MainWindowView: View {
    @Bindable private var appState: AppState
    @Bindable private var voiceInputController: VoiceInputController
    @State private var sidebarSearchText = ProcessInfo.processInfo.environment["TRANSCRIPTOR_QA_SEARCH"] ?? ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @Environment(\.openWindow) private var openWindow

    public init(appState: AppState) {
        self.appState = appState
        self.voiceInputController = appState.voiceInputController
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(
            minWidth: 640,
            idealWidth: 700,
            maxWidth: 980,
            minHeight: 480,
            idealHeight: 660,
            maxHeight: .infinity
        )
        .navigationSplitViewStyle(.balanced)
        .background(WindowChromeConfigurator())
        .sheet(isPresented: $appState.isPresentingWelcomeGuide) {
            WelcomeGuideView(appState: appState)
        }
        .onAppear {
            let openWindow = openWindow
            appState.openMainWindowAction = { openWindow(id: AppState.mainWindowID) }
            if appState.shouldAutoPresentWelcomeGuide {
                appState.presentWelcomeGuide()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    appState.navigateBack()
                } label: {
                    Label("Back", systemImage: "chevron.backward")
                }
                .disabled(!appState.canNavigateBack)
                .help("Back")

                Button {
                    appState.navigateForward()
                } label: {
                    Label("Forward", systemImage: "chevron.forward")
                }
                .disabled(!appState.canNavigateForward)
                .help("Forward")
            }

            ToolbarItemGroup {
                Button {
                    if voiceInputController.isRecording {
                        voiceInputController.stopFromToolbar()
                    } else {
                        voiceInputController.startFromToolbar()
                    }
                } label: {
                    Label(
                        voiceInputController.isRecording ? "Stop Voice Input" : "Start Voice Input",
                        systemImage: voiceInputController.isRecording ? "stop.circle.fill" : "mic"
                    )
                }
                .disabled(voiceInputController.state == .requestingPermission || voiceInputController.state == .stopping)
                .help(voiceInputController.failureMessage ?? "Use this button or your configured global shortcut to control dictation.")

                Button {
                    appState.openSettings(pane: nil)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Open Settings (Cmd+,)")
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $appState.sidebarSelection) {
            if trimmedSearchText.isEmpty {
                Section {
                    ForEach(NavigationScreen.allCases) { screen in
                        screenRow(for: screen)
                    }
                }

                // No "Settings" label — System Settings groups categories with
                // an extra vertical gap, not a header. A headerless second
                // section gives that native spacing.
                Section {
                    ForEach(SettingsPane.sidebarVisiblePanes) { pane in
                        paneRow(for: pane)
                    }
                }
            } else {
                searchResultsContent
            }
        }
        .listStyle(.sidebar)
        // System Settings rows are 32 pt with the regular sidebar font; the
        // list default (24-28 pt) packs them tighter than the real app.
        .environment(\.defaultMinListRowHeight, 32)
        // Native System Settings keeps a permanent sidebar — there is no
        // collapse control. NavigationSplitView inserts one automatically, so
        // remove it and pin the column to `.all` for the same fixed-sidebar feel.
        .toolbar(removing: .sidebarToggle)
        .safeAreaInset(edge: .top, spacing: 0) {
            sidebarSearchField
        }
        .onChange(of: appState.sidebarSelection) { _, _ in
            // Selecting a search result navigates and clears the query, like
            // System Settings.
            if !trimmedSearchText.isEmpty {
                sidebarSearchText = ""
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 264)
    }

    /// Native System Settings-style search field. Backed by a real
    /// `NSSearchField` (see `NativeSearchField`) so it reliably takes first
    /// responder and routes keystrokes to this app — the previous SwiftUI
    /// `TextField` could leak typing to the previously active application. No
    /// custom background is layered behind it, so it sits on the same sidebar
    /// material as the list (a single unified shade).
    private var sidebarSearchField: some View {
        NativeSearchField(text: $sidebarSearchText, placeholder: "Search")
            // SwiftUI pushes its own controlSize into hosted NSControls, so the
            // AppKit-side .large is overridden unless it is set here too.
            .controlSize(.large)
            .frame(height: 28)
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 6)
    }

    private func screenRow(for screen: NavigationScreen) -> some View {
        Label {
            Text(screen.title)
        } icon: {
            SidebarIconView(systemImage: screen.sidebarSymbol, tint: screen.sidebarTint)
        }
        .tag(SidebarItem.screen(screen))
        .help(screen.title)
    }

    private func paneRow(for pane: SettingsPane) -> some View {
        Label {
            Text(pane.title)
        } icon: {
            SidebarIconView(systemImage: pane.sidebarFillSymbol, tint: pane.sidebarTint)
        }
        .tag(SidebarItem.settings(pane))
        .help(pane.subtitle)
    }

    /// Search results mirror System Settings: the matching pane appears with
    /// its icon, followed by each matching individual setting inside it.
    @ViewBuilder
    private var searchResultsContent: some View {
        if !matchingScreens.isEmpty {
            Section("App") {
                ForEach(matchingScreens) { screen in
                    screenRow(for: screen)
                }
            }
        }

        if !settingsSearchResults.isEmpty {
            Section("Settings") {
                ForEach(settingsSearchResults) { result in
                    paneRow(for: result.pane)

                    ForEach(result.matchedSettingTitles, id: \.self) { settingTitle in
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(settingTitle)
                                Text(result.pane.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(SidebarItem.settings(result.pane))
                    }
                }
            }
        }

        if matchingScreens.isEmpty, settingsSearchResults.isEmpty {
            Text("No results for “\(trimmedSearchText)”")
                .foregroundStyle(.secondary)
        }
    }

    private var trimmedSearchText: String {
        sidebarSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var matchingScreens: [NavigationScreen] {
        NavigationScreen.allCases.filter { $0.matches(query: trimmedSearchText) }
    }

    private var settingsSearchResults: [SettingsSearchResult] {
        SettingsPane.searchResults(matching: trimmedSearchText)
    }

    // MARK: - Detail

    @ViewBuilder
    private var contentView: some View {
        switch appState.sidebarSelection {
        case let .screen(screen):
            switch screen {
            case .overview:
                OverviewView(appState: appState).modifier(SettingsContentWidth())
            case .history:
                HistoryView(appState: appState)
            case .importAudio:
                ImportAudioView(appState: appState).modifier(SettingsContentWidth())
            case .models:
                ModelsView(appState: appState).modifier(SettingsContentWidth())
            }
        case let .settings(pane):
            SettingsPaneDetailView(pane: pane, appState: appState).modifier(SettingsContentWidth())
        }
    }
}

/// A button style for navigation-like list rows. Unlike `.plain` — which dims
/// the entire label while the row is pressed — this keeps the label's foreground
/// colors stable, so only the row background (driven separately by hover) reacts
/// to interaction, matching native System Settings list rows.
struct StableRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
    }
}

/// Stretches page content to the full available detail width instead of capping
/// it to a narrow column with empty side gutters. Grouped `Form` already insets
/// its section cards with native margins, so the only horizontal padding the
/// user sees is the native row spacing — no artificial page-level gutters.
struct SettingsContentWidth: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// Glyph colour for a sidebar tile. Dark-mode values are sampled from macOS
/// System Settings glyphs (Privacy hand, Battery, Touch ID) in Display P3,
/// the space screenshots are taken in; light mode uses the system colours as-is.
struct SidebarIconTint {
    let dark: Color
    let light: Color

    func color(for scheme: ColorScheme) -> Color { scheme == .dark ? dark : light }

    private init(dark: (Double, Double, Double), light: NSColor) {
        self.dark = Color(.displayP3, red: dark.0 / 255, green: dark.1 / 255, blue: dark.2 / 255)
        self.light = Color(nsColor: light)
    }

    static let blue = SidebarIconTint(dark: (63, 140, 236), light: .systemBlue)
    static let indigo = SidebarIconTint(dark: (120, 118, 240), light: .systemIndigo)
    static let green = SidebarIconTint(dark: (98, 200, 98), light: .systemGreen)
    static let purple = SidebarIconTint(dark: (165, 96, 235), light: .systemPurple)
    static let red = SidebarIconTint(dark: (226, 72, 94), light: .systemRed)
    static let cyan = SidebarIconTint(dark: (102, 188, 240), light: .systemCyan)
    /// Utility panes use Apple's grey glyph (General, Keyboard, Menu Bar).
    static let neutral = SidebarIconTint(dark: (186, 186, 192), light: .systemGray)
}

/// A System Settings-style icon: a dark glass squircle with a coloured glyph.
///
/// Measured from System Settings on a Retina capture: 20 pt tile, a vertical
/// fill gradient (~12% → 6% white in dark mode), a 0.5 pt highlight on the top
/// edge only (sides stay soft), a wide soft shadow, and a filled semibold glyph
/// (line glyphs read washed-out at this size).
struct SidebarIconView: View {
    let systemImage: String
    var tint: SidebarIconTint = .neutral
    var size: CGFloat = 20
    /// When true, the glyph animates with a native variable-color symbol effect
    /// (used by the recording overlay's "listening" state).
    var animated: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    /// Glyph box as a share of the tile; System Settings leaves ~0.17 padding.
    private let glyphRatio: CGFloat = 0.64

    var body: some View {
        let tile = RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
        // Resizable + fixed box: a sidebar `List` scales label symbols up ~1.4x
        // through its environment, which pushed glyphs to the tile edge.
        Image(systemName: systemImage)
            .resizable()
            .scaledToFit()
            .fontWeight(.semibold)
            .frame(width: size * glyphRatio, height: size * glyphRatio)
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(tint.color(for: colorScheme).gradient)
            .symbolEffect(.variableColor.iterative, isActive: animated)
            .frame(width: size, height: size)
            .background {
                tile
                    .fill(LinearGradient(
                        colors: isDark
                            ? [Color(white: 0.125), Color(white: 0.06)]
                            : [Color(white: 1.0), Color(white: 0.93)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .overlay {
                        tile.strokeBorder(
                            LinearGradient(
                                stops: isDark
                                    ? [.init(color: .white.opacity(0.22), location: 0),
                                       .init(color: .white.opacity(0), location: 0.35)]
                                    : [.init(color: .black.opacity(0.04), location: 0),
                                       .init(color: .black.opacity(0.10), location: 1)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                    }
                    .shadow(color: .black.opacity(isDark ? 0.45 : 0.15), radius: size * 0.09, y: size * 0.03)
            }
    }
}

/// Reaches the hosting `NSWindow` to remove the titlebar separator line so the
/// toolbar blends into the content like System Settings.
private struct WindowChromeConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        window?.titlebarSeparatorStyle = .none
    }
}

extension NavigationScreen {
    var sidebarSymbol: String {
        switch self {
        case .overview:
            "waveform"
        case .history:
            "clock.fill"
        case .importAudio:
            "square.and.arrow.down.fill"
        case .models:
            "cpu.fill"
        }
    }

    var sidebarTint: SidebarIconTint {
        switch self {
        case .overview:
            .blue
        case .history:
            .blue
        case .importAudio:
            .green
        case .models:
            .purple
        }
    }
}

extension SettingsPane {
    var sidebarTint: SidebarIconTint {
        switch self {
        case .general:
            .neutral
        case .recording:
            .red
        case .keyboardShortcut:
            .neutral
        case .overlay:
            .neutral
        case .storage:
            .cyan
        case .privacy:
            .blue
        case .advanced:
            .neutral
        }
    }

    var sidebarFillSymbol: String {
        switch self {
        case .general:
            "gearshape.fill"
        case .recording:
            "mic.fill"
        case .keyboardShortcut:
            "keyboard.fill"
        case .overlay:
            "rectangle.inset.filled"
        case .storage:
            "internaldrive.fill"
        case .privacy:
            "hand.raised.fill"
        case .advanced:
            "slider.horizontal.3"
        }
    }
}

#if DEBUG
struct MainWindowView_Previews: PreviewProvider {
    static var previews: some View {
        MainWindowView(appState: .preview)
            .frame(width: 1320, height: 840)
    }
}
#endif
