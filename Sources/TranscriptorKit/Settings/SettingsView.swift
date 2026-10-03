import SwiftUI

/// The detail form for one settings pane. Settings live in the main window
/// sidebar (like System Settings), so this renders inside the main split view.
public struct SettingsPaneDetailView: View {
    @Bindable private var appState: AppState
    private let pane: SettingsPane
    @State private var showClearHistoryConfirmation = false

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
            settingsForm {
                shortcutSection
                voiceInputSection
                permissionsSection
                transcriptInsertionSection
                applicationSection
            }
        case .storage:
            settingsForm { storageSections }
        }
    }

    // MARK: - Section builders

    @ViewBuilder
    private var voiceInputSection: some View {
        Section {
            Picker("Voice Input Mode", selection: $appState.recordingState.mode) {
                ForEach(RecordingMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            Picker("Language", selection: $appState.transcriptionPreferences.transcriptionLanguage) {
                ForEach(TranscriptionLanguage.choices) { language in
                    Text(language.title).tag(language.code)
                }
            }
        } header: {
            Text("Voice Input")
        } footer: {
            Text("Applies to every model and provider. Automatic detection is unreliable on short phrases — pick your language if dictation comes back in the wrong one.")
        }
    }

    @ViewBuilder
    private var permissionsSection: some View {
        Section {
            LabeledContent("Microphone") {
                Text(appState.voiceInputController.permissionStatus.title)
            }

            Button("Open Microphone Privacy Settings") {
                appState.openMicrophonePrivacySettings()
            }

            LabeledContent("Accessibility") {
                Text(appState.accessibilityPermissionStatus.rawValue)
            }

            Button("Open Accessibility Settings") {
                appState.openAccessibilityPrivacySettings()
            }
        } header: {
            Text("Permissions")
        } footer: {
            Text("Transcriptor records from the current system input device. Accessibility access is only required for inserting dictated text into other apps.")
        }
    }

    @ViewBuilder
    private var transcriptInsertionSection: some View {
        Section {
            Toggle("Insert transcript into active app", isOn: $appState.generalSettings.insertTranscriptIntoActiveApp)
            Toggle("Also copy transcript to clipboard", isOn: $appState.generalSettings.alsoCopyTranscriptToClipboard)
            Toggle("Restore previous clipboard after insertion", isOn: $appState.generalSettings.restoreClipboardAfterInsertion)
                .disabled(appState.generalSettings.alsoCopyTranscriptToClipboard)
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
                "Always show Dock icon",
                isOn: $appState.generalSettings.showDockIcon
            )

            Toggle(
                "Launch at login",
                isOn: Binding(
                    get: { appState.generalSettings.launchAtLoginEnabled },
                    set: { appState.setLaunchAtLoginEnabled($0) }
                )
            )
            .disabled(!appState.launchAtLoginStatus.canRegisterFromCurrentRuntime)

            Button("Open Login Items Settings") {
                appState.openLoginItemsSettings()
            }
        } header: {
            Text("Application")
        } footer: {
            Text(appState.launchAtLoginStatus.detail + " Without the Dock icon, Transcriptor lives in the menu bar and shows in the Dock only while its window is open. If both icons are hidden, open Transcriptor again from Spotlight or Finder to get the window back.")
        }
    }

    @ViewBuilder
    private var shortcutSection: some View {
        Section {
            LabeledContent("Global Shortcut") {
                HotkeyRecorderButton(configuration: $appState.recordingState.hotkey)
            }

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
        } header: {
            Text("Shortcut")
        } footer: {
            Text("Used to start and stop voice input while Transcriptor is running.")
        }
    }

    @ViewBuilder
    private var storageSections: some View {
        Section {
            LabeledContent("Audio") {
                Text(megabyteString(for: appState.storageUsage.audioBytes))
            }

            LabeledContent("Transcripts and metadata") {
                Text(megabyteString(for: appState.storageUsage.historyBytes + appState.storageUsage.metadataBytes))
            }

            if appState.storageUsage.modelBytes > 0 {
                LabeledContent("Model cache") {
                    Text(megabyteString(for: appState.storageUsage.modelBytes))
                        .foregroundStyle(.secondary)
                }
            }

            LabeledContent("Total") {
                Text(megabyteString(for: appState.storageUsage.totalIncludingModelsBytes))
            }

            Button("Clear History…", role: .destructive) {
                showClearHistoryConfirmation = true
            }
            .disabled(appState.historyStore.entries.isEmpty)
            .confirmationDialog(
                "Delete all history?",
                isPresented: $showClearHistoryConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) {
                    appState.deleteAllHistory()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes every saved transcript and its recorded audio from this Mac. This can't be undone. Downloaded models are not affected.")
            }
        } header: {
            Text("Usage")
        } footer: {
            Text("Everything Transcriptor keeps on this Mac. Model cache files can be removed individually from the Models page.")
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
