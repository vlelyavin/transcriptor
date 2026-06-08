import SwiftUI

public struct ModelsView: View {
    @Bindable private var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionCard(
                    title: "Model Manager",
                    subtitle: "Local Whisper-family downloads are real in this build. Parakeet and cloud providers stay visibly unavailable until their runtimes exist."
                ) {
                    Text("Downloaded models stay on this Mac under Application Support. Audio is not uploaded when using the local WhisperKit provider.")
                        .foregroundStyle(.secondary)

                    if let selectedModel = appState.selectedModel {
                        Text("Preferred local model: \(selectedModel.name)")
                            .font(.callout.weight(.medium))
                    }

                    if let statusMessage = appState.whisperModelManager.statusMessage {
                        UnavailableActionBanner(message: statusMessage)
                    }
                }

                ForEach(appState.modelCatalog.sections) { section in
                    VStack(alignment: .leading, spacing: 14) {
                        Text(section.title)
                            .font(.title2.weight(.semibold))

                        Text(section.description)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 18)], spacing: 18) {
                            ForEach(section.models) { model in
                                if model.isWhisperKitLocalModel {
                                    whisperModelCard(model)
                                } else {
                                    placeholderModelCard(model)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Cloud Models")
                        .font(.title2.weight(.semibold))

                    Text("Remote providers are shown for structure and preference management only. They remain unavailable until networking and credential flows are added.")
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 18)], spacing: 18) {
                        ForEach(appState.providerCatalog.providers) { provider in
                            providerCard(provider)
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Models")
    }

    private func whisperModelCard(_ model: ModelDescriptor) -> some View {
        let inventoryItem = appState.whisperModelManager.item(for: model.id)
            ?? LocalModelInventoryItem(modelID: model.id, state: .notDownloaded)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.name)
                        .font(.title3.weight(.semibold))

                    Text(model.engineLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let accentBadgeLabel = model.accentBadgeLabel {
                    Text(accentBadgeLabel)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.yellow.opacity(0.18), in: Capsule())
                        .foregroundStyle(.yellow)
                }
            }

            HStack(spacing: 22) {
                statColumn(title: "Size", value: model.downloadSizeDescription)
                statColumn(title: "Speed", value: model.speedDescription)
                statColumn(title: "Accuracy", value: model.accuracyDescription)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Use")
                        .foregroundStyle(.secondary)
                    Text(model.intendedUseLabel)
                }
                GridRow {
                    Text("Scope")
                        .foregroundStyle(.secondary)
                    Text(model.languageScopeLabel)
                }
                GridRow {
                    Text("Status")
                        .foregroundStyle(.secondary)
                    localStateBadge(inventoryItem.state)
                }
            }

            Divider()

            Text(model.notes)
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

            HStack {
                Button(appState.transcriptionPreferences.selectedModelID == model.id ? "Selected" : "Set Preferred") {
                    appState.transcriptionPreferences.selectedModelID = model.id
                }

                if canDelete(inventoryItem.state) {
                    Button("Delete", role: .destructive) {
                        appState.whisperModelManager.delete(model)
                    }
                }

                Spacer()

                actionButton(for: model, state: inventoryItem.state)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(appState.transcriptionPreferences.selectedModelID == model.id ? Color.orange : Color.secondary.opacity(0.25), lineWidth: 1.5)
        )
    }

    private func placeholderModelCard(_ model: ModelDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.name)
                        .font(.title3.weight(.semibold))

                    Text(model.engineLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                AvailabilityBadge(availability: model.availability)
            }

            HStack(spacing: 22) {
                statColumn(title: "Size", value: model.downloadSizeDescription)
                statColumn(title: "Speed", value: model.speedDescription)
                statColumn(title: "Accuracy", value: model.accuracyDescription)
            }

            Divider()

            Text(model.notes)
                .foregroundStyle(.secondary)

            Text(model.availability.message)
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack {
                AvailabilityBadge(availability: model.availability)
                Spacer()
                Button("Unavailable") {}
                    .disabled(true)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    private func providerCard(_ provider: ProviderDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(provider.name)
                        .font(.title3.weight(.semibold))

                    Text(provider.summary)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(provider.modelLabel)
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .foregroundStyle(.blue)
            }

            Divider()

            Text(provider.priceNote)
                .foregroundStyle(.secondary)

            Text(provider.availability.message)
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack {
                AvailabilityBadge(availability: provider.availability)
                Spacer()
                Button("Unavailable") {}
                    .disabled(true)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
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

    private func statColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
        }
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
