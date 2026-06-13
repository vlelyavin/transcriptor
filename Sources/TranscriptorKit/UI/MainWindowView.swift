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

/// System Settings-style sidebar icon: a dark beveled tile with a white glyph.
/// The tile is a subtle top-to-bottom gradient (not pure black) and the border
/// is a soft top highlight rather than a hard stroke, matching macOS.
struct SidebarIconView: View {
    let systemImage: String
    var size: CGFloat = 20
    /// When true, the glyph animates with a native variable-color symbol effect
    /// (used by the recording overlay's "listening" state).
    var animated: Bool = false

    private var cornerRadius: CGFloat { size * 0.26 }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.55, weight: .medium))
            .foregroundStyle(.white)
            .symbolEffect(.variableColor.iterative, isActive: animated)
            .frame(width: size, height: size)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.28), Color(white: 0.16)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
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
