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
            List(selection: $appState.selectedScreen) {
                ForEach(NavigationScreen.allCases) { screen in
                    Label(screen.title, systemImage: screen.systemImage)
                        .tag(screen)
                        .help(screen.title)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
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
                .background(Color(nsColor: .underPageBackgroundColor))
        }
        .frame(minWidth: 780, minHeight: 600)
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
