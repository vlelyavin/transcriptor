import Foundation
import WhisperKit

public actor WhisperKitLocalTranscriptionProvider: LocalTranscriptionProvider {
    public let id = "whisperkit-local"
    public let displayName = "On-device (Whisper)"
    public let kind: TranscriptionProviderKind = .local
    public let supportedModelIDs: Set<String>

    private let catalog: ModelCatalog
    private let storageLayout: AppStorageLayout
    private let fileManager: FileManager
    private var loadedModelID: String?
    private var loadedModelFolder: URL?
    private var whisperKit: WhisperKit?

    public init(
        catalog: ModelCatalog,
        storageLayout: AppStorageLayout = AppStorageLayout(),
        fileManager: FileManager = .default
    ) {
        self.catalog = catalog
        self.storageLayout = storageLayout
        self.fileManager = fileManager
        self.supportedModelIDs = Set(catalog.whisperModels.map(\.id))
    }

    public func inventoryItem(for model: ModelDescriptor) async -> LocalModelInventoryItem {
        guard model.isWhisperKitLocalModel else {
            return LocalModelInventoryItem(
                modelID: model.id,
                state: .unavailable(message: model.availability.message)
            )
        }

        if loadedModelID == model.id, let loadedModelFolder {
            return LocalModelInventoryItem(
                modelID: model.id,
                state: .loaded,
                localFolderPath: loadedModelFolder.path
            )
        }

        if let localFolder = resolveLocalFolder(for: model) {
            return LocalModelInventoryItem(
                modelID: model.id,
                state: .downloaded,
                localFolderPath: localFolder.path
            )
        }

        return LocalModelInventoryItem(modelID: model.id, state: .notDownloaded)
    }

    @discardableResult
    public func downloadModel(
        _ model: ModelDescriptor,
        progressHandler: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> URL {
        guard let remoteVariantName = model.remoteVariantName else {
            throw TranscriptionError.unsupportedModel("This model does not have a verified WhisperKit runtime mapping yet.")
        }

        if let existingFolder = resolveLocalFolder(for: model) {
            return existingFolder
        }

        try ensureSufficientDiskSpace(for: model)
        let downloadBase = try storageLayout.modelsDirectory()
        let folder = try await WhisperKit.download(
            variant: remoteVariantName,
            downloadBase: downloadBase,
            progressCallback: { progress in
                progressHandler(progress.fractionCompleted)
            }
        )
        return folder
    }

    public func loadModel(_ model: ModelDescriptor) async throws {
        guard model.isWhisperKitLocalModel else {
            throw TranscriptionError.unsupportedModel("Only WhisperKit local models can be loaded in this build.")
        }

        if loadedModelID == model.id, whisperKit != nil {
            return
        }

        guard let localFolder = resolveLocalFolder(for: model) else {
            throw TranscriptionError.modelNotDownloaded("Download \(model.name) in the Models screen before trying to load it.")
        }

        whisperKit = nil
        loadedModelID = nil
        loadedModelFolder = nil

        let config = WhisperKitConfig(
            downloadBase: try storageLayout.modelsDirectory(),
            modelFolder: localFolder.path,
            verbose: false,
            prewarm: false,
            load: true,
            download: false
        )

        do {
            let runtime = try await WhisperKit(config)
            whisperKit = runtime
            loadedModelID = model.id
            loadedModelFolder = localFolder
        } catch {
            throw TranscriptionError.modelLoadFailed(error.localizedDescription)
        }
    }

    public func deleteModel(_ model: ModelDescriptor) async throws {
        guard let localFolder = resolveLocalFolder(for: model) else {
            return
        }

        if loadedModelID == model.id {
            whisperKit = nil
            loadedModelID = nil
            loadedModelFolder = nil
        }

        if fileManager.fileExists(atPath: localFolder.path) {
            try fileManager.removeItem(at: localFolder)
        }
    }

    public func transcribe(
        job: TranscriptionJob,
        progressHandler: @escaping @Sendable (TranscriptionProgress) -> Void
    ) async throws -> TranscriptionResult {
        guard let model = catalog.model(id: job.requestedModelID), model.isWhisperKitLocalModel else {
            throw TranscriptionError.unsupportedModel("The requested local model is not available in the WhisperKit catalog.")
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

        guard let whisperKit else {
            throw TranscriptionError.modelLoadFailed("WhisperKit did not finish loading \(job.requestedModelName).")
        }

        progressHandler(
            TranscriptionProgress(
                stage: .preparingAudio,
                statusMessage: "Preparing audio for local transcription…"
            )
        )

        do {
            let results = try await whisperKit.transcribe(
                audioPath: job.audioFileURL.path,
                decodeOptions: DecodingOptions(
                    verbose: false,
                    wordTimestamps: false
                ),
                callback: { upstreamProgress in
                    progressHandler(
                        TranscriptionProgress(
                            stage: .transcribing,
                            partialText: upstreamProgress.text,
                            statusMessage: upstreamProgress.text.isEmpty ? "Transcribing locally…" : "Decoding transcript…"
                        )
                    )
                    return Task.isCancelled ? false : true
                }
            )

            try Task.checkCancellation()

            let text = results
                .map(\.text)
                .joined(separator: " ")
                .normalizedTranscriptWhitespace()

            guard !text.isEmpty else {
                throw TranscriptionError.transcriptionFailed("WhisperKit finished without producing transcript text for this audio.")
            }

            let preview = String(text.prefix(180))
            let language = results.first?.language
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
                preview: preview,
                characterCount: text.count,
                language: language,
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

    private func resolveLocalFolder(for model: ModelDescriptor) -> URL? {
        guard let remoteVariantName = model.remoteVariantName else {
            return nil
        }

        let repoRoot = HubApiWrapper(downloadBase: try? storageLayout.modelsDirectory())
            .localRepoLocation(.init(id: "argmaxinc/whisperkit-coreml"))

        guard fileManager.fileExists(atPath: repoRoot.path) else {
            return nil
        }

        if let loadedModelFolder, loadedModelID == model.id, fileManager.fileExists(atPath: loadedModelFolder.path) {
            return loadedModelFolder
        }

        let enumerator = fileManager.enumerator(
            at: repoRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        while let candidateURL = enumerator?.nextObject() as? URL {
            if candidateURL.lastPathComponent == remoteVariantName {
                return candidateURL
            }
        }

        return nil
    }

    private func ensureSufficientDiskSpace(for model: ModelDescriptor) throws {
        guard let approximateDownloadBytes = model.approximateDownloadBytes else {
            return
        }

        let modelsDirectory = try storageLayout.modelsDirectory()
        let values = try modelsDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let availableBytes = Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        let safetyBuffer = Int64(128 * 1_048_576)

        guard availableBytes > approximateDownloadBytes + safetyBuffer else {
            throw TranscriptionError.modelNotDownloaded(
                "Not enough free disk space to download \(model.name). Free space is below the model size plus a safety buffer."
            )
        }
    }
}

private extension String {
    func normalizedTranscriptWhitespace() -> String {
        replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
