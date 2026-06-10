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
            List(selection: $appState.selectedScreen) {
                if trimmedSearchText.isEmpty {
                    ForEach(NavigationScreen.allCases) { screen in
                        sidebarRow(for: screen)
                    }
                } else {
                    if !matchingScreens.isEmpty {
                        Section("App") {
                            ForEach(matchingScreens) { screen in
                                sidebarRow(for: screen)
                            }
                        }
                    }

                    if !matchingSettingsPanes.isEmpty {
                        Section("Settings") {
                            ForEach(matchingSettingsPanes) { pane in
                                Button {
                                    appState.openSettings(pane: pane)
                                    sidebarSearchText = ""
                                } label: {
                                    Label {
                                        Text(pane.title)
                                    } icon: {
                                        SidebarIconView(systemImage: pane.sidebarFillSymbol, tint: pane.sidebarTint)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if matchingScreens.isEmpty, matchingSettingsPanes.isEmpty {
                        Text("No results for “\(trimmedSearchText)”")
                            .foregroundStyle(.secondary)
                    }
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
                        systemImage: voiceInputController.isRecording ? "stop.circle.fill" : "mic.circle"
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

    private func sidebarRow(for screen: NavigationScreen) -> some View {
        Label {
            Text(screen.title)
        } icon: {
            SidebarIconView(systemImage: screen.systemImage, tint: screen.sidebarTint)
        }
        .tag(screen)
        .help(screen.title)
    }

    private var trimmedSearchText: String {
        sidebarSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var matchingScreens: [NavigationScreen] {
        NavigationScreen.allCases.filter {
            $0.title.localizedCaseInsensitiveContains(trimmedSearchText)
        }
    }

    private var matchingSettingsPanes: [SettingsPane] {
        SettingsPane.allCases.filter { pane in
            let haystack = ([pane.title, pane.subtitle] + pane.searchTokens).joined(separator: " ")
            return haystack.localizedCaseInsensitiveContains(trimmedSearchText)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch appState.selectedScreen {
        case .overview:
            OverviewView(appState: appState)
        case .history:
            HistoryView(appState: appState)
        case .importAudio:
            ImportAudioView(appState: appState)
        case .models:
            ModelsView(appState: appState)
        }
    }
}

/// System Settings-style colored rounded-square sidebar icon.
struct SidebarIconView: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 21, height: 21)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: 5.5, style: .continuous))
    }
}

extension NavigationScreen {
    var sidebarTint: Color {
        switch self {
        case .overview:
            .blue
        case .history:
            .orange
        case .importAudio:
            .green
        case .models:
            .purple
        }
    }
}

extension SettingsPane {
    var sidebarTint: Color {
        switch self {
        case .general:
            .gray
        case .recording:
            .red
        case .keyboardShortcut:
            .indigo
        case .overlay:
            .cyan
        case .models:
            .purple
        case .storage:
            .gray
        case .cloudProviders:
            .blue
        case .privacy:
            .blue
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
