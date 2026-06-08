import XCTest
@testable import SottoKit

final class RecordingStorageTests: XCTestCase {
    func testRecordingStorageGeneratesApplicationSupportRecordingPath() throws {
        let rootDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = RecordingStorage(
            fileManager: .default,
            applicationSupportURLProvider: { rootDirectory }
        )

        let url = try storage.nextRecordingURL(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            identifier: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        )

        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "Recordings")
        XCTAssertEqual(url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent, "Sotto")
        XCTAssertEqual(url.pathExtension, "wav")
        XCTAssertTrue(url.lastPathComponent.hasPrefix("recording-"))
        XCTAssertTrue(url.lastPathComponent.lowercased().contains("aaaaaaaa"))
    }
}
