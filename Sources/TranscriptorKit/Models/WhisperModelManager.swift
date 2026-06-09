import Foundation
import Observation

@MainActor
@Observable
public final class WhisperModelManager {
    public private(set) var inventory: [String: LocalModelInventoryItem]
    public private(set) var activeModelID: String?
    public private(set) var statusMessage: String?

    private let catalog: ModelCatalog
    private let provider: WhisperKitLocalTranscriptionProvider

    public init(
        catalog: ModelCatalog,
        provider: WhisperKitLocalTranscriptionProvider
    ) {
        self.catalog = catalog
        self.provider = provider
        self.inventory = Dictionary(
            uniqueKeysWithValues: catalog.whisperModels.map {
                ($0.id, LocalModelInventoryItem(modelID: $0.id, state: .notDownloaded))
            }
        )

        Task { await refresh() }
    }

    public func item(for modelID: String) -> LocalModelInventoryItem? {
        inventory[modelID]
    }

    public func refresh() async {
        for model in catalog.whisperModels {
            inventory[model.id] = await provider.inventoryItem(for: model)
        }

        activeModelID = inventory.first(where: { $0.value.state == .loaded })?.key
    }

    public func download(_ model: ModelDescriptor) {
        inventory[model.id] = LocalModelInventoryItem(modelID: model.id, state: .downloading(progress: 0))
        statusMessage = nil

        Task {
            do {
                let folder = try await provider.downloadModel(model) { [weak self] progress in
                    Task { @MainActor in
                        self?.inventory[model.id] = LocalModelInventoryItem(
                            modelID: model.id,
                            state: .downloading(progress: progress),
                            localFolderPath: self?.inventory[model.id]?.localFolderPath
                        )
                    }
                }

                await MainActor.run {
                    inventory[model.id] = LocalModelInventoryItem(
                        modelID: model.id,
                        state: .downloaded,
                        localFolderPath: folder.path
                    )
                    statusMessage = "Downloaded \(model.name)."
                }
            } catch {
                await MainActor.run {
                    inventory[model.id] = LocalModelInventoryItem(
                        modelID: model.id,
                        state: .failed(message: error.localizedDescription)
                    )
                    statusMessage = error.localizedDescription
                }
            }
        }
    }

    public func load(_ model: ModelDescriptor) {
        inventory[model.id] = LocalModelInventoryItem(
            modelID: model.id,
            state: .loading,
            localFolderPath: inventory[model.id]?.localFolderPath
        )
        statusMessage = nil

        Task {
            do {
                try await provider.loadModel(model)
                await refresh()
                await MainActor.run {
                    statusMessage = "Loaded \(model.name)."
                }
            } catch {
                await MainActor.run {
                    inventory[model.id] = LocalModelInventoryItem(
                        modelID: model.id,
                        state: .failed(message: error.localizedDescription),
                        localFolderPath: inventory[model.id]?.localFolderPath
                    )
                    statusMessage = error.localizedDescription
                }
            }
        }
    }

    public func delete(_ model: ModelDescriptor) {
        inventory[model.id] = LocalModelInventoryItem(
            modelID: model.id,
            state: .deleting,
            localFolderPath: inventory[model.id]?.localFolderPath
        )
        statusMessage = nil

        Task {
            do {
                try await provider.deleteModel(model)
                await MainActor.run {
                    inventory[model.id] = LocalModelInventoryItem(modelID: model.id, state: .notDownloaded)
                    if activeModelID == model.id {
                        activeModelID = nil
                    }
                    statusMessage = "Deleted \(model.name)."
                }
            } catch {
                await MainActor.run {
                    inventory[model.id] = LocalModelInventoryItem(
                        modelID: model.id,
                        state: .failed(message: error.localizedDescription)
                    )
                    statusMessage = error.localizedDescription
                }
            }
        }
    }

    public func downloadedWhisperModels() -> [ModelDescriptor] {
        catalog.whisperModels.filter { inventory[$0.id]?.state == .downloaded || inventory[$0.id]?.state == .loaded }
    }
}
