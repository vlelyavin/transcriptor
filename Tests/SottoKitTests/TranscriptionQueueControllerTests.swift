import XCTest
@testable import SottoKit

@MainActor
final class TranscriptionQueueControllerTests: XCTestCase {
    func testQueueTranscribesPendingEntryAndPersistsVersion() async throws {
        let entry = HistoryEntry(
            sourceType: .dictation,
            displayName: "queue.wav",
            originalFilePath: "/tmp/queue.wav",
            workingFilePath: "/tmp/queue.wav",
            transcriptText: "",
            transcriptPreview: "Waiting for transcription.",
            durationSeconds: 5,
            characterCount: 0,
            modelID: "whisper-tiny",
            modelName: "Tiny",
            providerID: nil,
            providerName: nil,
            language: nil,
            fileSizeBytes: 1_024,
            transcriptionStatus: .pending
        )
        let store = EntryStore(entries: [entry.id: entry])
        let provider = MockTranscriptionProvider(
            result: TranscriptionResult(
                text: "hello from sotto queue",
                preview: "hello from sotto queue",
                characterCount: 22,
                language: "en",
                modelID: "whisper-tiny",
                modelName: "Tiny",
                providerID: "whisperkit-local",
                providerName: "WhisperKit Local"
            )
        )
        let controller = makeController(provider: provider, store: store)

        controller.enqueue(entryID: entry.id, modelID: "whisper-tiny", modelName: "Tiny")
        try await waitUntilIdle(controller)

        let persisted = try XCTUnwrap(store.entries[entry.id])
        XCTAssertEqual(persisted.transcriptionStatus, .completed)
        XCTAssertEqual(persisted.transcriptText, "hello from sotto queue")
        XCTAssertEqual(persisted.transcriptVersions.count, 1)
        XCTAssertEqual(persisted.latestTranscriptVersion?.providerID, "whisperkit-local")
    }

    func testRetranscriptionPreservesPreviousTranscriptVersion() async throws {
        let originalVersion = TranscriptVersion(
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            transcriptText: "original transcript",
            transcriptPreview: "original transcript",
            characterCount: 19,
            modelID: "whisper-tiny",
            modelName: "Tiny",
            providerID: "whisperkit-local",
            providerName: "WhisperKit Local",
            language: "en"
        )
        let entry = HistoryEntry(
            sourceType: .dictation,
            displayName: "redo.wav",
            originalFilePath: "/tmp/redo.wav",
            workingFilePath: "/tmp/redo.wav",
            transcriptText: "original transcript",
            transcriptPreview: "original transcript",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            lastTranscriptionAt: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 5,
            characterCount: 19,
            modelID: "whisper-tiny",
            modelName: "Tiny",
            providerID: "whisperkit-local",
            providerName: "WhisperKit Local",
            language: "en",
            fileSizeBytes: 1_024,
            transcriptionStatus: .completed,
            errorMessage: nil
        )
        var seededEntry = entry
        seededEntry.transcriptVersions = [originalVersion]

        let store = EntryStore(entries: [seededEntry.id: seededEntry])
        let provider = MockTranscriptionProvider(
            result: TranscriptionResult(
                text: "replacement transcript",
                preview: "replacement transcript",
                characterCount: 22,
                language: "en",
                modelID: "whisper-base-en",
                modelName: "Base (English)",
                providerID: "whisperkit-local",
                providerName: "WhisperKit Local"
            )
        )
        let controller = makeController(provider: provider, store: store)

        controller.enqueue(entryID: seededEntry.id, modelID: "whisper-base-en", modelName: "Base (English)")
        try await waitUntilIdle(controller)

        let persisted = try XCTUnwrap(store.entries[seededEntry.id])
        XCTAssertEqual(persisted.transcriptionStatus, .completed)
        XCTAssertEqual(persisted.transcriptText, "replacement transcript")
        XCTAssertEqual(persisted.transcriptVersions.count, 2)
        XCTAssertTrue(persisted.transcriptVersions.contains(where: { $0.transcriptText == "original transcript" }))
        XCTAssertTrue(persisted.transcriptVersions.contains(where: { $0.transcriptText == "replacement transcript" }))
    }

    func testCancellationRestoresPendingEntry() async throws {
        let entry = HistoryEntry(
            sourceType: .dictation,
            displayName: "cancel.wav",
            originalFilePath: "/tmp/cancel.wav",
            workingFilePath: "/tmp/cancel.wav",
            transcriptText: "",
            transcriptPreview: "Waiting for transcription.",
            durationSeconds: 5,
            characterCount: 0,
            modelID: "whisper-tiny",
            modelName: "Tiny",
            providerID: nil,
            providerName: nil,
            language: nil,
            fileSizeBytes: 1_024,
            transcriptionStatus: .pending
        )
        let store = EntryStore(entries: [entry.id: entry])
        let provider = MockTranscriptionProvider(
            result: TranscriptionResult(
                text: "should not finish",
                preview: "should not finish",
                characterCount: 17,
                language: "en",
                modelID: "whisper-tiny",
                modelName: "Tiny",
                providerID: "whisperkit-local",
                providerName: "WhisperKit Local"
            ),
            delayNanoseconds: 5_000_000_000
        )
        let controller = makeController(provider: provider, store: store)

        controller.enqueue(entryID: entry.id, modelID: "whisper-tiny", modelName: "Tiny")
        try await Task.sleep(nanoseconds: 50_000_000)
        controller.cancel(entryID: entry.id)
        try await waitUntilIdle(controller)

        let persisted = try XCTUnwrap(store.entries[entry.id])
        XCTAssertEqual(persisted.transcriptionStatus, .pending)
        XCTAssertEqual(persisted.transcriptText, "")
    }

    private func makeController(
        provider: MockTranscriptionProvider,
        store: EntryStore
    ) -> TranscriptionQueueController {
        let controller = TranscriptionQueueController(provider: provider)
        controller.replaceEntryLookup { id in
            store.entries[id]
        }
        controller.replacePersistEntry { entry in
            store.entries[entry.id] = entry
        }
        controller.replaceModelLookup { modelID in
            ModelCatalog.defaultCatalog.model(id: modelID)
        }
        return controller
    }

    private func waitUntilIdle(_ controller: TranscriptionQueueController) async throws {
        for _ in 0..<100 {
            if controller.activeJob == nil && controller.queuedEntryIDs.isEmpty {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTFail("Timed out waiting for transcription queue to finish.")
    }
}

@MainActor
private final class EntryStore {
    var entries: [UUID: HistoryEntry]

    init(entries: [UUID: HistoryEntry]) {
        self.entries = entries
    }
}

private struct MockTranscriptionProvider: TranscriptionProvider {
    let id = "mock-local"
    let displayName = "Mock Local"
    let kind: TranscriptionProviderKind = .local
    var result: TranscriptionResult
    var delayNanoseconds: UInt64 = 0

    func transcribe(
        job: TranscriptionJob,
        progressHandler: @escaping @Sendable (TranscriptionProgress) -> Void
    ) async throws -> TranscriptionResult {
        progressHandler(
            TranscriptionProgress(
                stage: .transcribing,
                partialText: "mock partial",
                statusMessage: "Mock transcription in progress"
            )
        )

        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }

        try Task.checkCancellation()
        return result
    }
}
