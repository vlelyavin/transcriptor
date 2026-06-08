import XCTest
@testable import SottoKit

@MainActor
final class HistoryRepositoryTests: XCTestCase {
    func testHistoryRepositoryPersistsCRUDAcrossReload() throws {
        let rootDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let layout = AppStorageLayout(
            fileManager: .default,
            applicationSupportURLProvider: { rootDirectory }
        )

        let repository = try HistoryRepository(layout: layout)
        let entry = HistoryEntry(
            sourceType: .dictation,
            displayName: "crud-test.wav",
            originalFilePath: "/tmp/crud-test.wav",
            workingFilePath: "/tmp/crud-test.wav",
            transcriptText: "hello world",
            transcriptPreview: "hello world",
            durationSeconds: 4,
            characterCount: 11,
            modelID: "tiny",
            modelName: "Tiny",
            providerID: nil,
            providerName: "Local",
            language: "en",
            fileSizeBytes: 12_345,
            transcriptionStatus: .completed
        )

        try repository.upsert(entry)
        XCTAssertEqual(try repository.fetchAll().count, 1)

        let reloadedRepository = try HistoryRepository(layout: layout)
        let fetchedEntry = try XCTUnwrap(reloadedRepository.fetch(id: entry.id))
        XCTAssertEqual(fetchedEntry.displayName, entry.displayName)
        XCTAssertEqual(fetchedEntry.transcriptText, "hello world")

        _ = try reloadedRepository.delete(id: entry.id)
        XCTAssertTrue(try reloadedRepository.fetchAll().isEmpty)
    }
}
