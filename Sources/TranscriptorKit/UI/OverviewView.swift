import SwiftUI

public struct OverviewView: View {
    private let appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        Form {
            Section {
                heroHeader
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            if !appState.isTranscriptionConfigured {
                Section {
                    setupBanner
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                linkedRow("Voice input shortcut", destination: .settings(.keyboardShortcut)) {
                    Text(appState.recordingState.hotkey.displayString)
                        .font(.system(.body, design: .monospaced))
                }

                linkedRow("Input mode", destination: .settings(.general)) {
                    Text(appState.recordingState.mode.title)
                }

                linkedRow("Current state", destination: .settings(.advanced)) {
                    Text(appState.voiceInputController.state.rawValue.capitalized)
                }

                linkedRow("Overlay", destination: .settings(.general)) {
                    Text(appState.overlayState.isEnabled ? "Enabled" : "Disabled")
                        .foregroundStyle(.secondary)
                }

                linkedRow("Insert into active app", destination: .settings(.general)) {
                    Text(insertionStatusText)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Voice Input")
            }

            Section {
                linkedRow("Preferred provider", destination: .settings(.models)) {
                    Text(preferredProviderTitle)
                }

                linkedRow("Selected local model", destination: .settings(.models)) {
                    Text(appState.selectedModel?.name ?? "None selected")
                }

                linkedRow("Ready local models", destination: .screen(.models)) {
                    Text("\(appState.readyLocalModelIDs.count)")
                }

                linkedRow("Auto-transcribe", destination: .settings(.models)) {
                    Text(appState.transcriptionPreferences.autoTranscribeAfterCapture ? "On" : "Off")
                }
            } header: {
                Text("Transcription")
            }

            Section {
                linkedRow("Managed usage", destination: .settings(.storage)) {
                    Text(megabyteString(for: appState.storageUsage.totalManagedBytes))
                }

                linkedRow("History limit", destination: .settings(.storage)) {
                    Text("\(appState.storageSettings.capMegabytes) MB")
                }

                linkedRow("History items", destination: .screen(.history)) {
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

                    Button("Open History") {
                        appState.sidebarSelection = .screen(.history)
                    }
                }
            } header: {
                Text("Recent History")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Overview")
    }

    /// Native System Settings-style hero: large app glyph, name, and a one-line
    /// description of what the app does.
    private var heroHeader: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                }

            Text("Transcriptor")
                .font(.title2.weight(.bold))

            Text("Press your shortcut, speak, and your words are typed for you — transcribed on-device and saved to a private local history.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    /// Persistent call-to-action shown until a transcription model (or cloud
    /// provider) is configured. Launches the setup guide.
    private var setupBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("Set up transcription")
                    .font(.body.weight(.semibold))
                Text("Download a model to turn recordings into text. Until then, Transcriptor still works as a voice recorder.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button("Set Up…") {
                appState.presentWelcomeGuide()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 0.5)
        }
        .padding(.vertical, 4)
    }

    /// A status row whose trailing button jumps to the place where the value
    /// can actually be changed.
    private func linkedRow(
        _ title: String,
        destination: SidebarItem,
        @ViewBuilder value: () -> some View
    ) -> some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                value()

                Button {
                    appState.sidebarSelection = destination
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .background(.quaternary.opacity(0.7), in: Circle())
                }
                .buttonStyle(.plain)
                .help(helpText(for: destination))
            }
        }
    }

    private func helpText(for destination: SidebarItem) -> String {
        switch destination {
        case let .screen(screen):
            "Open \(screen.title)"
        case let .settings(pane):
            "Change in Settings › \(pane.title)"
        }
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
