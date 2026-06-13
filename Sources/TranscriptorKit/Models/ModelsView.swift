import SwiftUI

public struct ModelsView: View {
    @State private var openAIAPIKeyInput = ""
    @State private var groqAPIKeyInput = ""
    @Bindable private var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        Form {
            Section("Current Selection") {
                LabeledContent("Preferred provider") {
                    Text(preferredProviderTitle)
                }

                LabeledContent("Selected model") {
                    Text(appState.selectedModel?.name ?? "None selected")
                }

                LabeledContent("Ready local models") {
                    Text("\(appState.readyLocalModelIDs.count)")
                }

                Toggle(
                    "Auto-transcribe after recording or import",
                    isOn: Binding(
                        get: { appState.transcriptionPreferences.autoTranscribeAfterCapture && appState.canEnableAutoTranscribe },
                        set: { appState.transcriptionPreferences.autoTranscribeAfterCapture = $0 && appState.canEnableAutoTranscribe }
                    )
                )
                .disabled(!appState.canEnableAutoTranscribe)
            }

            ForEach(appState.modelCatalog.sections) { section in
                // Each model is its own grouped card so models are clearly
                // separated with native spacing. The catalog group title sits
                // above the first card and its description below the last.
                ForEach(Array(section.models.enumerated()), id: \.element.id) { index, model in
                    Section {
                        localModelRows(model)
                    } header: {
                        if index == 0 {
                            Text(section.title)
                        }
                    } footer: {
                        if index == section.models.count - 1 {
                            Text(section.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let openAI = appState.providerCatalog.providers.first(where: { $0.id == "openai" }) {
                cloudProviderSection(
                    provider: openAI,
                    modelID: $appState.providerSettings.openAIModelID,
                    privacyConsent: $appState.providerSettings.openAIPrivacyAcknowledged,
                    apiKeyInput: $openAIAPIKeyInput
                )
            }

            if let groq = appState.providerCatalog.providers.first(where: { $0.id == "groq" }) {
                cloudProviderSection(
                    provider: groq,
                    modelID: $appState.providerSettings.groqModelID,
                    privacyConsent: $appState.providerSettings.groqPrivacyAcknowledged,
                    apiKeyInput: $groqAPIKeyInput
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Models")
    }

    // MARK: - Local model rows

    /// One downloadable local model, emitted as the rows of its own grouped
    /// `Section`. The header row carries the name, an enlarged red/green status
    /// dot with a text status beside it, a Select/Selected button, and
    /// download/delete actions. The Size/Language/Speed/Accuracy/Best-for
    /// metadata follow as individual section rows so the grouped form draws a
    /// native separator above Size and after every characteristic.
    @ViewBuilder
    private func localModelRows(_ model: ModelDescriptor) -> some View {
        let inventoryItem = inventoryItem(for: model)
        let state = inventoryItem.state
        let isSelected = appState.transcriptionPreferences.selectedModelID == model.id
            && appState.transcriptionPreferences.preferredProviderID == model.localProviderID

        HStack(alignment: .center, spacing: 10) {
            SidebarIconView(systemImage: modelIconSymbol(for: model), size: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.name + (model.accentBadgeLabel.map { " (\($0))" } ?? ""))

                HStack(spacing: 5) {
                    statusIndicator(color: localStateColor(state), label: localStatusLabel(state))
                    Text(localStatusLabel(state))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isSelected {
                // The selected model shows an inactive "Selected" button rather
                // than a bare checkmark, so the relationship to "Select" is clear.
                Button("Selected") {}
                    .controlSize(.small)
                    .disabled(true)
                    .help("This is the selected local model")
            } else if isSelectable(state) {
                Button("Select") {
                    appState.selectLocalModel(model.id)
                }
                .controlSize(.small)
            }

            actionButton(for: model, state: state)
                .controlSize(.small)

            if canDelete(state) {
                Button {
                    delete(model)
                } label: {
                    Image(systemName: "trash")
                }
                .controlSize(.small)
                .help("Delete downloaded model files")
            }
        }

        if let progress = state.progressValue {
            ProgressView(value: progress)
                .controlSize(.small)
        }

        if let detailMessage = state.detailMessage {
            Text(detailMessage)
                .font(.caption)
                .foregroundStyle(Color.red)
                .fixedSize(horizontal: false, vertical: true)
        }

        // Each metadata row is a direct child of the Section, so the grouped
        // form inserts a separator above Size and after every characteristic.
        LabeledContent("Size") { Text(model.downloadSizeDescription) }
        LabeledContent("Language") { Text(model.languageScopeLabel) }
        LabeledContent("Speed") { Text(model.speedDescription) }
        LabeledContent("Accuracy") { Text(model.accuracyDescription) }
        LabeledContent("Best for") { Text(model.intendedUseLabel) }
    }

    /// A colored status dot sized to match native macOS status indicators.
    private func statusIndicator(color: Color, label: String) -> some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .accessibilityLabel(label)
    }

    // MARK: - Cloud provider configuration

    /// Full inline configuration for one cloud provider, modeled on the native
    /// System Settings network panel: the top line carries the red/green status
    /// indicator and the "send audio" consent switch, and the remaining
    /// details (connection status, model ID, API key) sit below. The provider
    /// is only "Ready" — green — once consent, a stored key, and a passing key
    /// test are all in place. Details cannot be edited until consent is given.
    private func cloudProviderSection(
        provider: ProviderDescriptor,
        modelID: Binding<String>,
        privacyConsent: Binding<Bool>,
        apiKeyInput: Binding<String>
    ) -> some View {
        let runtimeState = appState.providerRuntimeState(for: provider)
        let validationState = appState.providerCredentialValidationStates[provider.id] ?? .idle
        let hasStoredKey = appState.hasStoredAPIKey(for: provider.id)
        let hasConsent = privacyConsent.wrappedValue
        let keyInputEmpty = apiKeyInput.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isTesting: Bool = {
            if case .testing = validationState { return true }
            return false
        }()

        return Section {
            // Header row mirrors the local model cards: an icon tile, the
            // provider name, and a status dot + requirement text beneath it.
            // The "send audio" consent switch sits on the trailing edge.
            HStack(alignment: .center, spacing: 10) {
                SidebarIconView(systemImage: providerIconSymbol(for: provider), size: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(provider.name)

                    HStack(spacing: 5) {
                        statusIndicator(color: providerStateColor(runtimeState), label: runtimeState.title)
                        Text(cloudStatusText(runtimeState))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                Toggle("Send audio to \(provider.name)", isOn: privacyConsent)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("Send audio to \(provider.name). Required before any audio leaves this Mac.")
            }

            LabeledContent {
                TextField("Model ID", text: modelID)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: 230)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Model ID")
                    Text(modelIDHint(for: provider))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .disabled(!hasConsent)

            LabeledContent {
                SecureField(hasStoredKey ? "Stored — enter to replace" : "Enter API key", text: apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: 230)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("API Key")
                    // Plain gray status text — no icons.
                    Text(hasStoredKey ? "Stored in Keychain" : "No key stored")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!hasConsent)

            HStack(spacing: 8) {
                Button("Save") {
                    appState.saveAPIKey(apiKeyInput.wrappedValue, for: provider.id)
                    apiKeyInput.wrappedValue = ""
                }
                .disabled(!hasConsent || keyInputEmpty)

                Button("Test") {
                    appState.testAPIKey(for: provider.id, enteredKey: apiKeyInput.wrappedValue)
                    apiKeyInput.wrappedValue = ""
                }
                .disabled(!hasConsent || (keyInputEmpty && !hasStoredKey) || isTesting)

                Button("Remove") {
                    appState.removeAPIKey(for: provider.id)
                }
                .disabled(!hasStoredKey)

                if runtimeState.isReady {
                    if appState.transcriptionPreferences.preferredProviderID == provider.id {
                        Label("Default", systemImage: "checkmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Set as Default") {
                            appState.transcriptionPreferences.preferredProviderID = provider.id
                        }
                    }
                }

                Spacer()

                Button("Reset") {
                    apiKeyInput.wrappedValue = ""
                    appState.resetCloudProvider(provider.id)
                }
                .help("Reset \(provider.name): clears the key, consent, and model.")
            }

            if let validationMessage = validationState.message {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(validationStateStyle(validationState))
                    .fixedSize(horizontal: false, vertical: true)
            }
        } footer: {
            Text(provider.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Local model helpers

    private func isSelectable(_ state: LocalModelState) -> Bool {
        switch state {
        case .downloaded, .loaded:
            true
        default:
            false
        }
    }

    @ViewBuilder
    private func actionButton(for model: ModelDescriptor, state: LocalModelState) -> some View {
        switch state {
        case .notDownloaded, .failed:
            Button("Download") {
                download(model)
            }
        case .downloaded:
            Button("Load") {
                load(model)
            }
        case .downloading, .loading, .deleting:
            // Transitional — the progress bar/spinner communicates the activity.
            ProgressView()
                .controlSize(.small)
        case .loaded:
            // Ready: the green dot and Select/✓ already convey usability.
            EmptyView()
        case .unavailable:
            EmptyView()
        }
    }

    private func inventoryItem(for model: ModelDescriptor) -> LocalModelInventoryItem {
        if model.isParakeetLocalModel {
            return appState.parakeetModelManager.item(for: model.id)
                ?? LocalModelInventoryItem(modelID: model.id, state: .notDownloaded)
        }

        return appState.whisperModelManager.item(for: model.id)
            ?? LocalModelInventoryItem(modelID: model.id, state: .notDownloaded)
    }

    private func download(_ model: ModelDescriptor) {
        if model.isParakeetLocalModel {
            appState.parakeetModelManager.download(model)
        } else {
            appState.whisperModelManager.download(model)
        }
    }

    private func load(_ model: ModelDescriptor) {
        if model.isParakeetLocalModel {
            appState.parakeetModelManager.load(model)
        } else {
            appState.whisperModelManager.load(model)
        }
    }

    private func delete(_ model: ModelDescriptor) {
        if model.isParakeetLocalModel {
            appState.parakeetModelManager.delete(model)
        } else {
            appState.whisperModelManager.delete(model)
        }
    }

    private func canDelete(_ state: LocalModelState) -> Bool {
        switch state {
        case .downloaded, .loaded, .failed:
            true
        default:
            false
        }
    }

    private func localStateColor(_ state: LocalModelState) -> Color {
        switch state {
        case .downloaded, .loaded:
            .green
        case .notDownloaded, .failed, .unavailable:
            .red
        case .downloading, .loading, .deleting:
            .secondary
        }
    }

    /// User-facing status shown next to the indicator dot.
    private func localStatusLabel(_ state: LocalModelState) -> String {
        switch state {
        case .loaded:
            "Ready"
        case .downloaded:
            "Downloaded"
        case .notDownloaded:
            "Not downloaded"
        case .downloading:
            "Downloading…"
        case .loading:
            "Loading…"
        case .deleting:
            "Removing…"
        case .failed:
            "Failed"
        case .unavailable:
            "Unavailable"
        }
    }

    /// Icon glyph for a local model's header tile, by engine family.
    private func modelIconSymbol(for model: ModelDescriptor) -> String {
        if model.isParakeetLocalModel {
            return "waveform.badge.mic"
        }
        return "waveform"
    }

    private var preferredProviderTitle: String {
        switch appState.transcriptionPreferences.preferredProviderID {
        case "parakeet-local":
            "Parakeet Local"
        case "whisperkit-local":
            "On-device (Whisper)"
        default:
            appState.preferredCloudProvider?.name ?? "On-device (Whisper)"
        }
    }

    // MARK: - Cloud provider styling

    private func providerStateColor(_ state: ProviderRuntimeState) -> Color {
        // Red for any not-ready state, green only when fully ready. No blue.
        state.isReady ? .green : .red
    }

    /// Icon glyph for a cloud provider's header tile.
    private func providerIconSymbol(for provider: ProviderDescriptor) -> String {
        "cloud"
    }

    /// The status text shown beneath a cloud provider's name: the current
    /// requirement to finish setup, or "Ready" once the provider is usable.
    private func cloudStatusText(_ state: ProviderRuntimeState) -> String {
        state.isReady ? "Ready" : state.message
    }

    /// A short, provider-specific hint on where to find a valid model ID.
    private func modelIDHint(for provider: ProviderDescriptor) -> String {
        switch provider.id {
        case "openai":
            "Find model IDs in the OpenAI dashboard under API → Models (e.g. gpt-4o-mini-transcribe)."
        case "groq":
            "Find model IDs on the Groq Console models page (e.g. whisper-large-v3)."
        default:
            "Use a transcription model ID from \(provider.name)'s documentation."
        }
    }

    private func validationStateStyle(_ state: ProviderCredentialValidationState) -> AnyShapeStyle {
        switch state {
        case .idle, .testing, .succeeded:
            AnyShapeStyle(.secondary)
        case .failed:
            AnyShapeStyle(Color.red)
        }
    }
}
