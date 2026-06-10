import SwiftUI

public struct SettingsView: View {
    @State private var searchText = ""
    @State private var openAIAPIKeyInput = ""
    @State private var groqAPIKeyInput = ""
    @Bindable private var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 700

            Group {
                if compact {
                    compactSettingsLayout
                } else {
                    wideSettingsLayout
                }
            }
            .background(Color(nsColor: .underPageBackgroundColor))
            .onAppear {
                if !compact, appState.selectedSettingsPane == nil {
                    appState.selectedSettingsPane = .general
                }
            }
        }
        .onChange(of: filteredPanes) { _, panes in
            guard let selectedPane = appState.selectedSettingsPane else {
                return
            }

            if panes.contains(selectedPane) {
                return
            }

            appState.selectedSettingsPane = panes.first
        }
        .navigationTitle("Settings")
    }

    private var compactSettingsLayout: some View {
        Group {
            if let pane = appState.selectedSettingsPane, filteredPanes.contains(pane) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Button {
                            appState.selectedSettingsPane = nil
                        } label: {
                            Label("All Settings", systemImage: "chevron.backward")
                        }
                        .buttonStyle(.borderless)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    currentPaneView(for: pane)
                }
            } else if filteredPanes.isEmpty {
                ContentUnavailableView(
                    "No Matching Settings",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term.")
                )
            } else {
                List(filteredPanes) { pane in
                    Button {
                        appState.selectedSettingsPane = pane
                    } label: {
                        HStack {
                            Label(pane.title, systemImage: pane.systemImage)

                            Spacer()

                            Image(systemName: "chevron.forward")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset(alternatesRowBackgrounds: false))
                .searchable(text: $searchText, placement: .automatic, prompt: "Search settings")
            }
        }
    }

    private var wideSettingsLayout: some View {
        HStack(spacing: 0) {
            List(filteredPanes, selection: $appState.selectedSettingsPane) { pane in
                Label(pane.title, systemImage: pane.systemImage)
                    .tag(Optional(pane))
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText, placement: .automatic, prompt: "Search settings")
            .frame(width: 210)

            Divider()

            Group {
                if let pane = resolvedPane {
                    currentPaneView(for: pane)
                } else {
                    ContentUnavailableView(
                        "No Matching Settings",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term.")
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .underPageBackgroundColor))
        }
    }

    @ViewBuilder
    private func currentPaneView(for pane: SettingsPane) -> some View {
        switch pane {
        case .general:
            settingsForm(pane: .general) {
                Section("Application") {
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

                    Text(appState.launchAtLoginStatus.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("Refresh Status") {
                            appState.refreshLaunchAtLoginStatus()
                        }

                        Button("Open Login Items Settings") {
                            appState.openLoginItemsSettings()
                        }
                    }
                }
            }
        case .recording:
            settingsForm(pane: .recording) {
                Section("Input Mode") {
                    Picker("Voice Input Mode", selection: $appState.recordingState.mode) {
                        ForEach(RecordingMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    Toggle("Save original audio", isOn: $appState.recordingState.savesAudioLocally)

                    if !appState.recordingState.savesAudioLocally {
                        Text("This preference is currently partial. Dictation audio is still kept locally for pending transcription and reliable re-transcription until cleanup rules are fully implemented.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
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

                    Button("Open Microphone Privacy Settings") {
                        appState.openMicrophonePrivacySettings()
                    }
                }

                Section("Transcript Insertion") {
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

                    Text("Accessibility access is only required for inserting dictated text into other apps. If access is unavailable, Transcriptor still saves the transcript to history and can copy it to the clipboard instead.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if appState.generalSettings.insertTranscriptIntoActiveApp {
                        Text("Live dictation is transcribed immediately when this setting is on so the transcript can be inserted back into the original app.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

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
        case .keyboardShortcut:
            settingsForm(pane: .keyboardShortcut) {
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

                    LabeledContent("Accessibility Permission") {
                        Text("Not Required")
                            .foregroundStyle(.secondary)
                    }

                    Text("Transcriptor uses Carbon hotkey registration, so it normally does not need Accessibility permission just to start or stop recording.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Restore Recommended Shortcut") {
                        appState.resetHotkeyToRecommendedDefault()
                    }
                }

                Section("Menu Shortcuts") {
                    LabeledContent("Import Audio") {
                        Text("Cmd + Shift + I")
                            .font(.system(.body, design: .monospaced))
                    }

                    LabeledContent("Search History") {
                        Text("Cmd + F")
                            .font(.system(.body, design: .monospaced))
                    }

                    LabeledContent("Settings") {
                        Text("Cmd + ,")
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
        case .overlay:
            settingsForm(pane: .overlay) {
                Section("Appearance") {
                    Toggle("Show recording overlay", isOn: $appState.overlayState.isEnabled)
                    Toggle("Use non-activating overlay", isOn: $appState.overlayState.isNonActivating)
                    Toggle("Show live audio indicator", isOn: $appState.overlayState.showsLiveAudioIndicator)

                    Picker("Overlay Position", selection: $appState.overlayState.position) {
                        ForEach(OverlayPosition.allCases) { position in
                            Text(position.title).tag(position)
                        }
                    }

                    Text("The overlay is non-activating by default so it stays above normal windows without stealing focus from the app you are dictating into.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Restore Overlay Defaults") {
                        appState.resetOverlayDefaults()
                    }
                }
            }
        case .models:
            settingsForm(pane: .models) {
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

                Section("Local Provider") {
                    Picker("Preferred Local Provider", selection: $appState.transcriptionPreferences.preferredLocalProviderID) {
                        Text("WhisperKit Local").tag("whisperkit-local")
                        Text("Parakeet Local").tag("parakeet-local")
                    }
                    .onChange(of: appState.transcriptionPreferences.preferredLocalProviderID) { _, newValue in
                        appState.selectPreferredLocalProvider(newValue)
                    }

                    Text("Choose which local runtime should be preferred when you transcribe without selecting a cloud provider.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Default Local Model") {
                    Picker("Selected Transcription Model", selection: $appState.transcriptionPreferences.selectedModelID) {
                        ForEach(appState.modelCatalog.localModels) { model in
                            Text(model.name).tag(model.id)
                        }
                    }
                    .onChange(of: appState.transcriptionPreferences.selectedModelID) { _, newValue in
                        appState.selectLocalModel(newValue)
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

                    if let provider = appState.preferredCloudProvider {
                        Label(provider.privacySummary, systemImage: "icloud")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if let statusMessage = appState.whisperModelManager.statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .storage:
            settingsForm(pane: .storage) {
                Section("Retention") {
                    Stepper(value: $appState.storageSettings.capMegabytes, in: 256...10_240, step: 256) {
                        Text("History storage limit: \(appState.storageSettings.capMegabytes) MB")
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
        case .cloudProviders:
            settingsForm(pane: .cloudProviders) {
                Section("Providers") {
                    if let provider = appState.providerCatalog.providers.first(where: { $0.id == "openai" }) {
                        providerConfigurationDisclosure(
                            provider: provider,
                            isEnabled: $appState.providerSettings.openAIEnabled,
                            modelID: $appState.providerSettings.openAIModelID,
                            privacyConsent: $appState.providerSettings.openAIPrivacyAcknowledged,
                            apiKeyInput: $openAIAPIKeyInput
                        )
                    }

                    if let provider = appState.providerCatalog.providers.first(where: { $0.id == "groq" }) {
                        providerConfigurationDisclosure(
                            provider: provider,
                            isEnabled: $appState.providerSettings.groqEnabled,
                            modelID: $appState.providerSettings.groqModelID,
                            privacyConsent: $appState.providerSettings.groqPrivacyAcknowledged,
                            apiKeyInput: $groqAPIKeyInput
                        )
                    }
                }

                Section {
                    Button("Reset Cloud Provider Defaults") {
                        appState.resetCloudProviderDefaults()
                    }
                }
            }
        case .privacy:
            settingsForm(pane: .privacy) {
                Section("Current Behavior") {
                    Label("Local WhisperKit transcription keeps audio on this Mac. Transcriptor does not upload recording or import audio for local runs.", systemImage: "lock.shield")
                    Label("Parakeet Local uses FluidAudio Core ML bundles downloaded from Hugging Face and keeps transcription on this Mac.", systemImage: "waveform.badge.mic")
                    Label("Model downloads come from public model repositories and stay in Application Support.", systemImage: "square.and.arrow.down")
                    Label("OpenAI and Groq only send audio after you enable the provider, store an API key in Keychain, and acknowledge the privacy warning.", systemImage: "key")
                    Label("Imports use standard macOS user-granted file access through the open panel or drag and drop, then copies are stored under Application Support for durable local history.", systemImage: "folder.badge.plus")
                    Label("WebM import is still blocked until a reliable decoder/transcoder is integrated.", systemImage: "exclamationmark.triangle")
                }
            }
        }
    }

    private func settingsForm<Content: View>(
        pane: SettingsPane,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(pane.title)
                    .font(.title2.weight(.semibold))

                Text(pane.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)

            Form {
                content()
            }
            .formStyle(.grouped)
        }
    }

    private var filteredPanes: [SettingsPane] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SettingsPane.allCases
        }

        return SettingsPane.allCases.filter { pane in
            let haystack = ([pane.title, pane.subtitle] + pane.searchTokens).joined(separator: " ")
            return haystack.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var resolvedPane: SettingsPane? {
        if let selectedPane = appState.selectedSettingsPane, filteredPanes.contains(selectedPane) {
            return selectedPane
        }

        return filteredPanes.first
    }

    private func providerConfigurationDisclosure(
        provider: ProviderDescriptor,
        isEnabled: Binding<Bool>,
        modelID: Binding<String>,
        privacyConsent: Binding<Bool>,
        apiKeyInput: Binding<String>
    ) -> some View {
        let runtimeState = appState.providerRuntimeState(for: provider)
        let validationState = appState.providerCredentialValidationStates[provider.id] ?? .idle

        return DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable \(provider.name)", isOn: isEnabled)

                LabeledContent("Model ID") {
                    TextField("Model ID", text: modelID)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 240)
                }

                Toggle("I understand audio is sent to \(provider.name)", isOn: privacyConsent)

                HStack(spacing: 10) {
                    SecureField("API key", text: apiKeyInput)
                        .textFieldStyle(.roundedBorder)

                    Button("Save") {
                        appState.saveAPIKey(apiKeyInput.wrappedValue, for: provider.id)
                        apiKeyInput.wrappedValue = ""
                    }
                    .disabled(apiKeyInput.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Remove", role: .destructive) {
                        appState.removeAPIKey(for: provider.id)
                    }
                    .disabled(!appState.hasStoredAPIKey(for: provider.id))

                    Button("Test") {
                        appState.testAPIKey(for: provider.id)
                    }
                    .disabled(!appState.hasStoredAPIKey(for: provider.id))
                }

                if appState.hasStoredAPIKey(for: provider.id) {
                    Label("API key stored in Keychain", systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label("No API key stored", systemImage: "key.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(runtimeState.message)
                    .font(.caption)
                    .foregroundStyle(providerRuntimeColor(runtimeState))

                if let validationMessage = validationState.message {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(validationColor(validationState))
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(provider.name)
                    Text(provider.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(runtimeState.title)
                    .font(.caption)
                    .foregroundStyle(providerRuntimeStatusStyle(runtimeState))
            }
        }
    }

    private func providerRuntimeStatusStyle(_ state: ProviderRuntimeState) -> AnyShapeStyle {
        switch state {
        case .ready, .disabled:
            AnyShapeStyle(.secondary)
        case .missingAPIKey, .privacyConsentRequired:
            AnyShapeStyle(Color.orange)
        case .unavailable:
            AnyShapeStyle(Color.red)
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
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.6)
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

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(appState: .preview)
            .frame(width: 1080, height: 720)
    }
}
#endif
