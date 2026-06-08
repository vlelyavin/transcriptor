import SwiftUI
import SottoKit

@main
struct SottoApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainWindowView(appState: appState)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import Audio") {
                    appState.selectedScreen = .importAudio
                }
                .keyboardShortcut("I", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView(appState: appState)
                .frame(minWidth: 820, minHeight: 560)
        }
    }
}
