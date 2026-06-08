import SwiftUI

public struct OverviewView: View {
    private let appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sotto")
                        .font(.system(size: 34, weight: .semibold))

                    Text("A native macOS shell for a local-first speech-to-text workflow.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                SectionCard(
                    title: "Recording Overlay",
                    subtitle: "Global capture and live feedback are planned for a future milestone."
                ) {
                    Label("Non-activating overlay: planned", systemImage: "rectangle.inset.filled.and.person.filled")
                    Label("Live audio indicator: planned", systemImage: "waveform.badge.mic")
                    Label("Current mode preference: \(appState.recordingState.mode.title)", systemImage: "keyboard")
                }

                SectionCard(
                    title: "Transcription Stack",
                    subtitle: "The app remains truthful about what is not implemented yet."
                ) {
                    Text("Whisper-family models, Parakeet exploration, and OpenAI/Groq provider entries are visible in the UI, but none are presented as functional until the real runtimes and networking layers exist.")
                        .foregroundStyle(.secondary)

                    if let selectedModel = appState.selectedModel {
                        Text("Selected model preference: \(selectedModel.name)")
                            .font(.callout)
                    }
                }

                SectionCard(
                    title: "Storage Controls",
                    subtitle: "History, audio, and transcript retention will be capped independently of downloaded model files."
                ) {
                    Text("Current history cap: \(appState.storageSettings.capMegabytes) MB")
                    Text("Auto-delete oldest history: \(appState.storageSettings.autoDeleteOldestHistory ? "On" : "Off")")
                        .foregroundStyle(.secondary)
                    Text("Downloaded model files excluded: \(appState.storageSettings.excludesDownloadedModels ? "Yes" : "No")")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .navigationTitle("Overview")
    }
}
