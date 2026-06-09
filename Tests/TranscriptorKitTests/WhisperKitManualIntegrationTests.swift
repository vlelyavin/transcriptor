import Foundation
import XCTest
@testable import TranscriptorKit

final class WhisperKitManualIntegrationTests: XCTestCase {
    func testTinyModelTranscribesPublicSampleAudio() async throws {
        guard ProcessInfo.processInfo.environment["RUN_MANUAL_WHISPER_INTEGRATION"] == "1" else {
            throw XCTSkip("Manual WhisperKit integration test is opt-in.")
        }

        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TranscriptorWhisperIntegration-\(UUID().uuidString)", isDirectory: true)
        let layout = AppStorageLayout(
            fileManager: .default,
            applicationSupportURLProvider: { rootDirectory }
        )
        let provider = WhisperKitLocalTranscriptionProvider(
            catalog: .defaultCatalog,
            storageLayout: layout
        )
        let model = try XCTUnwrap(ModelCatalog.defaultCatalog.model(id: "whisper-tiny"))

        let audioURL = try await downloadManualTestAudio(into: rootDirectory)
        _ = try await provider.downloadModel(model)
        let result = try await provider.transcribe(
            job: TranscriptionJob(
                historyEntryID: UUID(),
                audioFileURL: audioURL,
                requestedProviderID: "whisperkit-local",
                requestedProviderName: "WhisperKit Local",
                requestedModelID: model.id,
                requestedModelName: model.name,
                sourceType: .importedAudio
            ),
            progressHandler: { _ in }
        )

        XCTAssertFalse(result.text.isEmpty)
        XCTAssertTrue(
            result.text.localizedCaseInsensitiveContains("my fellow americans")
                || result.text.localizedCaseInsensitiveContains("fellow americans"),
            "Expected the public JFK sample to include the recognizable phrase, got: \(result.text)"
        )
    }

    private func downloadManualTestAudio(into rootDirectory: URL) async throws -> URL {
        let audioURL = rootDirectory.appendingPathComponent("jfk.wav")
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)

        let sourceURL = URL(string: ProcessInfo.processInfo.environment["TRANSCRIPTOR_MANUAL_AUDIO_URL"]
            ?? "https://huggingface.co/datasets/Xenova/transformers.js-docs/resolve/main/jfk.wav")!
        let (data, _) = try await URLSession.shared.data(from: sourceURL)
        try data.write(to: audioURL)
        return audioURL
    }
}
