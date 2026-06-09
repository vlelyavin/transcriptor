import XCTest
@testable import TranscriptorKit

final class TranscriptExportServiceTests: XCTestCase {
    func testFormatsTranscriptExportText() throws {
        let service = TranscriptExportService()
        let entry = HistoryEntry(
            sourceType: .dictation,
            displayName: "demo.wav",
            originalFilePath: "/tmp/demo.wav",
            workingFilePath: "/tmp/demo.wav",
            transcriptText: "hello from transcriptor",
            transcriptPreview: "hello from transcriptor",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            durationSeconds: 12,
            characterCount: 16,
            modelID: "tiny",
            modelName: "Whisper Tiny",
            providerID: nil,
            providerName: "Local",
            language: "en",
            fileSizeBytes: 1_024,
            transcriptionStatus: .completed
        )

        let text = try service.formattedText(for: entry)
        XCTAssertTrue(text.contains("Transcriptor Transcript"))
        XCTAssertTrue(text.contains("Title: demo.wav"))
        XCTAssertTrue(text.contains("Model: Whisper Tiny"))
        XCTAssertTrue(text.contains("hello from transcriptor"))
    }
}
