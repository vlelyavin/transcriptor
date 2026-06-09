import XCTest
@testable import TranscriptorKit

final class StorageQuotaServiceTests: XCTestCase {
    func testManagedStorageUsageExcludesModelsFromManagedTotal() throws {
        let rootDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileManager = FileManager.default
        let layout = AppStorageLayout(
            fileManager: fileManager,
            applicationSupportURLProvider: { rootDirectory }
        )

        try write(bytes: 1_024, to: layout.recordingsDirectory().appendingPathComponent("recording.wav"))
        try write(bytes: 2_048, to: layout.importOriginalsDirectory().appendingPathComponent("clip.m4a"))
        try write(bytes: 512, to: layout.metadataDirectory().appendingPathComponent("history.json"))
        try write(bytes: 4_096, to: layout.modelsDirectory().appendingPathComponent("model.bin"))

        let usage = try layout.managedStorageUsage()
        XCTAssertEqual(usage.audioBytes, 3_072)
        XCTAssertEqual(usage.metadataBytes, 512)
        XCTAssertEqual(usage.modelBytes, 4_096)
        XCTAssertEqual(usage.totalManagedBytes, 3_584)
        XCTAssertEqual(usage.totalIncludingModelsBytes, 7_680)
    }

    func testPrunesOldestEntriesFirstWhenOverLimit() throws {
        let rootDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let layout = AppStorageLayout(
            fileManager: .default,
            applicationSupportURLProvider: { rootDirectory }
        )
        let quotaService = StorageQuotaService(layout: layout)

        try write(bytes: 3 * 1_048_576, to: layout.recordingsDirectory().appendingPathComponent("oversized.wav"))

        let oldestID = UUID()
        let middleID = UUID()
        let newestID = UUID()

        let entries = [
            HistoryEntry(
                id: oldestID,
                sourceType: .dictation,
                displayName: "oldest.wav",
                originalFilePath: nil,
                workingFilePath: nil,
                transcriptText: "",
                transcriptPreview: "",
                createdAt: Date(timeIntervalSince1970: 1),
                durationSeconds: 10,
                characterCount: 0,
                fileSizeBytes: 1_048_576,
                transcriptionStatus: .pending
            ),
            HistoryEntry(
                id: middleID,
                sourceType: .dictation,
                displayName: "middle.wav",
                originalFilePath: nil,
                workingFilePath: nil,
                transcriptText: "",
                transcriptPreview: "",
                createdAt: Date(timeIntervalSince1970: 2),
                durationSeconds: 10,
                characterCount: 0,
                fileSizeBytes: 1_048_576,
                transcriptionStatus: .pending
            ),
            HistoryEntry(
                id: newestID,
                sourceType: .dictation,
                displayName: "newest.wav",
                originalFilePath: nil,
                workingFilePath: nil,
                transcriptText: "",
                transcriptPreview: "",
                createdAt: Date(timeIntervalSince1970: 3),
                durationSeconds: 10,
                characterCount: 0,
                fileSizeBytes: 1_048_576,
                transcriptionStatus: .pending
            ),
        ]

        let result = try quotaService.pruneEntriesIfNeeded(
            entries: entries,
            settings: StorageSettings(capMegabytes: 1, autoDeleteOldestHistory: true)
        )

        XCTAssertEqual(result.prunedEntryIDs, [oldestID, middleID])
    }

    private func write(bytes: Int, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        let data = Data(repeating: 0xA, count: bytes)
        try data.write(to: url)
    }
}
