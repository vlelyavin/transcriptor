import AVFoundation
import XCTest
@testable import TranscriptorKit

final class AudioRetentionServiceTests: XCTestCase {
    private var rootDirectory: URL!
    private var layout: AppStorageLayout!
    private var service: AudioRetentionService!

    override func setUpWithError() throws {
        rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        layout = AppStorageLayout(
            fileManager: .default,
            applicationSupportURLProvider: { [rootDirectory] in rootDirectory }
        )
        service = AudioRetentionService(
            layout: layout,
            fileManager: .default,
            diagnostics: RecordingDiagnosticsLog(layout: layout)
        )
    }

    override func tearDownWithError() throws {
        if let rootDirectory {
            try? FileManager.default.removeItem(at: rootDirectory)
        }
    }

    func testArchiveReplacesDeviceFormatWAVWith16kHzMonoM4A() throws {
        let wavURL = try layout.recordingsDirectory()
            .appendingPathComponent("recording-2026-01-01T10-00-00-abcdef12.wav")
        try writeWAV(to: wavURL, seconds: 2, sampleRate: 48_000, channels: 1)

        var entry = HistoryEntry.pendingRecording(
            recording: RecordedAudioAsset(
                url: wavURL,
                createdAt: Date(),
                durationSeconds: 2,
                fileSizeBytes: try fileSize(wavURL)
            ),
            modelID: "whisper-tiny",
            modelName: "Tiny"
        )
        entry.transcriptionStatus = .completed
        entry.transcriptText = "hello"
        entry.transcriptPreview = "hello"

        let archived = try XCTUnwrap(service.archiveRecording(for: entry))
        let archivedURL = try XCTUnwrap(archived.originalFilePath.map(URL.init(fileURLWithPath:)))

        XCTAssertEqual(archivedURL.pathExtension, "m4a")
        XCTAssertFalse(FileManager.default.fileExists(atPath: wavURL.path), "the device-format WAV is replaced")
        XCTAssertTrue(FileManager.default.fileExists(atPath: archivedURL.path))
        XCTAssertEqual(archived.workingFilePath, archived.originalFilePath)
        XCTAssertEqual(archived.displayName, archivedURL.lastPathComponent)
        XCTAssertGreaterThan(archived.fileSizeBytes, 0)
        XCTAssertLessThan(archived.fileSizeBytes, entry.fileSizeBytes, "the m4a archive is smaller than the captured WAV")
        XCTAssertEqual(archived.audioStorageDescription, "16 kHz mono m4a")

        let archivedFile = try AVAudioFile(forReading: archivedURL)
        XCTAssertEqual(archivedFile.processingFormat.sampleRate, 16_000)
        XCTAssertEqual(archivedFile.processingFormat.channelCount, 1)
        XCTAssertEqual(
            Double(archivedFile.length) / archivedFile.processingFormat.sampleRate,
            2,
            accuracy: 0.25
        )

        // Already archived: a second pass must not re-encode or lose the file.
        XCTAssertNil(service.archiveRecording(for: archived))
        XCTAssertTrue(FileManager.default.fileExists(atPath: archivedURL.path))
    }

    func testArchiveSkipsImportedAudio() throws {
        let wavURL = try layout.importOriginalsDirectory()
            .appendingPathComponent("import-clip.wav")
        try writeWAV(to: wavURL, seconds: 1, sampleRate: 44_100, channels: 2)

        let entry = HistoryEntry(
            sourceType: .importedAudio,
            displayName: "import-clip.wav",
            originalFilePath: wavURL.path,
            workingFilePath: wavURL.path,
            transcriptText: "imported",
            transcriptPreview: "imported",
            durationSeconds: 1,
            characterCount: 8,
            fileSizeBytes: try fileSize(wavURL),
            transcriptionStatus: .completed
        )

        XCTAssertNil(service.archiveRecording(for: entry), "imports keep the file the user brought")
        XCTAssertTrue(FileManager.default.fileExists(atPath: wavURL.path))
    }

    func testRemoveRecordingsDeletesAudioButKeepsEntry() throws {
        let wavURL = try layout.recordingsDirectory()
            .appendingPathComponent("recording-remove.wav")
        try writeWAV(to: wavURL, seconds: 1, sampleRate: 16_000, channels: 1)

        let entry = HistoryEntry(
            sourceType: .dictation,
            displayName: "recording-remove.wav",
            originalFilePath: wavURL.path,
            workingFilePath: wavURL.path,
            transcriptText: "keep me",
            transcriptPreview: "keep me",
            durationSeconds: 1,
            characterCount: 7,
            fileSizeBytes: try fileSize(wavURL),
            transcriptionStatus: .completed
        )

        let updated = try XCTUnwrap(service.removeRecordings(for: entry))
        XCTAssertNil(updated.originalFilePath)
        XCTAssertNil(updated.workingFilePath)
        XCTAssertEqual(updated.fileSizeBytes, 0)
        XCTAssertEqual(updated.transcriptText, "keep me")
        XCTAssertFalse(FileManager.default.fileExists(atPath: wavURL.path))
        XCTAssertNil(service.removeRecordings(for: updated))
    }

    func testExpiredEntryIDsFollowWindowAndSkipInFlightWork() throws {
        let wavURL = try layout.recordingsDirectory()
            .appendingPathComponent("recording-old.wav")
        try writeWAV(to: wavURL, seconds: 1, sampleRate: 16_000, channels: 1)

        let oldDate = Date(timeIntervalSinceNow: -40 * 86_400)
        let oldEntry = HistoryEntry(
            sourceType: .dictation,
            displayName: "old.wav",
            originalFilePath: wavURL.path,
            workingFilePath: wavURL.path,
            transcriptText: "old",
            transcriptPreview: "old",
            createdAt: oldDate,
            durationSeconds: 1,
            characterCount: 3,
            fileSizeBytes: try fileSize(wavURL),
            transcriptionStatus: .completed
        )

        XCTAssertEqual(
            service.expiredEntryIDs(in: [oldEntry], settings: AudioRetentionSettings(keepsRecordings: true, window: .month)),
            [oldEntry.id]
        )
        XCTAssertTrue(
            service.expiredEntryIDs(in: [oldEntry], settings: AudioRetentionSettings(keepsRecordings: true, window: .year)).isEmpty
        )
        XCTAssertTrue(
            service.expiredEntryIDs(in: [oldEntry], settings: AudioRetentionSettings(keepsRecordings: true, window: .forever)).isEmpty
        )

        var transcribing = oldEntry
        transcribing.transcriptionStatus = .transcribing
        XCTAssertTrue(
            service.expiredEntryIDs(in: [transcribing], settings: AudioRetentionSettings(keepsRecordings: true, window: .month)).isEmpty,
            "audio an in-flight transcription is reading is never expired"
        )

        XCTAssertTrue(
            service.expiredEntryIDs(in: [oldEntry], settings: AudioRetentionSettings(keepsRecordings: false, window: .month)).isEmpty,
            "with recordings off the checkbox path removes audio; the window does not double-delete"
        )
    }

    // MARK: - Helpers

    private func writeWAV(
        to url: URL,
        seconds: Double,
        sampleRate: Double,
        channels: AVAudioChannelCount
    ) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels))
        let file = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: Int(channels),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ])

        let frames = AVAudioFrameCount(sampleRate * seconds)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        for channel in 0..<Int(channels) {
            let samples = try XCTUnwrap(buffer.floatChannelData?[channel])
            for frame in 0..<Int(frames) {
                samples[frame] = sinf(Float(frame) * 2 * .pi * 220 / Float(sampleRate)) * 0.4
            }
        }
        try file.write(from: buffer)
    }

    private func fileSize(_ url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }
}

final class DockIconPolicyTests: XCTestCase {
    func testMenuBarOnlyByDefault() {
        XCTAssertFalse(DockIconPolicy.shouldShowDockIcon(for: .init()))
    }

    func testPinnedIconShowsDockIcon() {
        XCTAssertTrue(DockIconPolicy.shouldShowDockIcon(for: .init(pinnedDockIcon: true)))
        // An open window is not an input: with the preference off the app must
        // stay menu-bar-only while Settings is open.
        XCTAssertFalse(DockIconPolicy.shouldShowDockIcon(for: .init()))
    }
}
