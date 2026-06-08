import SwiftUI

public struct SettingsView: View {
    @Bindable private var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Recording") {
                    Text("Settings placeholder")
                }
            }
            .formStyle(.grouped)
            .padding()
            .navigationTitle("Settings")
        }
    }
}
