import SwiftUI

public struct MainWindowView: View {
    @Environment(\.openSettings) private var openSettings
    @Bindable private var appState: AppState
    @Bindable private var voiceInputController: VoiceInputController

    public init(appState: AppState) {
        self.appState = appState
        self.voiceInputController = appState.voiceInputController
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: $appState.selectedScreen) {
                Section {
                    ForEach(NavigationScreen.allCases) { screen in
                        Label(screen.title, systemImage: screen.systemImage)
                            .tag(screen)
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                SidebarHeaderView()
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            contentView
        }
        .frame(minWidth: 960, minHeight: 640)
        .navigationSplitViewStyle(.balanced)
        .toolbar {
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
                .help(voiceInputController.failureMessage ?? "Use this button or a future global shortcut to control dictation.")

                Button("Buy") {
                    appState.selectedScreen = .overview
                }
                .help("Placeholder only. Licensing is not implemented.")

                Button {
                    openSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
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
        case .settings:
            SettingsHomeView(appState: appState)
        }
    }
}

#if DEBUG
struct MainWindowView_Previews: PreviewProvider {
    static var previews: some View {
        MainWindowView(appState: .preview)
            .frame(width: 1280, height: 860)
    }
}
#endif
