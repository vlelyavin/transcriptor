import SwiftUI

/// The detail form for one settings pane. Settings live in the main window
/// sidebar (like System Settings), so this renders inside the main split view.
public struct SettingsPaneDetailView: View {
    @Bindable private var appState: AppState
    private let pane: SettingsPane

    public init(pane: SettingsPane, appState: AppState) {
        self.pane = pane
        self.appState = appState
    }

    public var body: some View {
        currentPaneView(for: pane)
            .navigationTitle(pane.title)
    }

    @ViewBuilder
    private func currentPaneView(for pane: SettingsPane) -> some View {
        switch pane {
        case .general:
            // Essentials only. Everything else lives under Advanced.
            settingsForm {
                voiceInputSection
                transcriptInsertionSection
                applicationSection
            }
        case .keyboardShortcut:
            settingsForm {
                shortcutSections
            }
        case .advanced:
            // Single catch-all for everything non-essential. Transcription
            // provider/model selection lives on the dedicated Models screen, not
            // here, to avoid duplicate settings.
            settingsForm {
                recordingDetailSection
                overlaySection
                storageSections
                privacySection
                diagnosticsSection
            }
        // The panes below are no longer listed in the sidebar but remain
        // reachable via Overview deep links and sidebar search, each showing a
        // focused slice of the Advanced settings.
        case .recording:
            settingsForm {
                voiceInputSection
                recordingDetailSection
                transcriptInsertionSection
            }
        case .overlay:
            settingsForm { overlaySection }
        case .storage:
            settingsForm { storageSections }
        case .privacy:
            settingsForm { privacySection }
        }
    }

    // MARK: - Section builders (shared across panes)

    @ViewBuilder
    private var voiceInputSection: some View {
        Section("Voice Input") {
            Picker("Voice Input Mode", selection: $appState.recordingState.mode) {
                ForEach(RecordingMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Toggle("Show recording overlay", isOn: $appState.overlayState.isEnabled)
        }
    }

    @ViewBuilder
    private var transcriptInsertionSection: some View {
        Section {
            Toggle("Insert transcript into active app", isOn: $appState.generalSettings.insertTranscriptIntoActiveApp)
            Toggle("Also copy transcript to clipboard", isOn: $appState.generalSettings.alsoCopyTranscriptToClipboard)
            Toggle("Restore previous clipboard after insertion", isOn: $appState.generalSettings.restoreClipboardAfterInsertion)
                .disabled(appState.generalSettings.alsoCopyTranscriptToClipboard)

            LabeledContent("Accessibility") {
                Text(appState.accessibilityPermissionStatus.rawValue)
            }

            HStack {
                Button("Request Accessibility Access") {
                    appState.requestAccessibilityPermissionPrompt()
                }

                Button("Open Accessibility Settings") {
                    appState.openAccessibilityPrivacySettings()
                }
            }
        } header: {
            Text("Transcript Insertion")
        } footer: {
            Text("Accessibility access is only required for inserting dictated text into other apps. If access is unavailable, Transcriptor still saves the transcript to history and can copy it to the clipboard instead.")
        }
    }

    @ViewBuilder
    private var applicationSection: some View {
        Section {
            Toggle(
                "Show Transcriptor in menu bar",
                isOn: $appState.generalSettings.showMenuBarIcon
            )

            Toggle(
                "Launch at login",
                isOn: Binding(
                    get: { appState.generalSettings.launchAtLoginEnabled },
                    set: { appState.setLaunchAtLoginEnabled($0) }
                )
            )
            .disabled(!appState.launchAtLoginStatus.canRegisterFromCurrentRuntime)

            LabeledContent("Status") {
                Text(appState.launchAtLoginStatus.title)
            }

            HStack {
                Button("Refresh Status") {
                    appState.refreshLaunchAtLoginStatus()
                }

                Button("Open Login Items Settings") {
                    appState.openLoginItemsSettings()
                }
            }
        } header: {
            Text("Application")
        } footer: {
            Text(appState.launchAtLoginStatus.detail)
        }
    }

    @ViewBuilder
    private var recordingDetailSection: some View {
        Section {
            Toggle(isOn: $appState.recordingState.savesAudioLocally) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save original audio")
                    if !appState.recordingState.savesAudioLocally {
                        Text("Currently partial: dictation audio is still kept locally for pending transcription and reliable re-transcription until cleanup rules are fully implemented.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            LabeledContent("Permission") {
                Text(appState.voiceInputController.permissionStatus.rawValue.capitalized)
            }

            LabeledContent("Input Device") {
                Text("System Default")
                    .foregroundStyle(.secondary)
            }

            Button("Open Microphone Privacy Settings") {
                appState.openMicrophonePrivacySettings()
            }
        } header: {
            Text("Microphone & Audio")
        } footer: {
            Text("Input device selection is a follow-up item. This build records from the current system default microphone.")
        }
    }

    @ViewBuilder
    private var shortcutSections: some View {
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

            Button("Restore Recommended Shortcut") {
                appState.resetHotkeyToRecommendedDefault()
            }
        }

        Section("Menu Shortcuts") {
            LabeledContent("Import Audio") {
                Text("⌘⇧I")
                    .font(.system(.body, design: .monospaced))
            }

            LabeledContent("Search History") {
                Text("⌘F")
                    .font(.system(.body, design: .monospaced))
            }

            LabeledContent("Settings") {
                Text("⌘,")
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    @ViewBuilder
    private var overlaySection: some View {
        Section {
            Toggle("Show recording overlay", isOn: $appState.overlayState.isEnabled)
            Toggle("Use non-activating overlay", isOn: $appState.overlayState.isNonActivating)
            Toggle("Show live audio indicator", isOn: $appState.overlayState.showsLiveAudioIndicator)

            Picker("Overlay Position", selection: $appState.overlayState.position) {
                ForEach(OverlayPosition.allCases) { position in
                    Text(position.title).tag(position)
                }
            }

            Button("Restore Overlay Defaults") {
                appState.resetOverlayDefaults()
            }
        } header: {
            Text("Overlay")
        } footer: {
            Text("The overlay is non-activating by default so it stays above normal windows without stealing focus from the app you are dictating into.")
        }
    }

    /// History storage limit bounds: 20 MB up to 2 GB (2 048 MB).
    private var storageLimitRange: ClosedRange<Int> { 20...2_048 }

    /// Clamps both typed entry and stepper input to `storageLimitRange` so the
    /// limit can never be set outside the supported bounds.
    private var storageLimitBinding: Binding<Int> {
        Binding(
            get: {
                min(max(appState.storageSettings.capMegabytes, storageLimitRange.lowerBound), storageLimitRange.upperBound)
            },
            set: { newValue in
                appState.storageSettings.capMegabytes = min(max(newValue, storageLimitRange.lowerBound), storageLimitRange.upperBound)
            }
        )
    }

    @ViewBuilder
    private var storageSections: some View {
        Section("Retention") {
            LabeledContent("History storage limit") {
                HStack(spacing: 6) {
                    TextField("", value: storageLimitBinding, format: .number)
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 62)
                        .textFieldStyle(.roundedBorder)

                    Text("MB")
                        .foregroundStyle(.secondary)

                    Stepper("", value: storageLimitBinding, in: storageLimitRange, step: 64)
                        .labelsHidden()
                }
            }

            Toggle("Auto-delete oldest history when over limit", isOn: $appState.storageSettings.autoDeleteOldestHistory)
            Toggle("Exclude downloaded model files from cap", isOn: $appState.storageSettings.excludesDownloadedModels)

            Button("Restore Storage Defaults") {
                appState.resetStorageDefaults()
            }
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

    @ViewBuilder
    private var privacySection: some View {
        Section("Privacy") {
            Label("Local WhisperKit transcription keeps audio on this Mac. Transcriptor does not upload recording or import audio for local runs.", systemImage: "lock.shield")
            Label("Parakeet Local uses FluidAudio Core ML bundles downloaded from Hugging Face and keeps transcription on this Mac.", systemImage: "waveform.badge.mic")
            Label("Model downloads come from public model repositories and stay in Application Support.", systemImage: "square.and.arrow.down")
            Label("OpenAI and Groq only send audio after you store an API key in Keychain and confirm on the Models page that audio may be sent.", systemImage: "key")
            Label("Imports use standard macOS user-granted file access through the open panel or drag and drop, then copies are stored under Application Support for durable local history.", systemImage: "folder.badge.plus")
        }
    }

    @ViewBuilder
    private var diagnosticsSection: some View {
        Section("Last Insertion Attempt") {
            LabeledContent("Captured App") {
                Text(appState.transcriptInsertionDebugSnapshot.capturedAppName ?? "None")
                    .foregroundStyle(appState.transcriptInsertionDebugSnapshot.capturedAppName == nil ? .secondary : .primary)
            }

            LabeledContent("Target") {
                Text(appState.transcriptInsertionDebugSnapshot.targetSummary)
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("Result") {
                Text(appState.transcriptInsertionDebugSnapshot.lastOutcome?.message ?? "No insertion attempt yet.")
                    .foregroundStyle(appState.transcriptInsertionDebugSnapshot.lastOutcome == nil ? .secondary : .primary)
                    .multilineTextAlignment(.trailing)
            }

            if let lastUpdatedAt = appState.transcriptInsertionDebugSnapshot.lastUpdatedAt {
                LabeledContent("Updated") {
                    Text(lastUpdatedAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func settingsForm<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        Form {
            content()
        }
        .formStyle(.grouped)
    }

    private func megabyteString(for bytes: Int64) -> String {
        String(format: "%.2f MB", Double(bytes) / 1_048_576)
    }
}

#if DEBUG
struct SettingsPaneDetailView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPaneDetailView(pane: .general, appState: .preview)
            .frame(width: 760, height: 560)
    }
}
#endif
