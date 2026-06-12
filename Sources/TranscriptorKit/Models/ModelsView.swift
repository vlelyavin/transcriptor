import SwiftUI

public struct ModelsView: View {
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

                LabeledContent("Selected local model") {
                    Text(appState.selectedModel?.name ?? "None selected")
                }

                LabeledContent("Ready local models") {
                    Text("\(appState.readyLocalModelIDs.count)")
                }

                if let whisperStatus = appState.whisperModelManager.statusMessage {
                    Text(whisperStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let parakeetStatus = appState.parakeetModelManager.statusMessage {
                    Text(parakeetStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                ForEach(appState.providerCatalog.providers) { provider in
                    providerRow(provider)
                }
            } header: {
                Text("Cloud Models")
            } footer: {
                Text("Cloud transcription is optional and only runs after explicit setup.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Models")
    }

    private func localModelRow(_ model: ModelDescriptor) -> some View {
        let inventoryItem = inventoryItem(for: model)
        let isSelected = appState.transcriptionPreferences.selectedModelID == model.id
            && appState.transcriptionPreferences.preferredProviderID == model.localProviderID

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name + (model.accentBadgeLabel.map { " (\($0))" } ?? ""))

                    Text("\(model.downloadSizeDescription) • \(model.engineLabel) • \(model.languageScopeLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                stateText(for: inventoryItem.state)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .help("Selected as the preferred local model")
                } else {
                    Button("Select") {
                        appState.selectLocalModel(model.id)
                    }
                    .controlSize(.small)
                    .disabled(!isSelectable(inventoryItem.state))
                }

                actionButton(for: model, state: inventoryItem.state)
                    .controlSize(.small)

                if canDelete(inventoryItem.state) {
                    Button {
                        delete(model)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .controlSize(.small)
                    .help("Delete downloaded model files")
                }
            }

            if let progress = inventoryItem.state.progressValue {
                ProgressView(value: progress)
                    .controlSize(.small)
            }

            if let detailMessage = inventoryItem.state.detailMessage {
                Text(detailMessage)
                    .font(.caption)
                    .foregroundStyle(stateMessageStyle(for: inventoryItem.state))
            }

            // Details are always shown — no disclosure arrow to expand.
            VStack(alignment: .leading, spacing: 4) {
                LabeledContent("Speed") { Text(model.speedDescription) }
                LabeledContent("Accuracy") { Text(model.accuracyDescription) }
                LabeledContent("Best for") { Text(model.intendedUseLabel) }

                Text(model.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(model.availability.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            .padding(.top, 4)
        }
        .padding(.vertical, 2)
    }

    private func providerRow(_ provider: ProviderDescriptor) -> some View {
        let runtimeState = appState.providerRuntimeState(for: provider)
        let validationState = appState.providerCredentialValidationStates[provider.id] ?? .idle

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.name)

                    Text(provider.modelLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(runtimeState.title)
                    .font(.caption)
                    .foregroundStyle(providerStateStyle(runtimeState))

                if runtimeState.isSelectable {
                    if appState.transcriptionPreferences.preferredProviderID == provider.id {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .help("Selected as the preferred provider")
                    } else {
                        Button("Select") {
                            appState.transcriptionPreferences.preferredProviderID = provider.id
                        }
                        .controlSize(.small)
                    }
                } else {
                    Button("Set Up…") {
                        appState.openSettings(pane: .cloudProviders)
                    }
                    .controlSize(.small)
                }
            }

            if let validationMessage = validationState.message {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(validationStateStyle(validationState))
            } else {
                Text(runtimeState.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func isSelectable(_ state: LocalModelState) -> Bool {
        // Only a downloaded (or loaded) model can be selected — you cannot pick a
        // model that isn't on disk yet.
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
        case .loaded:
            Button("Loaded") {}
                .disabled(true)
        case .downloading, .loading, .deleting:
            Button(state.title) {}
                .disabled(true)
        case .unavailable:
            Button("Unavailable") {}
                .disabled(true)
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

    private func stateText(for state: LocalModelState) -> some View {
        Text(state.title)
            .font(.caption)
            .foregroundStyle(stateMessageStyle(for: state))
    }

    private func stateMessageStyle(for state: LocalModelState) -> AnyShapeStyle {
        switch state {
        case .failed, .unavailable:
            AnyShapeStyle(Color.red)
        default:
            AnyShapeStyle(.secondary)
        }
    }

    private var preferredProviderTitle: String {
        switch appState.transcriptionPreferences.preferredProviderID {
        case "parakeet-local":
            "Parakeet Local"
        case "whisperkit-local":
            "WhisperKit Local"
        default:
            appState.preferredCloudProvider?.name ?? "WhisperKit Local"
        }
    }

    private func providerStateStyle(_ state: ProviderRuntimeState) -> AnyShapeStyle {
        switch state {
        case .ready, .disabled:
            AnyShapeStyle(.secondary)
        case .missingAPIKey, .privacyConsentRequired:
            AnyShapeStyle(Color.orange)
        case .unavailable:
            AnyShapeStyle(Color.red)
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
