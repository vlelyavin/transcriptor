import SwiftUI

public struct MainWindowView: View {
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

                List(selection: $appState.selectedScreen) {
                    ForEach(NavigationScreen.allCases) { screen in
                        Label(screen.title, systemImage: screen.systemImage)
                            .tag(screen)
                            .help(screen.title)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Divider()

                        HStack(spacing: 8) {
                            Image(systemName: voiceInputController.isRecording ? "mic.fill" : "mic")
                                .foregroundStyle(voiceInputController.isRecording ? .red : .secondary)

                            Text(voiceInputController.isRecording ? "Recording" : "Ready")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(appState.recordingState.hotkey.displayString)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
            .background {
                NativeSidebarMaterial()
                    .ignoresSafeArea()
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 236, max: 270)
        } detail: {
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .underPageBackgroundColor))
        }
        .frame(minWidth: 800, minHeight: 620)
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
                    appState.openSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Open Settings")
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
            SettingsView(appState: appState)
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
