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
            }
        case .keyboardShortcut:
            settingsForm(title: "Keyboard Shortcut", subtitle: "Global shortcut editing remains intentionally unavailable in this build.") {
                Section("Global Voice Input") {
                    LabeledContent("Current Shortcut") {
                        Text(appState.recordingState.hotkey.modifiers.joined(separator: " + ") + " + " + appState.recordingState.hotkey.key)
                            .font(.system(.body, design: .monospaced))
                    }

                    Button("Capture Shortcut") {}
                        .disabled(true)

                    Text("Shortcut capture and registration are not implemented yet. The value shown here is mock state only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Menu Shortcuts") {
                    LabeledContent("Import Audio") {
                        Text("Cmd + Shift + I")
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
        case .overlay:
            settingsForm(title: "Overlay", subtitle: "Preferences for the future non-activating recording overlay.") {
                Section("Appearance") {
                    Toggle("Use non-activating overlay", isOn: $appState.overlayState.isNonActivating)
                    Toggle("Show live audio indicator", isOn: $appState.overlayState.showsLiveAudioIndicator)
                }
            }
        case .models:
            settingsForm(title: "Models", subtitle: "Choose the preferred transcription model for future sessions.") {
                Section("Preferred Model") {
                    Picker("Selected Transcription Model", selection: $appState.transcriptionPreferences.selectedModelID) {
                        ForEach(appState.modelCatalog.allModels) { model in
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
            settingsForm(title: "Privacy", subtitle: "Truthful notes about what this UI does and does not do yet.") {
                Section("Current Behavior") {
                    Label("No audio is uploaded by this scaffold because networking is not implemented.", systemImage: "lock.shield")
                    Label("Original audio can be marked for local save, but recording itself is not implemented yet.", systemImage: "internaldrive")
                    Label("Provider toggles store local preference state only.", systemImage: "key")
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
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(appState: .preview)
            .frame(width: 1080, height: 720)
    }
}
#endif
