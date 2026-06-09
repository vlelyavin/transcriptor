import Darwin
import FluidAudio
import Foundation

public actor ParakeetLocalTranscriptionProvider: LocalTranscriptionProvider {
    public let id = "parakeet-local"
    public let displayName = "Parakeet Local"
    public let kind: TranscriptionProviderKind = .local
    public let supportedModelIDs: Set<String>

    private let catalog: ModelCatalog
    private let fileManager: FileManager
    private var loadedModelID: String?
    private var loadedVersion: AsrModelVersion?
    private var asrManager: AsrManager?

    public init(
        catalog: ModelCatalog,
        fileManager: FileManager = .default
    ) {
        self.catalog = catalog
        self.fileManager = fileManager
        self.supportedModelIDs = Set(catalog.parakeetModels.map(\.id))
    }

    public func inventoryItem(for model: ModelDescriptor) async -> LocalModelInventoryItem {
        guard model.isParakeetLocalModel else {
            return LocalModelInventoryItem(
                modelID: model.id,
                state: .unavailable(message: model.availability.message)
            )
        }

        guard Self.isAppleSilicon else {
            return LocalModelInventoryItem(
                modelID: model.id,
                state: .unavailable(message: "Parakeet Local currently requires Apple Silicon for this Core ML backend.")
            )
        }

        let folder = localFolder(for: model)

        if loadedModelID == model.id, let folder {
            return LocalModelInventoryItem(modelID: model.id, state: .loaded, localFolderPath: folder.path)
        }

        if let folder {
            return LocalModelInventoryItem(modelID: model.id, state: .downloaded, localFolderPath: folder.path)
        }

        return LocalModelInventoryItem(modelID: model.id, state: .notDownloaded)
    }

    @discardableResult
    public func downloadModel(
        _ model: ModelDescriptor,
        progressHandler: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> URL {
        guard model.isParakeetLocalModel else {
            throw TranscriptionError.unsupportedModel("This Parakeet model is not mapped to a verified local runtime.")
        }

        guard Self.isAppleSilicon else {
            throw TranscriptionError.providerUnavailable("Parakeet Local currently requires Apple Silicon for this Core ML backend.")
        }

        if let existingFolder = localFolder(for: model) {
            return existingFolder
        }

        let version = try version(for: model)
        let targetFolder = try await AsrModels.download(
            version: version,
            progressHandler: { progress in
                progressHandler(progress.fractionCompleted)
            }
        )
        return targetFolder
    }

    public func loadModel(_ model: ModelDescriptor) async throws {
        guard model.isParakeetLocalModel else {
            throw TranscriptionError.unsupportedModel("Only verified Parakeet local models can be loaded by this provider.")
        }

        guard Self.isAppleSilicon else {
            throw TranscriptionError.providerUnavailable("Parakeet Local currently requires Apple Silicon for this Core ML backend.")
        }

        if loadedModelID == model.id, asrManager != nil {
            return
        }

        guard let folder = localFolder(for: model) else {
            throw TranscriptionError.modelNotDownloaded("Download \(model.name) in Models before trying to load it.")
        }

        let version = try version(for: model)
        let models = try await AsrModels.load(from: folder, version: version)
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)

        asrManager = manager
        loadedModelID = model.id
        loadedVersion = version
    }

    public func deleteModel(_ model: ModelDescriptor) async throws {
        guard let folder = localFolder(for: model) else {
            return
        }

        if loadedModelID == model.id {
            asrManager = nil
            loadedModelID = nil
            loadedVersion = nil
        }

        if fileManager.fileExists(atPath: folder.path) {
            try fileManager.removeItem(at: folder)
        }
    }

    public func transcribe(
        job: TranscriptionJob,
        progressHandler: @escaping @Sendable (TranscriptionProgress) -> Void
    ) async throws -> TranscriptionResult {
        guard let model = catalog.model(id: job.requestedModelID), model.isParakeetLocalModel else {
            throw TranscriptionError.unsupportedModel("The requested Parakeet model is not available in this build.")
        }

        guard Self.isAppleSilicon else {
            throw TranscriptionError.providerUnavailable("Parakeet Local currently requires Apple Silicon for this Core ML backend.")
        }

        guard fileManager.fileExists(atPath: job.audioFileURL.path) else {
            throw TranscriptionError.missingAudioFile("The audio file for this history item could not be found.")
        }

        progressHandler(
            TranscriptionProgress(
                stage: .loadingModel,
                statusMessage: "Loading \(job.requestedModelName)…"
            )
        )

        try Task.checkCancellation()
        try await loadModel(model)
        try Task.checkCancellation()

        guard let asrManager, let loadedVersion else {
            throw TranscriptionError.modelLoadFailed("Parakeet models did not finish loading.")
        }

        progressHandler(
            TranscriptionProgress(
                stage: .preparingAudio,
                statusMessage: "Preparing audio for local Parakeet transcription…"
            )
        )

        do {
            var decoderState = try TdtDecoderState(decoderLayers: loadedVersion.decoderLayers)
            let result = try await asrManager.transcribe(job.audioFileURL, decoderState: &decoderState)
            let text = result.text.normalizedTranscriptWhitespace()

            guard !text.isEmpty else {
                throw TranscriptionError.transcriptionFailed("Parakeet finished without producing transcript text for this audio.")
            }

            progressHandler(
                TranscriptionProgress(
                    stage: .finalizing,
                    fractionCompleted: 1.0,
                    partialText: text,
                    statusMessage: "Finalizing transcript…"
                )
            )

            return TranscriptionResult(
                text: text,
                preview: String(text.prefix(180)),
                characterCount: text.count,
                language: inferredLanguage(for: model),
                modelID: model.id,
                modelName: model.name,
                providerID: id,
                providerName: displayName
            )
        } catch is CancellationError {
            throw TranscriptionError.cancelled
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }

    private func version(for model: ModelDescriptor) throws -> AsrModelVersion {
        switch model.id {
        case "parakeet-v2-en":
            .v2
        case "parakeet-v3-multilingual":
            .v3
        default:
            throw TranscriptionError.unsupportedModel("The requested Parakeet model is not mapped to a supported FluidAudio model version.")
        }
    }

    private func inferredLanguage(for model: ModelDescriptor) -> String? {
        switch model.id {
        case "parakeet-v2-en":
            "en"
        default:
            nil
        }
    }

    private func localFolder(for model: ModelDescriptor) -> URL? {
        guard let version = try? version(for: model) else {
            return nil
        }

        let directory = AsrModels.defaultCacheDirectory(for: version)
        guard AsrModels.modelsExist(at: directory, version: version) else {
            return nil
        }
        return directory
    }

    private static var isAppleSilicon: Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("hw.optional.arm64", &value, &size, nil, 0)
        return result == 0 && value == 1
    }
}

private extension String {
    func normalizedTranscriptWhitespace() -> String {
        replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
