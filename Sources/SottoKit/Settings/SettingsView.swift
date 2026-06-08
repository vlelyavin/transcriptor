import SwiftUI

public struct SettingsView: View {
    @Bindable private var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Recording") {
                    Picker("Voice Input Mode", selection: $appState.recordingState.mode) {
                        ForEach(RecordingMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    LabeledContent("Global Shortcut") {
                        Text(appState.recordingState.hotkey.modifiers.joined(separator: " + ") + " + " + appState.recordingState.hotkey.key)
                            .foregroundStyle(.secondary)
                    }

                    Toggle("Save recordings locally", isOn: $appState.recordingState.savesAudioLocally)

                    Text("Global hotkeys and recording are not implemented yet. These controls exist only as truthful UI scaffolding.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Overlay") {
                    Toggle("Use non-activating overlay", isOn: $appState.overlayState.isNonActivating)
                    Toggle("Show live audio indicator", isOn: $appState.overlayState.showsLiveAudioIndicator)
                }

                Section("Audio") {
                    LabeledContent("Input Device") {
                        Text(appState.audioCaptureState.inputDeviceName)
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Sample Rate") {
                        Text("\(appState.audioCaptureState.sampleRate) Hz")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Storage") {
                    Stepper(value: $appState.storageSettings.capMegabytes, in: 256...10_240, step: 256) {
                        Text("Retention Cap: \(appState.storageSettings.capMegabytes) MB")
                    }

                    Toggle("Exclude downloaded model files from cap", isOn: $appState.storageSettings.excludesDownloadedModels)
                }

                Section("Providers") {
                    ForEach(appState.providerCatalog.providers) { provider in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(provider.name)
                                Spacer()
                                AvailabilityBadge(availability: provider.availability)
                            }

                            Text(provider.availability.blocker)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }

                    Text("API keys are not accepted in this scaffold. Future credentials must be stored in the macOS Keychain only.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding()
            .navigationTitle("Settings")
        }
    }
}
