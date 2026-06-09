import SwiftUI

public struct ModelsView: View {
    @Bindable private var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Models")
                        .font(.largeTitle.weight(.semibold))

                    Text("Choose the local runtime you want ready on this Mac, then keep cloud providers honest about privacy and setup.")
                        .foregroundStyle(.secondary)
                }

                SectionCard(
                    title: "Current Selection",
                    subtitle: "Downloaded local models stay in Application Support."
                ) {
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
                    SectionCard(
                        title: section.title,
                        subtitle: section.description
                    ) {
                        VStack(spacing: 0) {
                            ForEach(Array(section.models.enumerated()), id: \.element.id) { index, model in
                                localModelRow(model)

                                if index < section.models.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                SectionCard(
                    title: "Cloud Models",
                    subtitle: "Cloud transcription is optional and only runs after explicit setup."
                ) {
                    VStack(spacing: 0) {
                        ForEach(Array(appState.providerCatalog.providers.enumerated()), id: \.element.id) { index, provider in
                            providerRow(provider)

                            if index < appState.providerCatalog.providers.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Models")
    }

    private func localModelRow(_ model: ModelDescriptor) -> some View {
        let inventoryItem = inventoryItem(for: model)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(model.name)
                            .font(.headline)

                        if let accentBadgeLabel = model.accentBadgeLabel {
                            Text(accentBadgeLabel)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary.opacity(0.8), in: Capsule())
                        }
                    }

                    Text("\(model.engineLabel) • \(model.languageScopeLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                stateBadge(for: inventoryItem.state)
            }

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                GridRow {
                    statLabel(title: "Size", value: model.downloadSizeDescription)
                    statLabel(title: "Speed", value: model.speedDescription)
                }
                GridRow {
                    statLabel(title: "Accuracy", value: model.accuracyDescription)
                    statLabel(title: "Use", value: model.intendedUseLabel)
                }
            }

            Text(model.notes)
                .font(.callout)
                .foregroundStyle(.secondary)

            if let detailMessage = inventoryItem.state.detailMessage {
                Text(detailMessage)
                    .font(.caption)
                    .foregroundStyle(inventoryItem.state == .unavailable(message: detailMessage) ? .red : .orange)
            } else {
                Text(model.availability.message)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let progress = inventoryItem.state.progressValue {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress)
                    Text(String(format: "%.0f%% downloaded", progress * 100))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                Button(appState.transcriptionPreferences.selectedModelID == model.id ? "Selected" : "Set Preferred") {
                    appState.selectLocalModel(model.id)
                }
                .disabled(appState.transcriptionPreferences.selectedModelID == model.id && appState.transcriptionPreferences.preferredProviderID == model.localProviderID)

                if canDelete(inventoryItem.state) {
                    Button("Delete", role: .destructive) {
                        delete(model)
                    }
                }

                Spacer()

                actionButton(for: model, state: inventoryItem.state)
            }
        }
        .padding(.vertical, 10)
    }

    private func providerRow(_ provider: ProviderDescriptor) -> some View {
        let runtimeState = appState.providerRuntimeState(for: provider)
        let validationState = appState.providerCredentialValidationStates[provider.id] ?? .idle

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.name)
                        .font(.headline)

                    Text(provider.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(runtimeState.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(providerStateColor(runtimeState).opacity(0.15), in: Capsule())
                    .foregroundStyle(providerStateColor(runtimeState))
            }

            LabeledContent("Model") {
                Text(provider.modelLabel)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Privacy") {
                Text(provider.privacySummary)
                    .foregroundStyle(.secondary)
            }

            if let validationMessage = validationState.message {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(validationStateColor(validationState))
            } else {
                Text(runtimeState.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                AvailabilityBadge(availability: provider.availability)
                Spacer()

                if runtimeState.isSelectable {
                    Button(appState.transcriptionPreferences.preferredProviderID == provider.id ? "Selected" : "Set Preferred") {
                        appState.transcriptionPreferences.preferredProviderID = provider.id
                    }
                    .disabled(appState.transcriptionPreferences.preferredProviderID == provider.id)
                } else {
                    Button("Open Settings") {
                        appState.openSettings(pane: .cloudProviders)
                    }
                }
            }
        }
        .padding(.vertical, 10)
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

    private func stateBadge(for state: LocalModelState) -> some View {
        Text(state.title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(stateColor(state).opacity(0.15), in: Capsule())
            .foregroundStyle(stateColor(state))
    }

    private func statLabel(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
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

    private func stateColor(_ state: LocalModelState) -> Color {
        switch state {
        case .notDownloaded:
            .secondary
        case .downloading:
            .blue
        case .downloaded:
            .green
        case .loading:
            .orange
        case .loaded:
            .green
        case .deleting:
            .secondary
        case .failed:
            .red
        case .unavailable:
            .red
        }
    }

    private func providerStateColor(_ state: ProviderRuntimeState) -> Color {
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

    private func validationStateColor(_ state: ProviderCredentialValidationState) -> Color {
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
}
