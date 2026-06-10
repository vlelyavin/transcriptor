import AVFoundation
import XCTest
@testable import TranscriptorKit

final class AudioImportServiceTests: XCTestCase {
    private func makeService() -> (AudioImportService, AppStorageLayout) {
        let rootDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let layout = AppStorageLayout(
            fileManager: .default,
            applicationSupportURLProvider: { rootDirectory }
        )
        return (AudioImportService(layout: layout), layout)
    }

    private func fixtureURL(named name: String) throws -> URL {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"),
            "Missing test fixture \(name)"
        )
        return url
    }

    func testOggOpusImportConvertsToWAVWorkingFile() throws {
        let (service, _) = makeService()
        let result = try service.prepareImport(from: try fixtureURL(named: "fixture-opus.ogg"))

        XCTAssertEqual(result.status, .pending)
        XCTAssertNil(result.errorMessage)
        let workingFileURL = try XCTUnwrap(result.workingFileURL)
        XCTAssertEqual(workingFileURL.pathExtension, "wav")
        XCTAssertNotEqual(workingFileURL, result.originalFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: workingFileURL.path))

        let decoded = try AVAudioFile(forReading: workingFileURL)
        let duration = Double(decoded.length) / decoded.processingFormat.sampleRate
        XCTAssertEqual(duration, 0.6, accuracy: 0.1)
    }

    func testOggVorbisImportConvertsToWAVWorkingFile() throws {
        let (service, _) = makeService()
        let result = try service.prepareImport(from: try fixtureURL(named: "fixture-vorbis.ogg"))

        XCTAssertEqual(result.status, .pending)
        let workingFileURL = try XCTUnwrap(result.workingFileURL)
        XCTAssertEqual(workingFileURL.pathExtension, "wav")
        XCTAssertNoThrow(try AVAudioFile(forReading: workingFileURL))
    }

    func testOpusExtensionImportIsSupported() throws {
        let (service, _) = makeService()
        let result = try service.prepareImport(from: try fixtureURL(named: "fixture-voice.opus"))

        XCTAssertEqual(result.status, .pending)
        XCTAssertEqual(result.workingFileURL?.pathExtension, "wav")
    }

    func testOggImportKeepsOriginalFile() throws {
        let (service, layout) = makeService()
        let result = try service.prepareImport(from: try fixtureURL(named: "fixture-opus.ogg"))

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.originalFileURL.path))
        XCTAssertEqual(result.originalFileURL.pathExtension, "ogg")
        XCTAssertTrue(result.originalFileURL.path.hasPrefix(try layout.importOriginalsDirectory().path))
    }

    func testWebMImportIsRejectedAsUnsupported() throws {
        let (service, _) = makeService()
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent("clip-\(UUID().uuidString).webm")
        try Data([0x1A, 0x45, 0xDF, 0xA3]).write(to: sourceURL)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        XCTAssertThrowsError(try service.prepareImport(from: sourceURL)) { error in
            guard case let AudioImportError.unsupportedFileType(fileExtension) = error else {
                return XCTFail("Expected unsupportedFileType, got \(error)")
            }
            XCTAssertEqual(fileExtension, "webm")
        }
    }

    func testCorruptOggImportFailsHonestlyAndKeepsOriginal() throws {
        let (service, _) = makeService()
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent("broken-\(UUID().uuidString).ogg")
        try Data("not really an ogg file".utf8).write(to: sourceURL)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let result = try service.prepareImport(from: sourceURL)
        XCTAssertEqual(result.status, .failed)
        XCTAssertNil(result.workingFileURL)
        XCTAssertNotNil(result.errorMessage)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.originalFileURL.path))
    }

    func testWAVImportUsesOriginalAsWorkingFile() throws {
        let (service, _) = makeService()

        let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
        let sourceURL = FileManager.default.temporaryDirectory.appendingPathComponent("tone-\(UUID().uuidString).wav")
        do {
            // Scope the writer so the file is flushed before importing it.
            let file = try AVAudioFile(forWriting: sourceURL, settings: format.settings)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 16_000)!
            buffer.frameLength = 16_000
            try file.write(from: buffer)
        }
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let result = try service.prepareImport(from: sourceURL)
        XCTAssertEqual(result.status, .pending)
        XCTAssertEqual(result.workingFileURL, result.originalFileURL)
        XCTAssertEqual(result.durationSeconds, 1)
    }
}
