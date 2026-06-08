import Foundation
import Observation

public struct ActiveTranscriptionJob: Equatable, Sendable {
    public var entryID: UUID
    public var modelID: String
    public var modelName: String
    public var startedAt: Date
    public var progress: TranscriptionProgress?

    public init(
        entryID: UUID,
        modelID: String,
        modelName: String,
        startedAt: Date = .now,
        progress: TranscriptionProgress? = nil
    ) {
        self.entryID = entryID
        self.modelID = modelID
        self.modelName = modelName
        self.startedAt = startedAt
        self.progress = progress
    }
}

private struct QueuedTranscriptionRequest: Equatable, Sendable {
    var entryID: UUID
    var modelID: String
    var modelName: String
}

@MainActor
@Observable
public final class TranscriptionQueueController {
    public private(set) var queuedEntryIDs: [UUID] = []
    public private(set) var activeJob: ActiveTranscriptionJob?
    public private(set) var lastErrorByEntryID: [UUID: String] = [:]

    private let provider: any TranscriptionProvider
    private var entryLookup: @MainActor (UUID) -> HistoryEntry?
    private var persistEntry: @MainActor (HistoryEntry) throws -> Void
    private var modelLookup: @MainActor (String) -> ModelDescriptor?
    private var queuedRequests: [QueuedTranscriptionRequest] = []
    private var currentTask: Task<Void, Never>?

    public init(
        provider: any TranscriptionProvider,
        entryLookup: @escaping @MainActor (UUID) -> HistoryEntry? = { _ in nil },
        persistEntry: @escaping @MainActor (HistoryEntry) throws -> Void = { _ in },
        modelLookup: @escaping @MainActor (String) -> ModelDescriptor? = { _ in nil }
    ) {
        self.provider = provider
        self.entryLookup = entryLookup
        self.persistEntry = persistEntry
        self.modelLookup = modelLookup
    }

    public func replaceEntryLookup(_ entryLookup: @escaping @MainActor (UUID) -> HistoryEntry?) {
        self.entryLookup = entryLookup
    }

    public func replacePersistEntry(_ persistEntry: @escaping @MainActor (HistoryEntry) throws -> Void) {
        self.persistEntry = persistEntry
    }

    public func replaceModelLookup(_ modelLookup: @escaping @MainActor (String) -> ModelDescriptor?) {
        self.modelLookup = modelLookup
    }

    public func enqueue(entryID: UUID, modelID: String, modelName: String) {
        let request = QueuedTranscriptionRequest(entryID: entryID, modelID: modelID, modelName: modelName)

        if activeJob?.entryID == entryID {
            return
        }

        if let existingIndex = queuedRequests.firstIndex(where: { $0.entryID == entryID }) {
            queuedRequests[existingIndex] = request
        } else {
            queuedRequests.append(request)
        }

        queuedEntryIDs = queuedRequests.map(\.entryID)
        startNextIfNeeded()
    }

    public func cancel(entryID: UUID) {
        queuedRequests.removeAll(where: { $0.entryID == entryID })
        queuedEntryIDs = queuedRequests.map(\.entryID)

        guard activeJob?.entryID == entryID else {
            return
        }

        currentTask?.cancel()
    }

    public func isQueuedOrRunning(entryID: UUID) -> Bool {
        activeJob?.entryID == entryID || queuedRequests.contains(where: { $0.entryID == entryID })
    }

    public func progress(for entryID: UUID) -> TranscriptionProgress? {
        guard activeJob?.entryID == entryID else {
            return nil
        }

        return activeJob?.progress
    }

    private func startNextIfNeeded() {
        guard currentTask == nil, !queuedRequests.isEmpty else {
            return
        }

        let request = queuedRequests.removeFirst()
        queuedEntryIDs = queuedRequests.map(\.entryID)
        activeJob = ActiveTranscriptionJob(entryID: request.entryID, modelID: request.modelID, modelName: request.modelName)
        lastErrorByEntryID[request.entryID] = nil

        currentTask = Task { [weak self] in
            guard let self else {
                return
            }

            await self.process(request)
        }
    }

    private func process(_ request: QueuedTranscriptionRequest) async {
        guard var entry = entryLookup(request.entryID) else {
            finishActiveJob()
            return
        }

        let originalEntry = entry
        guard let audioPath = entry.workingFilePath ?? entry.originalFilePath else {
            fail(request.entryID, message: "No local audio file is available for this history item.", originalEntry: originalEntry)
            return
        }

        let audioURL = URL(fileURLWithPath: audioPath)
        entry.transcriptionStatus = .transcribing
        entry.errorMessage = nil
        entry.modelID = request.modelID
        entry.modelName = request.modelName
        entry.providerID = provider.id
        entry.providerName = provider.displayName

        do {
            try persistEntry(entry)
        } catch {
            fail(request.entryID, message: error.localizedDescription, originalEntry: originalEntry)
            return
        }

        let job = TranscriptionJob(
            historyEntryID: entry.id,
            audioFileURL: audioURL,
            requestedModelID: request.modelID,
            requestedModelName: request.modelName,
            sourceType: entry.sourceType
        )

        do {
            let result = try await provider.transcribe(job: job) { [weak self] progress in
                Task { @MainActor in
                    guard let self, self.activeJob?.entryID == request.entryID else {
                        return
                    }
                    self.activeJob?.progress = progress
                }
            }

            try Task.checkCancellation()

            guard var latestEntry = entryLookup(request.entryID) else {
                finishActiveJob()
                return
            }

            latestEntry.transcriptionStatus = .completed
            latestEntry.errorMessage = nil
            latestEntry.appendTranscriptVersion(
                TranscriptVersion(
                    createdAt: result.completedAt,
                    transcriptText: result.text,
                    transcriptPreview: result.preview,
                    characterCount: result.characterCount,
                    modelID: result.modelID,
                    modelName: result.modelName,
                    providerID: result.providerID,
                    providerName: result.providerName,
                    language: result.language
                )
            )
            latestEntry.providerID = result.providerID
            latestEntry.providerName = result.providerName
            latestEntry.transcriptionStatus = .completed
            latestEntry.errorMessage = nil

            try persistEntry(latestEntry)
        } catch is CancellationError {
            restoreAfterFailure(
                for: request.entryID,
                message: TranscriptionError.cancelled.localizedDescription,
                originalEntry: originalEntry,
                cancelled: true
            )
        } catch let error as TranscriptionError {
            restoreAfterFailure(
                for: request.entryID,
                message: error.localizedDescription,
                originalEntry: originalEntry,
                cancelled: error == .cancelled
            )
        } catch {
            restoreAfterFailure(
                for: request.entryID,
                message: error.localizedDescription,
                originalEntry: originalEntry,
                cancelled: false
            )
        }

        finishActiveJob()
    }

    private func restoreAfterFailure(
        for entryID: UUID,
        message: String,
        originalEntry: HistoryEntry,
        cancelled: Bool
    ) {
        if var currentEntry = entryLookup(entryID) {
            if originalEntry.hasCompletedTranscript {
                currentEntry.transcriptionStatus = .completed
                currentEntry.errorMessage = cancelled
                    ? "Re-transcription cancelled. Previous transcript kept."
                    : "Re-transcription failed. Previous transcript kept. \(message)"
                currentEntry.transcriptText = originalEntry.transcriptText
                currentEntry.transcriptPreview = originalEntry.transcriptPreview
                currentEntry.transcriptVersions = originalEntry.transcriptVersions
                currentEntry.lastTranscriptionAt = originalEntry.lastTranscriptionAt
                currentEntry.characterCount = originalEntry.characterCount
                currentEntry.modelID = originalEntry.modelID
                currentEntry.modelName = originalEntry.modelName
                currentEntry.providerID = originalEntry.providerID
                currentEntry.providerName = originalEntry.providerName
                currentEntry.language = originalEntry.language
            } else {
                currentEntry.transcriptionStatus = cancelled ? .pending : .failed
                currentEntry.errorMessage = message
            }

            try? persistEntry(currentEntry)
        }

        lastErrorByEntryID[entryID] = message
    }

    private func fail(_ entryID: UUID, message: String, originalEntry: HistoryEntry) {
        restoreAfterFailure(for: entryID, message: message, originalEntry: originalEntry, cancelled: false)
        finishActiveJob()
    }

    private func finishActiveJob() {
        currentTask = nil
        activeJob = nil
        startNextIfNeeded()
    }
}
