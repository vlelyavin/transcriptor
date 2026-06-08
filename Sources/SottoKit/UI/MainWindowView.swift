import SwiftUI

public struct MainWindowView: View {
    @Bindable private var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Sotto")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Native macOS scaffold for a local-first speech-to-text app.")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 960, minHeight: 640)
        .padding(40)
    }
}
