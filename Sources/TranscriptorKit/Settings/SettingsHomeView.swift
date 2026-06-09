import SwiftUI

public struct SettingsHomeView: View {
    @Bindable private var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        SettingsView(appState: appState)
    }
}
