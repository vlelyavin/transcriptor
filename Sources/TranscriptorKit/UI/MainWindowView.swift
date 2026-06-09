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
            VStack(spacing: 0) {
                SidebarHeaderView()

                Divider()

                List(selection: $appState.selectedScreen) {
                    Section("Library") {
                        ForEach(NavigationScreen.allCases) { screen in
                            HStack(spacing: 10) {
                                Image(systemName: screen.systemImage)
                                    .frame(width: 18)
                                    .foregroundStyle(.secondary)

                                Text(screen.title)
                                    .lineLimit(1)

                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                            .tag(screen)
                        }
                    }
                }
                .listStyle(.sidebar)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 1080, minHeight: 720)
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
                        systemImage: voiceInputController.isRecording ? "stop.circle.fill" : "mic.circle"
                    )
                }
                .disabled(voiceInputController.state == .requestingPermission || voiceInputController.state == .stopping)
                .help(voiceInputController.failureMessage ?? "Use this button or your configured global shortcut to control dictation.")

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
            .frame(width: 1320, height: 840)
    }
}
#endif
