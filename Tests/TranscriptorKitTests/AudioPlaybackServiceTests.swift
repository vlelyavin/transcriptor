import XCTest
@testable import TranscriptorKit

@MainActor
final class AudioPlaybackServiceTests: XCTestCase {
    func testMissingFilePlaybackThrowsGracefulError() {
        let service = AudioPlaybackService()
        let entry = HistoryEntry(
            sourceType: .dictation,
            displayName: "missing.wav",
            originalFilePath: "/tmp/definitely-missing-transcriptor-file.wav",
            workingFilePath: nil,
            transcriptText: "",
            transcriptPreview: "",
            durationSeconds: 4,
            characterCount: 0,
            fileSizeBytes: 0,
            transcriptionStatus: .pending
        )

        XCTAssertThrowsError(try service.togglePlayback(for: entry)) { error in
            XCTAssertEqual(error as? AudioPlaybackError, .missingFile)
        }
    }
}
