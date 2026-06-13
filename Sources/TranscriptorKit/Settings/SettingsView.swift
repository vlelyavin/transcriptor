import SwiftUI

/// The detail form for one settings pane. Settings live in the main window
/// sidebar (like System Settings), so this renders inside the main split view.
public struct SettingsPaneDetailView: View {
    @State private var openAIAPIKeyInput = ""
    @State private var groqAPIKeyInput = ""
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
            // Single catch-all for everything non-essential.
            settingsForm {
                recordingDetailSection
                overlaySection
                transcriptionSections
                storageSections
                cloudProviderSections
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
        case .models:
            settingsForm { transcriptionSections }
        case .storage:
            settingsForm { storageSections }
        case .cloudProviders:
            settingsForm { cloudProviderSections }
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

    @ViewBuilder
    private var transcriptionSections: some View {
        Section("Preferred Transcription Provider") {
            providerSelectionRow(
                title: "WhisperKit Local",
                subtitle: "Audio stays on this Mac.",
                isSelected: appState.transcriptionPreferences.preferredProviderID == "whisperkit-local",
                isEnabled: true
            ) {
                appState.selectPreferredLocalProvider("whisperkit-local")
            }

            providerSelectionRow(
                title: "Parakeet Local",
                subtitle: parakeetProviderSubtitle,
                isSelected: appState.transcriptionPreferences.preferredProviderID == "parakeet-local",
                isEnabled: appState.parakeetModelManager.inventory.values.contains {
                    switch $0.state {
                    case .unavailable:
                        false
                    default:
                        true
                    }
                }
            ) {
                appState.selectPreferredLocalProvider("parakeet-local")
            }

            ForEach(appState.providerCatalog.providers) { provider in
                let runtimeState = appState.providerRuntimeState(for: provider)
                providerSelectionRow(
                    title: provider.name,
                    subtitle: runtimeState.message,
                    isSelected: appState.transcriptionPreferences.preferredProviderID == provider.id,
                    isEnabled: runtimeState.isSelectable
                ) {
                    appState.transcriptionPreferences.preferredProviderID = provider.id
                }
            }
        }

        Section {
            Picker("Preferred Local Provider", selection: $appState.transcriptionPreferences.preferredLocalProviderID) {
                Text("WhisperKit Local").tag("whisperkit-local")
                Text("Parakeet Local").tag("parakeet-local")
            }
            .onChange(of: appState.transcriptionPreferences.preferredLocalProviderID) { _, newValue in
                appState.selectPreferredLocalProvider(newValue)
            }
        } header: {
            Text("Local Provider")
        } footer: {
            Text("Choose which local runtime should be preferred when you transcribe without selecting a cloud provider.")
        }

        Section {
            // Only downloaded models can be selected; the binding routes through
            // selectLocalModel which rejects undownloaded models.
            Picker(
                "Selected Transcription Model",
                selection: Binding(
                    get: { appState.transcriptionPreferences.selectedModelID },
                    set: { appState.selectLocalModel($0) }
                )
            ) {
                if readyLocalModels.isEmpty {
                    Text("No downloaded models").tag(appState.transcriptionPreferences.selectedModelID)
                } else {
                    ForEach(readyLocalModels) { model in
                        Text(model.name).tag(model.id)
                    }
                }
            }
            .disabled(readyLocalModels.isEmpty)
        } header: {
            Text("Default Local Model")
        } footer: {
            if readyLocalModels.isEmpty {
                Text("Download a model below to choose it here.")
            } else if let selectedModel = appState.selectedModel {
                Text(selectedModel.availability.message)
            }
        }

        Section {
            Toggle(
                "Auto-transcribe after recording or import",
                isOn: Binding(
                    get: { appState.transcriptionPreferences.autoTranscribeAfterCapture && appState.canEnableAutoTranscribe },
                    set: { appState.transcriptionPreferences.autoTranscribeAfterCapture = $0 && appState.canEnableAutoTranscribe }
                )
            )
            .disabled(!appState.canEnableAutoTranscribe)

            if let provider = appState.preferredCloudProvider {
                Label(provider.privacySummary, systemImage: "icloud")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Automation")
        } footer: {
            if !appState.canEnableAutoTranscribe {
                Text("Download a transcription model to enable automatic transcription.")
            } else if let statusMessage = appState.whisperModelManager.statusMessage {
                Text(statusMessage)
            }
        }
    }

    private var readyLocalModels: [ModelDescriptor] {
        appState.modelCatalog.localModels.filter { appState.readyLocalModelIDs.contains($0.id) }
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
    private var cloudProviderSections: some View {
        if let provider = appState.providerCatalog.providers.first(where: { $0.id == "openai" }) {
            providerConfigurationSection(
                provider: provider,
                modelID: $appState.providerSettings.openAIModelID,
                privacyConsent: $appState.providerSettings.openAIPrivacyAcknowledged,
                apiKeyInput: $openAIAPIKeyInput
            )
        }

        if let provider = appState.providerCatalog.providers.first(where: { $0.id == "groq" }) {
            providerConfigurationSection(
                provider: provider,
                modelID: $appState.providerSettings.groqModelID,
                privacyConsent: $appState.providerSettings.groqPrivacyAcknowledged,
                apiKeyInput: $groqAPIKeyInput
            )
        }
    }

    @ViewBuilder
    private var privacySection: some View {
        Section("Privacy") {
            Label("Local WhisperKit transcription keeps audio on this Mac. Transcriptor does not upload recording or import audio for local runs.", systemImage: "lock.shield")
            Label("Parakeet Local uses FluidAudio Core ML bundles downloaded from Hugging Face and keeps transcription on this Mac.", systemImage: "waveform.badge.mic")
            Label("Model downloads come from public model repositories and stay in Application Support.", systemImage: "square.and.arrow.down")
            Label("OpenAI and Groq only send audio after you enable the provider, store an API key in Keychain, and acknowledge the privacy warning.", systemImage: "key")
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

    private func providerConfigurationSection(
        provider: ProviderDescriptor,
        modelID: Binding<String>,
        privacyConsent: Binding<Bool>,
        apiKeyInput: Binding<String>
    ) -> some View {
        let runtimeState = appState.providerRuntimeState(for: provider)
        let validationState = appState.providerCredentialValidationStates[provider.id] ?? .idle
        let hasStoredKey = appState.hasStoredAPIKey(for: provider.id)
        let keyInputEmpty = apiKeyInput.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return Section {
            // Status row reads like a native availability indicator: a colored
            // dot plus a short state label, with the detail message beneath.
            LabeledContent {
                HStack(spacing: 6) {
                    Circle()
                        .fill(providerRuntimeColor(runtimeState))
                        .frame(width: 7, height: 7)
                    Text(runtimeState.title)
                        .foregroundStyle(.secondary)
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Status")
                    Text(runtimeState.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            LabeledContent("Model ID") {
                TextField("Model ID", text: modelID)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: 230)
            }

            Toggle(isOn: privacyConsent) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Send audio to \(provider.name)")
                    Text("Required before any audio leaves this Mac for \(provider.name).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            LabeledContent {
                SecureField(hasStoredKey ? "Stored in Keychain — enter to replace" : "Enter API key", text: apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: 230)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("API Key")
                    Label(
                        hasStoredKey ? "Stored in Keychain" : "No key stored",
                        systemImage: hasStoredKey ? "checkmark.shield" : "key.slash"
                    )
                    .font(.caption)
                    .foregroundStyle(hasStoredKey ? Color.green : Color.secondary)
                }
            }

            HStack(spacing: 8) {
                Button("Save") {
                    appState.saveAPIKey(apiKeyInput.wrappedValue, for: provider.id)
                    apiKeyInput.wrappedValue = ""
                }
                .disabled(keyInputEmpty)

                Button("Remove") {
                    appState.removeAPIKey(for: provider.id)
                }
                .disabled(!hasStoredKey)

                Button("Test") {
                    appState.testAPIKey(for: provider.id)
                }
                .disabled(!hasStoredKey)

                Button("Reset") {
                    apiKeyInput.wrappedValue = ""
                    appState.resetCloudProvider(provider.id)
                }
                .help("Reset \(provider.name): clears the key, consent, and model.")
            }

            if let validationMessage = validationState.message {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(validationColor(validationState))
            }
        } header: {
            Text(provider.name)
        } footer: {
            Text(provider.summary)
        }
    }

    private func providerSelectionRow(
        title: String,
        subtitle: String,
        isSelected: Bool,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                RadioIndicator(isSelected: isSelected)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
    }

    private func providerRuntimeColor(_ state: ProviderRuntimeState) -> Color {
        switch state {
        case .ready:
            .green
        case .disabled:
            .secondary
        case .missingAPIKey, .privacyConsentRequired:
            .orange
        case .unavailable:
            .red
        }
    }

    private func validationColor(_ state: ProviderCredentialValidationState) -> Color {
        switch state {
        case .idle:
            .secondary
        case .testing:
            .orange
        case .succeeded:
            .green
        case .failed:
            .red
        }
    }

    private func megabyteString(for bytes: Int64) -> String {
        String(format: "%.2f MB", Double(bytes) / 1_048_576)
    }

    private var parakeetProviderSubtitle: String {
        if appState.parakeetModelManager.inventory.values.contains(where: {
            switch $0.state {
            case .unavailable:
                false
            default:
                true
            }
        }) {
            return "Audio stays on this Mac. Uses a local Core ML Parakeet backend."
        }

        return "Requires Apple Silicon for the current Core ML backend."
    }
}

/// A radio button drawn to match the native macOS control: a bordered well when
/// off, an accent-filled disc with a small white center when on. Used for the
/// vertical "Preferred Transcription Provider" radio group, where per-row
/// disabling and subtitles rule out a plain `Picker(.radioGroup)`.
struct RadioIndicator: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                .overlay {
                    Circle()
                        .strokeBorder(
                            isSelected ? Color.clear : Color(nsColor: .separatorColor),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.07), radius: 0.5, y: 0.5)

            if isSelected {
                Circle()
                    .fill(.white)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(width: 14, height: 14)
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
