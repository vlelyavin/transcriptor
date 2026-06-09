import XCTest
@testable import TranscriptorKit

final class HistoryEntryTests: XCTestCase {
    func testCompletedTranscriptEnablesCopyAndExportActions() {
        let entry = HistoryEntry(
            sourceType: .dictation,
            displayName: "done.wav",
            originalFilePath: nil,
            workingFilePath: nil,
            transcriptText: "completed transcript",
            transcriptPreview: "completed transcript",
            durationSeconds: 5,
            characterCount: 20,
            fileSizeBytes: 512,
            transcriptionStatus: .completed
        )

        XCTAssertTrue(entry.canCopyTranscript)
        XCTAssertTrue(entry.canExportTranscript)
    }

    func testPendingTranscriptDisablesCopyAndExportActions() {
        let entry = HistoryEntry(
            sourceType: .importedAudio,
            displayName: "pending.m4a",
            originalFilePath: nil,
            workingFilePath: nil,
            transcriptText: "",
            transcriptPreview: "Pending transcription",
            durationSeconds: 5,
            characterCount: 0,
            fileSizeBytes: 512,
            transcriptionStatus: .pending
        )

        XCTAssertFalse(entry.canCopyTranscript)
        XCTAssertFalse(entry.canExportTranscript)
    }
}
