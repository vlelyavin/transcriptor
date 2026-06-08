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
                    subtitle: "Mock inventory states are visible so the UI can be validated before downloads, inference, or cloud calls exist."
                ) {
                    Text("Available and downloaded badges in this screen are illustrative only. No model downloads, no local transcription runtime, and no cloud networking are implemented in this build.")
                        .foregroundStyle(.secondary)

                    if let selectedModel = appState.selectedModel {
                        Text("Preferred model: \(selectedModel.name)")
                            .font(.callout.weight(.medium))
                    }
                }

                ForEach(appState.modelCatalog.sections) { section in
                    VStack(alignment: .leading, spacing: 14) {
                        Text(section.title)
                            .font(.title2.weight(.semibold))

                        Text(section.description)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 18)], spacing: 18) {
                            ForEach(section.models) { model in
                                modelCard(model)
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

    private func modelCard(_ model: ModelDescriptor) -> some View {
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

            Divider()

            Text(model.notes)
                .foregroundStyle(.secondary)

            Text(model.availability.message)
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack {
                AvailabilityBadge(availability: model.availability)

                Spacer()

                Button(appState.transcriptionPreferences.selectedModelID == model.id ? "Selected" : "Set Preferred") {
                    appState.transcriptionPreferences.selectedModelID = model.id
                }
                .disabled(model.family == "Parakeet")
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(appState.transcriptionPreferences.selectedModelID == model.id ? .orange : .quaternary, lineWidth: 1.5)
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
