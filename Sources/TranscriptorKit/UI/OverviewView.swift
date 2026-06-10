import SwiftUI

public struct OverviewView: View {
    private let appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        Form {
            Section {
                LabeledContent("Voice input shortcut") {
                    Text(appState.recordingState.hotkey.displayString)
                        .font(.system(.body, design: .monospaced))
                }

                LabeledContent("Input mode") {
                    Text(appState.recordingState.mode.title)
                }

                LabeledContent("Current state") {
                    Text(appState.voiceInputController.state.rawValue.capitalized)
                }

                LabeledContent("Overlay") {
                    Text(appState.overlayState.isEnabled ? "Enabled" : "Disabled")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Insert into active app") {
                    Text(insertionStatusText)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Voice Input")
            }

            Section {
                LabeledContent("Preferred provider") {
                    Text(preferredProviderTitle)
                }

                LabeledContent("Selected local model") {
                    Text(appState.selectedModel?.name ?? "None selected")
                }

                LabeledContent("Ready local models") {
                    Text("\(appState.readyLocalModelIDs.count)")
                }

                LabeledContent("Auto-transcribe") {
                    Text(appState.transcriptionPreferences.autoTranscribeAfterCapture ? "On" : "Off")
                }
            } header: {
                Text("Transcription")
            }

            Section {
                LabeledContent("Managed usage") {
                    Text(megabyteString(for: appState.storageUsage.totalManagedBytes))
                }

                LabeledContent("History limit") {
                    Text("\(appState.storageSettings.capMegabytes) MB")
                }

                LabeledContent("History items") {
                    Text("\(appState.historyStore.entries.count)")
                }

                if let storageWarningMessage = appState.storageWarningMessage {
                    Text(storageWarningMessage)
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
            } header: {
                Text("Storage")
            }

            Section {
                if appState.historyStore.entries.isEmpty {
                    ContentUnavailableView(
                        "No Recent History",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Record or import audio to start building transcript history.")
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(appState.historyStore.entries.prefix(5)) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.displayName)
                                .lineLimit(1)

                            Text("\(entry.transcriptionStatus.title) • \(formattedDate(entry.createdAt))")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(entry.transcriptPreview.isEmpty ? "Pending transcription" : entry.transcriptPreview)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text("Recent History")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Overview")
    }

    private func megabyteString(for bytes: Int64) -> String {
        String(format: "%.2f MB", Double(bytes) / 1_048_576)
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private var insertionStatusText: String {
        guard appState.generalSettings.insertTranscriptIntoActiveApp else {
            return "Off"
        }

        return appState.accessibilityPermissionStatus == .granted
            ? "On"
            : "On — needs Accessibility access"
    }

    private var preferredProviderTitle: String {
        switch appState.transcriptionPreferences.preferredProviderID {
        case "parakeet-local":
            "Parakeet Local"
        case "whisperkit-local":
            "WhisperKit Local"
        default:
            appState.preferredCloudProvider?.name ?? "WhisperKit Local"
        }
    }
}
