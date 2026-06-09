import SwiftUI

public struct ModelsView: View {
    @Bindable private var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Models")
                        .font(.title.weight(.semibold))

                    Text("Choose a local Whisper model, review cloud provider readiness, and keep unsupported runtimes visibly unavailable.")
                        .foregroundStyle(.secondary)
                }

                SectionCard(
                    title: "Current Selection",
                    subtitle: "Downloaded local models stay on this Mac under Application Support."
                ) {
                    if let selectedModel = appState.selectedModel {
                        LabeledContent("Preferred local model") {
                            Text(selectedModel.name)
                        }
                    }

                    LabeledContent("Preferred provider") {
                        Text(appState.transcriptionPreferences.preferredProviderID == "whisperkit-local" ? "WhisperKit Local" : appState.preferredCloudProvider?.name ?? "WhisperKit Local")
                    }

                    if let statusMessage = appState.whisperModelManager.statusMessage {
                        UnavailableActionBanner(message: statusMessage)
                    }
                }

                ForEach(appState.modelCatalog.sections) { section in
                    SectionCard(
                        title: section.title,
                        subtitle: section.description
                    ) {
                        modelRows(for: section.models)
                    }
                }

                SectionCard(
                    title: "Cloud Models",
                    subtitle: "Cloud providers require a Keychain-stored API key and explicit privacy acknowledgment before audio is uploaded."
                ) {
                    providerRows
                }
            }
            .padding(24)
        }
        .navigationTitle("Models")
    }

    @ViewBuilder
    private func modelRows(for models: [ModelDescriptor]) -> some View {
        ForEach(Array(models.enumerated()), id: \.element.id) { index, model in
            if model.isWhisperKitLocalModel {
                whisperModelRow(model)
            } else {
                unavailableModelRow(model)
            }

            if index < models.count - 1 {
                Divider()
            }
        }
    }

    @ViewBuilder
    private var providerRows: some View {
        ForEach(Array(appState.providerCatalog.providers.enumerated()), id: \.element.id) { index, provider in
            providerRow(provider)

            if index < appState.providerCatalog.providers.count - 1 {
                Divider()
            }
        }
    }

    private func whisperModelRow(_ model: ModelDescriptor) -> some View {
        let inventoryItem = appState.whisperModelManager.item(for: model.id)
            ?? LocalModelInventoryItem(modelID: model.id, state: .notDownloaded)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(model.name)
                            .font(.headline)

                        if let accentBadgeLabel = model.accentBadgeLabel {
                            Text(accentBadgeLabel)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.yellow.opacity(0.16), in: Capsule())
                                .foregroundStyle(.yellow)
                        }
                    }

                    Text("\(model.engineLabel) • \(model.languageScopeLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                localStateBadge(inventoryItem.state)
            }

            HStack(spacing: 18) {
                statLabel(title: "Size", value: model.downloadSizeDescription)
                statLabel(title: "Speed", value: model.speedDescription)
                statLabel(title: "Accuracy", value: model.accuracyDescription)
                statLabel(title: "Use", value: model.intendedUseLabel)
            }

            Text(model.notes)
                .font(.callout)
                .foregroundStyle(.secondary)

            if let detailMessage = inventoryItem.state.detailMessage {
                Text(detailMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
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
                    appState.transcriptionPreferences.selectedModelID = model.id
                }
                .disabled(appState.transcriptionPreferences.selectedModelID == model.id)

                if canDelete(inventoryItem.state) {
                    Button("Delete", role: .destructive) {
                        appState.whisperModelManager.delete(model)
                    }
                }

                Spacer()

                actionButton(for: model, state: inventoryItem.state)
            }
        }
        .padding(.vertical, 4)
    }

    private func unavailableModelRow(_ model: ModelDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.name)
                        .font(.headline)

                    Text("\(model.engineLabel) • \(model.languageScopeLabel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                AvailabilityBadge(availability: model.availability)
            }

            HStack(spacing: 18) {
                statLabel(title: "Size", value: model.downloadSizeDescription)
                statLabel(title: "Speed", value: model.speedDescription)
                statLabel(title: "Accuracy", value: model.accuracyDescription)
                statLabel(title: "Use", value: model.intendedUseLabel)
            }

            Text(model.notes)
                .font(.callout)
                .foregroundStyle(.secondary)

            Text(model.availability.message)
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack(spacing: 10) {
                Button("Unavailable") {}
                    .disabled(true)

                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    private func providerRow(_ provider: ProviderDescriptor) -> some View {
        let runtimeState = appState.providerRuntimeState(for: provider)
        let validationState = appState.providerCredentialValidationStates[provider.id] ?? .idle

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(provider.name)
                        .font(.headline)

                    Text(provider.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(provider.modelLabel)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .foregroundStyle(.blue)

                    Text(runtimeState.title)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(providerStateColor(runtimeState).opacity(0.15), in: Capsule())
                        .foregroundStyle(providerStateColor(runtimeState))
                }
            }

            HStack(spacing: 18) {
                statLabel(title: "Privacy", value: provider.privacySummary)
                statLabel(title: "Billing", value: provider.priceNote)
            }

            Text(runtimeState.message)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let validationMessage = validationState.message {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(validationStateColor(validationState))
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
                        appState.selectedScreen = .settings
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func actionButton(for model: ModelDescriptor, state: LocalModelState) -> some View {
        switch state {
        case .notDownloaded, .failed:
            Button("Download") {
                appState.whisperModelManager.download(model)
            }
        case .downloaded:
            Button("Load") {
                appState.whisperModelManager.load(model)
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

    private func canDelete(_ state: LocalModelState) -> Bool {
        switch state {
        case .downloaded, .loaded, .failed:
            true
        default:
            false
        }
    }

    private func localStateBadge(_ state: LocalModelState) -> some View {
        Text(state.title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(stateColor(state).opacity(0.15), in: Capsule())
            .foregroundStyle(stateColor(state))
    }

    private func stateColor(_ state: LocalModelState) -> Color {
        switch state {
        case .loaded:
            .green
        case .downloaded:
            .blue
        case .downloading, .loading, .deleting:
            .orange
        case .failed, .unavailable:
            .red
        case .notDownloaded:
            .secondary
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

    private func statLabel(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
struct ModelsView_Previews: PreviewProvider {
    static var previews: some View {
        ModelsView(appState: .preview)
            .frame(width: 1280, height: 920)
    }
}
#endif
