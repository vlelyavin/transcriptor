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
                Section {
                    ForEach(section.models) { model in
                        localModelRow(model)
                    }
                } header: {
                    Text(section.title)
                } footer: {
                    Text(section.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("Cloud transcription is optional. A provider only becomes available after you turn on audio sending, store an API key, and the key passes a test — until then, everything stays on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Cloud Models")
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

    /// One downloadable local model. The model name is on the main line with a
    /// small red/green status indicator beneath it (red = not downloaded, green =
    /// downloaded and usable), the action button on the trailing edge, and the
    /// weight/language/speed metadata in a key/value table styled like the
    /// Current Selection rows. No "Not Downloaded"/"Loaded" text statuses — the
    /// dot and the available action already make the state clear.
    private func localModelRow(_ model: ModelDescriptor) -> some View {
        let inventoryItem = inventoryItem(for: model)
        let state = inventoryItem.state
        let isSelected = appState.transcriptionPreferences.selectedModelID == model.id
            && appState.transcriptionPreferences.preferredProviderID == model.localProviderID

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name + (model.accentBadgeLabel.map { " (\($0))" } ?? ""))

                    statusIndicator(color: localStateColor(state), label: localStateAccessibilityLabel(state))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .help("Selected as the preferred local model")
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

            // Metadata table — same key/value treatment as Current Selection.
            Group {
                LabeledContent("Size") { Text(model.downloadSizeDescription) }
                LabeledContent("Language") { Text(model.languageScopeLabel) }
                LabeledContent("Speed") { Text(model.speedDescription) }
                LabeledContent("Accuracy") { Text(model.accuracyDescription) }
                LabeledContent("Best for") { Text(model.intendedUseLabel) }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 2)
    }

    /// A small colored status dot with no visible text label — the action button
    /// and metadata carry the rest of the meaning, matching native lists.
    private func statusIndicator(color: Color, label: String) -> some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
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
            // 1. Top line: Status (red/green indicator) + the consent switch.
            LabeledContent {
                HStack(spacing: 12) {
                    statusIndicator(color: providerStateColor(runtimeState), label: runtimeState.title)
                    Text(runtimeState.title)
                        .font(.caption)
                        .foregroundStyle(providerStateStyle(runtimeState))

                    Toggle("Send audio to \(provider.name)", isOn: privacyConsent)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .help("Send audio to \(provider.name). Required before any audio leaves this Mac.")
                }
            } label: {
                Text("Status")
            }

            // 2. Below status: connection status, then the editable details.
            Text(runtimeState.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LabeledContent("Model ID") {
                TextField("Model ID", text: modelID)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    .frame(width: 230)
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
        } header: {
            Text(provider.name)
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

    private func localStateAccessibilityLabel(_ state: LocalModelState) -> String {
        switch state {
        case .downloaded, .loaded:
            "Downloaded"
        case .notDownloaded:
            "Not downloaded"
        case .downloading:
            "Downloading"
        case .loading:
            "Loading"
        case .deleting:
            "Deleting"
        case .failed:
            "Error"
        case .unavailable:
            "Unavailable"
        }
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

    private func providerStateStyle(_ state: ProviderRuntimeState) -> AnyShapeStyle {
        state.isReady ? AnyShapeStyle(Color.green) : AnyShapeStyle(.secondary)
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
