import SwiftUI

public struct SettingsHomeView: View {
    @Environment(\.openSettings) private var openSettings

    private let appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Settings")
                        .font(.system(size: 32, weight: .semibold))

                    Text("Preferences live in the native macOS Settings window. The summary below reflects your current lightweight local state.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 16) {
                    summaryCard(
                        title: "Recording",
                        lines: [
                            "Mode: \(appState.recordingState.mode.title)",
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
                    subtitle: "The app uses a dedicated macOS Settings scene instead of an in-window preferences form."
                ) {
                    HStack(spacing: 12) {
                        Button("Open Settings") {
                            openSettings()
                        }
                        .keyboardShortcut(",", modifiers: .command)

                        Text("Launch at login still persists as a preference only. Service Management integration is a follow-up.")
                            .foregroundStyle(.secondary)
                    }

                    Text("The Buy button in the toolbar is also a non-functional placeholder kept only for screenshot parity.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    private func megabyteString(for bytes: Int64) -> String {
        String(format: "%.2f MB", Double(bytes) / 1_048_576)
    }
}
