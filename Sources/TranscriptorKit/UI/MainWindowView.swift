import SwiftUI

public struct MainWindowView: View {
    @Bindable private var appState: AppState
    @Bindable private var voiceInputController: VoiceInputController
    @State private var sidebarSearchText = ""

    public init(appState: AppState) {
        self.appState = appState
        self.voiceInputController = appState.voiceInputController
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: $appState.sidebarSelection) {
                if trimmedSearchText.isEmpty {
                    Section {
                        ForEach(NavigationScreen.allCases) { screen in
                            screenRow(for: screen)
                        }
                    }

                    Section("Settings") {
                        ForEach(SettingsPane.allCases) { pane in
                            paneRow(for: pane)
                        }
                    }
                } else {
                    searchResultsContent
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .searchable(text: $sidebarSearchText, placement: .sidebar, prompt: "Search")
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
            .background {
                NativeSidebarMaterial()
                    .ignoresSafeArea()
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 640, minHeight: 460)
        .navigationSplitViewStyle(.balanced)
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
                        systemImage: voiceInputController.isRecording ? "stop.fill" : "mic.fill"
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

    @ViewBuilder
    private var contentView: some View {
        switch appState.sidebarSelection {
        case let .screen(screen):
            switch screen {
            case .overview:
                OverviewView(appState: appState)
            case .history:
                HistoryView(appState: appState)
            case .importAudio:
                ImportAudioView(appState: appState)
            case .models:
                ModelsView(appState: appState)
            }
        case let .settings(pane):
            SettingsPaneDetailView(pane: pane, appState: appState)
        }
    }
}

/// System Settings-style sidebar icon: black rounded-square tile with a thin
/// border and a white glyph.
struct SidebarIconView: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 21, height: 21)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 5.5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
            }
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
