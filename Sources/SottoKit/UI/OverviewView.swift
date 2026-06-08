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
                    subtitle: "Global capture, pending recordings, and live feedback now flow through the voice input controller."
                ) {
                    Label("Current controller state: \(appState.voiceInputController.state.rawValue)", systemImage: "mic.badge.plus")
                    Label("Overlay enabled: \(appState.overlayState.isEnabled ? "Yes" : "No")", systemImage: "rectangle.inset.filled.and.person.filled")
                    Label("Live audio indicator: \(appState.overlayState.showsLiveAudioIndicator ? "On" : "Off")", systemImage: "waveform.badge.mic")
                    Label("Current mode preference: \(appState.recordingState.mode.title)", systemImage: "keyboard")
                }

                SectionCard(
                    title: "Transcription Stack",
                    subtitle: "Local Whisper transcription is live, while unsupported runtimes still stay visibly unavailable."
                ) {
                    Text("WhisperKit-backed local models can now be downloaded, loaded, and used for on-device transcription. Parakeet and cloud providers remain visible as future work, not working features.")
                        .foregroundStyle(.secondary)

                    if let selectedModel = appState.selectedModel {
                        Text("Selected model preference: \(selectedModel.name)")
                            .font(.callout)
                    }

                    Text("Auto-transcribe after recording/import: \(appState.transcriptionPreferences.autoTranscribeAfterCapture ? "On" : "Off")")
                        .foregroundStyle(.secondary)
                }

                SectionCard(
                    title: "Storage Controls",
                    subtitle: "History, audio, and transcript retention will be capped independently of downloaded model files."
                ) {
                    Text("Current history cap: \(appState.storageSettings.capMegabytes) MB")
                    Text("Managed usage: \(megabyteString(for: appState.storageUsage.totalManagedBytes))")
                        .foregroundStyle(.secondary)
                    Text("History items stored: \(appState.historyStore.entries.count)")
                        .foregroundStyle(.secondary)
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

    private func megabyteString(for bytes: Int64) -> String {
        String(format: "%.2f MB", Double(bytes) / 1_048_576)
    }
}
