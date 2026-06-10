import SwiftUI

/// The standalone Settings window (Cmd+, / gear button), styled after System
/// Settings: searchable category sidebar with colored icons + grouped detail.
public struct SettingsWindowView: View {
    @State private var searchText = ""
    @State private var openAIAPIKeyInput = ""
    @State private var groqAPIKeyInput = ""
    @Bindable private var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                searchField
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .padding(.bottom, 4)

                List(selection: $appState.selectedSettingsPane) {
                    ForEach(filteredPanes) { pane in
                        Label {
                            Text(pane.title)
                        } icon: {
                            SidebarIconView(systemImage: pane.sidebarFillSymbol, tint: pane.sidebarTint)
                        }
                        .tag(Optional(pane))
                    }

                    if filteredPanes.isEmpty {
                        Text("No results")
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
            .background {
                NativeSidebarMaterial()
                    .ignoresSafeArea()
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 215, max: 230)
        } detail: {
            Group {
                if let pane = resolvedPane {
                    currentPaneView(for: pane)
                        .navigationTitle(pane.title)
                } else {
                    ContentUnavailableView(
                        "No Matching Settings",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term.")
                    )
                    .navigationTitle("Settings")
                }
            }
        }
        .frame(minWidth: 715, idealWidth: 760, minHeight: 470, idealHeight: 560)
        .onChange(of: filteredPanes) { _, panes in
            guard let selectedPane = appState.selectedSettingsPane else {
                return
            }

            if !panes.contains(selectedPane) {
                appState.selectedSettingsPane = panes.first
            }
        }
        .onAppear {
            if appState.selectedSettingsPane == nil {
                appState.selectedSettingsPane = .general
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    @ViewBuilder
    private func currentPaneView(for pane: SettingsPane) -> some View {
        switch pane {
        case .general:
            settingsForm {
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
            settingsForm {
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
            settingsForm {
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
        case .overlay:
            settingsForm {
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
            settingsForm {
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
                        Text(selectedModel.availability.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
            settingsForm {
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
            settingsForm {
                if let provider = appState.providerCatalog.providers.first(where: { $0.id == "openai" }) {
                    providerConfigurationSection(
                        provider: provider,
                        isEnabled: $appState.providerSettings.openAIEnabled,
                        modelID: $appState.providerSettings.openAIModelID,
                        privacyConsent: $appState.providerSettings.openAIPrivacyAcknowledged,
                        apiKeyInput: $openAIAPIKeyInput
                    )
                }

                if let provider = appState.providerCatalog.providers.first(where: { $0.id == "groq" }) {
                    providerConfigurationSection(
                        provider: provider,
                        isEnabled: $appState.providerSettings.groqEnabled,
                        modelID: $appState.providerSettings.groqModelID,
                        privacyConsent: $appState.providerSettings.groqPrivacyAcknowledged,
                        apiKeyInput: $groqAPIKeyInput
                    )
                }

                Section {
                    Button("Reset Cloud Provider Defaults") {
                        appState.resetCloudProviderDefaults()
                    }
                }
            }
        case .privacy:
            settingsForm {
                Section("Current Behavior") {
                    Label("Local WhisperKit transcription keeps audio on this Mac. Transcriptor does not upload recording or import audio for local runs.", systemImage: "lock.shield")
                    Label("Parakeet Local uses FluidAudio Core ML bundles downloaded from Hugging Face and keeps transcription on this Mac.", systemImage: "waveform.badge.mic")
                    Label("Model downloads come from public model repositories and stay in Application Support.", systemImage: "square.and.arrow.down")
                    Label("OpenAI and Groq only send audio after you enable the provider, store an API key in Keychain, and acknowledge the privacy warning.", systemImage: "key")
                    Label("Imports use standard macOS user-granted file access through the open panel or drag and drop, then copies are stored under Application Support for durable local history.", systemImage: "folder.badge.plus")
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

    private func providerConfigurationSection(
        provider: ProviderDescriptor,
        isEnabled: Binding<Bool>,
        modelID: Binding<String>,
        privacyConsent: Binding<Bool>,
        apiKeyInput: Binding<String>
    ) -> some View {
        let runtimeState = appState.providerRuntimeState(for: provider)
        let validationState = appState.providerCredentialValidationStates[provider.id] ?? .idle
        let hasStoredKey = appState.hasStoredAPIKey(for: provider.id)
        let keyInputEmpty = apiKeyInput.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return Section {
            Toggle("Enable \(provider.name)", isOn: isEnabled)

            LabeledContent("Model ID") {
                TextField("Model ID", text: modelID)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: 230)
            }

            Toggle("I understand audio is sent to \(provider.name)", isOn: privacyConsent)

            LabeledContent("API Key") {
                SecureField(hasStoredKey ? "Stored in Keychain — enter to replace" : "Enter API key", text: apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: 230)
            }

            HStack(spacing: 8) {
                Button("Save") {
                    appState.saveAPIKey(apiKeyInput.wrappedValue, for: provider.id)
                    apiKeyInput.wrappedValue = ""
                }
                .disabled(keyInputEmpty)

                Button("Remove", role: .destructive) {
                    appState.removeAPIKey(for: provider.id)
                }
                .disabled(!hasStoredKey)

                Button("Test") {
                    appState.testAPIKey(for: provider.id)
                }
                .disabled(!hasStoredKey)

                Spacer()

                Label(
                    hasStoredKey ? "Key stored in Keychain" : "No key stored",
                    systemImage: hasStoredKey ? "checkmark.shield" : "key.slash"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if !hasStoredKey, keyInputEmpty {
                Text("Enter an API key above to enable Save. Test and Remove become available once a key is stored in Keychain.")
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
            .contentShape(Rectangle())
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
struct SettingsWindowView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsWindowView(appState: .preview)
            .frame(width: 760, height: 560)
    }
}
#endif
