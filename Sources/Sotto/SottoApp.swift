import SwiftUI
import SottoKit

@main
struct SottoApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainWindowView(appState: appState)
        }

        Settings {
            SettingsView(appState: appState)
                .frame(width: 720, height: 520)
        }
    }
}
