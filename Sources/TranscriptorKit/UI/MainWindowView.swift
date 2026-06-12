import AppKit
import SwiftUI

public struct MainWindowView: View {
    @Bindable private var appState: AppState
    @Bindable private var voiceInputController: VoiceInputController
    @State private var sidebarSearchText = ProcessInfo.processInfo.environment["TRANSCRIPTOR_QA_SEARCH"] ?? ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

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
                // When the sidebar is collapsed the detail content fills the full
                // window width instead of leaving a blank gray gutter on the right.
                .environment(\.sidebarCollapsed, columnVisibility == .detailOnly)
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
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 6)
    }

    private func screenRow(for screen: NavigationScreen) -> some View {
        Label {
            Text(screen.title)
        } icon: {
            SidebarIconView(systemImage: screen.systemImage)
        }
        .tag(SidebarItem.screen(screen))
        .help(screen.title)
    }

    private func paneRow(for pane: SettingsPane) -> some View {
        Label {
            Text(pane.title)
        } icon: {
            SidebarIconView(systemImage: pane.sidebarFillSymbol)
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
        NavigationScreen.allCases.filter {
            $0.title.localizedCaseInsensitiveContains(trimmedSearchText)
        }
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

/// Environment flag set by `MainWindowView` when the split-view sidebar is
/// collapsed, so leading-aligned content can expand to fill the freed width.
private struct SidebarCollapsedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var sidebarCollapsed: Bool {
        get { self[SidebarCollapsedKey.self] }
        set { self[SidebarCollapsedKey.self] = newValue }
    }
}

/// Pins grouped-form content to a native System Settings-style column: a fixed
/// readable width hugging the leading edge instead of being centered with large
/// gaps on both sides when the window is wide. When the sidebar is collapsed the
/// cap is lifted so the content stretches across the whole window (matching
/// `white_collapsed.png`), leaving no empty gutter on the right.
struct SettingsContentWidth: ViewModifier {
    @Environment(\.sidebarCollapsed) private var sidebarCollapsed

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: sidebarCollapsed ? .infinity : 620, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// System Settings-style sidebar icon: a dark beveled tile with a white glyph.
/// The tile is a subtle top-to-bottom gradient (not pure black) and the border
/// is a soft top highlight rather than a hard stroke, matching macOS.
struct SidebarIconView: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.28), Color(white: 0.16)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: .black.opacity(0.18), radius: 0.5, y: 0.5)
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

extension SettingsPane {
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
        case .models:
            "cpu.fill"
        case .storage:
            "internaldrive.fill"
        case .cloudProviders:
            "cloud.fill"
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
