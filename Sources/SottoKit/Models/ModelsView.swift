import SwiftUI

public struct ModelsView: View {
    private let catalog: ModelCatalog
    private let providers: ProviderCatalog

    public init(catalog: ModelCatalog, providers: ProviderCatalog) {
        self.catalog = catalog
        self.providers = providers
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionCard(
                    title: "Model Manager",
                    subtitle: "Local and cloud-backed transcription options will live here."
                ) {
                    Text("This initial scaffold intentionally shows future models and providers as unavailable until the actual runtimes, downloads, and networking flows exist.")
                        .foregroundStyle(.secondary)
                }

                ForEach(catalog.sections) { section in
                    SectionCard(
                        title: section.title,
                        subtitle: section.description
                    ) {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(section.models) { model in
                                ModelRow(model: model)
                            }
                        }
                    }
                }

                SectionCard(
                    title: "Cloud Providers",
                    subtitle: "Remote transcription integrations are listed early but remain disabled."
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(providers.providers) { provider in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(provider.name)
                                        .font(.headline)

                                    Text(provider.summary)
                                        .foregroundStyle(.secondary)

                                    Text(provider.availability.blocker)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }

                                Spacer()

                                AvailabilityBadge(availability: provider.availability)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Models")
    }
}

private struct ModelRow: View {
    let model: ModelDescriptor

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(model.name)
                        .font(.headline)

                    Text(model.downloadSizeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(model.notes)
                    .foregroundStyle(.secondary)

                Text(model.availability.blocker)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            AvailabilityBadge(availability: model.availability)
        }
    }
}
