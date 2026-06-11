import AppKit
import SwiftUI

public struct MainWindowView: View {
    @Bindable private var appState: AppState
    @Bindable private var voiceInputController: VoiceInputController
    @State private var sidebarSearchText = ProcessInfo.processInfo.environment["TRANSCRIPTOR_QA_SEARCH"] ?? ""
    @FocusState private var searchFieldFocused: Bool

    public init(appState: AppState) {
        self.appState = appState
        self.voiceInputController = appState.voiceInputController
    }

    public var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 640, minHeight: 460)
        .navigationSplitViewStyle(.balanced)
        .background(WindowChromeConfigurator())
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
                    ForEach(SettingsPane.allCases) { pane in
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
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 6) {
                Image(systemName: voiceInputController.isRecording ? "mic.fill" : "mic")
                    .foregroundStyle(voiceInputController.isRecording ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))

                Text(voiceInputController.isRecording ? "Recording" : "Ready")
                    .foregroundStyle(.secondary)

                Spacer()

                Text(appState.recordingState.hotkey.displayString)
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                NativeSidebarMaterial(blending: .withinWindow)
                    .ignoresSafeArea()
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 264)
    }

    /// Native System Settings-style search field. Implemented as a real
    /// `TextField` with `@FocusState` (outside the `List`) so it keeps keyboard
    /// focus even as the list content switches to search results — the failure
    /// mode that made `.searchable(placement: .sidebar)` appear non-functional.
    private var sidebarSearchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)

            TextField("Search", text: $sidebarSearchText)
                .textFieldStyle(.plain)
                .focused($searchFieldFocused)
                .onSubmit { searchFieldFocused = true }

            if !trimmedSearchText.isEmpty {
                Button {
                    sidebarSearchText = ""
                    searchFieldFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(.separator.opacity(searchFieldFocused ? 0.0 : 0.4), lineWidth: 0.5)
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background {
            NativeSidebarMaterial(blending: .withinWindow)
                .ignoresSafeArea()
        }
        .contentShape(Rectangle())
        .onTapGesture { searchFieldFocused = true }
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

/// Pins grouped-form content to a native System Settings-style column: a fixed
/// readable width hugging the leading edge instead of being centered with large
/// gaps on both sides when the window is wide.
struct SettingsContentWidth: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: 620, alignment: .leading)
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
                            colors: [Color(white: 0.34), Color(white: 0.22)],
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
