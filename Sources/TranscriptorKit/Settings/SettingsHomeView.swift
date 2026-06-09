import SwiftUI

public struct SettingsHomeView: View {
    @Environment(\.openSettings) private var openSettings

    private let appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Settings")
                        .font(.title.weight(.semibold))

                    Text("Open the dedicated macOS Settings window to manage recording, models, storage, providers, and privacy. This summary reflects the current local configuration.")
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 16) {
                    summaryCard(
                        title: "Recording",
                        lines: [
                            "Mode: \(appState.recordingState.mode.title)",
                            "Auto-insert: \(appState.generalSettings.insertTranscriptIntoActiveApp ? "On" : "Off")",
                            "Save original audio: \(appState.recordingState.savesAudioLocally ? "On" : "Off")",
                            "Mic permission: \(appState.voiceInputController.permissionStatus.rawValue.capitalized)",
                            "Launch at login: \(appState.generalSettings.launchAtLoginEnabled ? "Requested" : "Off")",
                        ]
                    )

                    summaryCard(
                        title: "Models",
                        lines: [
                            "Selected: \(appState.selectedModel?.name ?? "None")",
                            "Auto-transcribe: \(appState.transcriptionPreferences.autoTranscribeAfterCapture ? "On" : "Off")",
                            "History cap: \(appState.storageSettings.capMegabytes) MB",
                            "Managed usage: \(megabyteString(for: appState.storageUsage.totalManagedBytes))"
                        ]
                    )

                    summaryCard(
                        title: "Providers",
                        lines: [
                            "Preferred provider: \(appState.transcriptionPreferences.preferredProviderID == "whisperkit-local" ? "WhisperKit Local" : appState.preferredCloudProvider?.name ?? "WhisperKit Local")",
                            "OpenAI key stored: \(appState.hasStoredAPIKey(for: "openai") ? "Yes" : "No")",
                            "Groq key stored: \(appState.hasStoredAPIKey(for: "groq") ? "Yes" : "No")",
                        ]
                    )
                }

                SectionCard(
                    title: "Native Settings Window",
                    subtitle: "Transcriptor uses a dedicated Settings window so preferences stay organized like a native macOS app."
                ) {
                    HStack(spacing: 12) {
                        Button("Open Settings") {
                            openSettings()
                        }
                        .keyboardShortcut(",", modifiers: .command)

                        Text("Launch at login still persists as a preference only. Service Management integration is a follow-up.")
                            .foregroundStyle(.secondary)
                    }

                    if let storageWarningMessage = appState.storageWarningMessage {
                        Text(storageWarningMessage)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Settings")
    }

    private func summaryCard(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            ForEach(lines, id: \.self) { line in
                Text(line)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
    }

    private func megabyteString(for bytes: Int64) -> String {
        String(format: "%.2f MB", Double(bytes) / 1_048_576)
    }
}
