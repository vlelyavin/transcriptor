import SwiftUI

public struct MainWindowView: View {
    @Bindable private var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        NavigationSplitView {
            List(NavigationScreen.allCases, selection: $appState.selectedScreen) { screen in
                Label(screen.title, systemImage: screen.systemImage)
                    .tag(screen)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            contentView
        }
        .frame(minWidth: 960, minHeight: 640)
        .toolbar {
            ToolbarItemGroup {
                Button {
                } label: {
                    Label("Start Voice Input", systemImage: "mic.fill")
                }
                .disabled(true)
                .help("Recording is not implemented in this initial scaffold.")

                SettingsLink {
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
            HistoryView(historyStore: appState.historyStore)
        case .importAudio:
            ImportAudioView()
        case .models:
            ModelsView(catalog: appState.modelCatalog, providers: appState.providerCatalog)
        case .settings:
            SettingsView(appState: appState)
        }
    }
}
