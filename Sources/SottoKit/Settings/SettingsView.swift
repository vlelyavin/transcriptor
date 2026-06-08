import SwiftUI

public struct SettingsView: View {
    @State private var selectedPane: SettingsPane? = .general
    @Bindable private var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $selectedPane) { pane in
                Label(pane.title, systemImage: pane.systemImage)
                    .tag(pane)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            ScrollView {
                currentPaneView
                    .padding(24)
            }
        }
    }

    @ViewBuilder
    private var currentPaneView: some View {
        switch selectedPane ?? .general {
        case .general:
            settingsForm(title: "General", subtitle: "App-wide preferences that persist locally on this Mac.") {
                Section("Application") {
                    Toggle("Launch at login", isOn: $appState.generalSettings.launchAtLoginEnabled)

                    Text("This is a placeholder preference only. Service Management integration is not implemented yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .recording:
            settingsForm(title: "Recording", subtitle: "Voice input behavior and local capture defaults.") {
                Section("Input Mode") {
                    Picker("Voice Input Mode", selection: $appState.recordingState.mode) {
                        ForEach(RecordingMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    Toggle("Save original audio", isOn: $appState.recordingState.savesAudioLocally)
                }

                Section("Microphone") {
                    LabeledContent("Permission") {
                        Text(appState.voiceInputController.permissionStatus.rawValue.capitalized)
                    }

                    LabeledContent("Input Device") {
                        Text("System Default")
                            .foregroundStyle(.secondary)
                    }

                    Text("Input device selection is a follow-up item. This build records from the current system default microphone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .keyboardShortcut:
            settingsForm(title: "Keyboard Shortcut", subtitle: "The global voice-input shortcut works while Sotto is running and does not require the main window to stay focused.") {
                Section("Global Voice Input") {
                    LabeledContent("Current Shortcut") {
                        Text(appState.recordingState.hotkey.displayString)
                            .font(.system(.body, design: .monospaced))
                    }

                    HotkeyRecorderButton(configuration: $appState.recordingState.hotkey)

                    if let conflictWarning = appState.recordingState.hotkey.obviousConflictWarning {
                        Text(conflictWarning)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("Avoid common system shortcuts like Spotlight or input source switching.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let registrationError = appState.hotkeyRegistrationErrorMessage {
                        Text(registrationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Menu Shortcuts") {
                    LabeledContent("Import Audio") {
                        Text("Cmd + Shift + I")
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
        case .overlay:
            settingsForm(title: "Overlay", subtitle: "Preferences for the live non-activating recording overlay.") {
                Section("Appearance") {
                    Toggle("Show recording overlay", isOn: $appState.overlayState.isEnabled)
                    Toggle("Use non-activating overlay", isOn: $appState.overlayState.isNonActivating)
                    Toggle("Show live audio indicator", isOn: $appState.overlayState.showsLiveAudioIndicator)

                    Picker("Overlay Position", selection: $appState.overlayState.position) {
                        ForEach(OverlayPosition.allCases) { position in
                            Text(position.title).tag(position)
                        }
                    }
                }
            }
        case .models:
            settingsForm(title: "Models", subtitle: "Choose which local Whisper model Sotto should use and whether new audio should transcribe automatically.") {
                Section("Local Provider") {
                    Picker("Preferred Local Provider", selection: $appState.transcriptionPreferences.preferredLocalProviderID) {
                        Text("WhisperKit Local").tag("whisperkit-local")
                    }

                    Text("WhisperKit is the only implemented local provider in this build. Cloud providers remain unavailable for transcription.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Default Local Model") {
                    Picker("Selected Transcription Model", selection: $appState.transcriptionPreferences.selectedModelID) {
                        ForEach(appState.modelCatalog.whisperModels) { model in
                            Text(model.name).tag(model.id)
                        }
                    }

                    if let selectedModel = appState.selectedModel {
                        HStack {
                            AvailabilityBadge(availability: selectedModel.availability)
                            Text(selectedModel.availability.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Automation") {
                    Toggle("Auto-transcribe after recording or import", isOn: $appState.transcriptionPreferences.autoTranscribeAfterCapture)

                    if let statusMessage = appState.whisperModelManager.statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .storage:
            settingsForm(title: "Storage", subtitle: "Control how much history data Sotto keeps locally.") {
                Section("Retention") {
                    Stepper(value: $appState.storageSettings.capMegabytes, in: 256...10_240, step: 256) {
                        Text("History storage limit: \(appState.storageSettings.capMegabytes) MB")
                    }

                    Toggle("Auto-delete oldest history when over limit", isOn: $appState.storageSettings.autoDeleteOldestHistory)
                    Toggle("Exclude downloaded model files from cap", isOn: $appState.storageSettings.excludesDownloadedModels)
                }

                Section("Usage") {
                    LabeledContent("Current usage") {
                        Text(megabyteString(for: appState.storageUsage.totalManagedBytes))
                    }

                    LabeledContent("Audio files") {
                        Text(megabyteString(for: appState.storageUsage.audioBytes))
                    }

                    LabeledContent("Metadata and exports") {
                        Text(megabyteString(for: appState.storageUsage.historyBytes + appState.storageUsage.metadataBytes))
                    }

                    if appState.storageSettings.excludesDownloadedModels {
                        LabeledContent("Model cache (excluded)") {
                            Text(megabyteString(for: appState.storageUsage.modelBytes))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let storageWarningMessage = appState.storageWarningMessage {
                        Text(storageWarningMessage)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        case .cloudProviders:
            settingsForm(title: "Cloud Providers", subtitle: "Provider toggles persist locally, but real networking and credentials are still unavailable.") {
                Section("Provider Preferences") {
                    Toggle("Enable OpenAI", isOn: $appState.providerSettings.openAIEnabled)
                    if let provider = appState.providerCatalog.providers.first(where: { $0.id == "openai" }) {
                        providerFootnote(provider)
                    }

                    Toggle("Enable Groq", isOn: $appState.providerSettings.groqEnabled)
                    if let provider = appState.providerCatalog.providers.first(where: { $0.id == "groq" }) {
                        providerFootnote(provider)
                    }
                }

                Section("Credentials") {
                    Text("API keys are not accepted in this build. When added later, they must be stored in the macOS Keychain only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .privacy:
            settingsForm(title: "Privacy", subtitle: "Truthful notes about what this build does and does not do yet.") {
                Section("Current Behavior") {
                    Label("Local WhisperKit transcription keeps audio on this Mac. Sotto does not upload recording or import audio for local runs.", systemImage: "lock.shield")
                    Label("Model downloads come from Argmax's public WhisperKit model repository and are stored under Application Support.", systemImage: "square.and.arrow.down")
                    Label("Provider toggles store local preference state only.", systemImage: "key")
                    Label("WebM import is stored as a failed item because this build does not yet include a reliable WebM decoder/transcoder.", systemImage: "exclamationmark.triangle")
                }
            }
        }
    }

    private func settingsForm<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.largeTitle.weight(.semibold))

                Text(subtitle)
                    .foregroundStyle(.secondary)
            }

            Form {
                content()
            }
            .formStyle(.grouped)
        }
        .frame(maxWidth: 720, alignment: .leading)
    }

    private func providerFootnote(_ provider: ProviderDescriptor) -> some View {
        HStack {
            AvailabilityBadge(availability: provider.availability)
            Text("\(provider.modelLabel) • \(provider.availability.message)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func megabyteString(for bytes: Int64) -> String {
        String(format: "%.2f MB", Double(bytes) / 1_048_576)
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(appState: .preview)
            .frame(width: 1080, height: 720)
    }
}
#endif
