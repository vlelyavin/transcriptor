import XCTest
@testable import TranscriptorKit

@MainActor
final class ModelManagementRulesTests: XCTestCase {
    func testCannotSelectUndownloadedLocalModel() throws {
        let appState = try makeAppState()
        XCTAssertTrue(appState.readyLocalModelIDs.isEmpty, "Precondition: no downloaded models")

        let original = appState.transcriptionPreferences.selectedModelID
        let target = try XCTUnwrap(
            appState.modelCatalog.localModels.first(where: { $0.id != original })
        )

        appState.selectLocalModel(target.id)

        XCTAssertEqual(
            appState.transcriptionPreferences.selectedModelID,
            original,
            "Selecting an undownloaded model must be rejected"
        )
    }

    func testTranscriptionNotConfiguredWithoutModelsOrProviders() throws {
        let appState = try makeAppState()
        XCTAssertFalse(appState.isTranscriptionConfigured)
        XCTAssertFalse(appState.canEnableAutoTranscribe)
    }

    func testUnconfiguredDictationDoesNotQueueTranscription() throws {
        let appState = try makeAppState()
        appState.transcriptionPreferences.autoTranscribeAfterCapture = true

        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModelManagementRulesTests-rec-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        let audioURL = rootDirectory.appendingPathComponent("rec.wav")
        try Data("fake".utf8).write(to: audioURL)

        appState.appendPendingRecording(
            RecordedAudioAsset(url: audioURL, createdAt: .now, durationSeconds: 1, fileSizeBytes: 4)
        )

        let entry = try XCTUnwrap(appState.historyStore.entries.first)
        XCTAssertFalse(appState.transcriptionQueueController.isQueuedOrRunning(entryID: entry.id))
        if case .unconfigured = appState.overlaySupplementalPhase {
        } else {
            XCTFail("Expected unconfigured overlay phase")
        }
    }

    private func makeAppState() throws -> AppState {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModelManagementRulesTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)

        let layout = AppStorageLayout(
            fileManager: .default,
            applicationSupportURLProvider: { rootDirectory }
        )
        let suiteName = "TranscriptorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        return AppState(
            preferencesStore: AppPreferencesStore(defaults: defaults),
            storageLayout: layout,
            historyRepository: try HistoryRepository(inMemory: true),
            launchAtLoginService: TestLaunchAtLoginService(),
            secretStore: TestSecretStore()
        )
    }
}

@MainActor
private final class TestLaunchAtLoginService: LaunchAtLoginServing {
    var status = LaunchAtLoginStatus.needsPackagedApp
    func refreshStatus() -> LaunchAtLoginStatus { status }
    func setEnabled(_ enabled: Bool) -> LaunchAtLoginStatus { status }
    func openSystemSettings() {}
}

private struct TestSecretStore: SecretStore {
    func secret(for account: String) throws -> String? { nil }
    func saveSecret(_ secret: String, for account: String) throws {}
    func deleteSecret(for account: String) throws {}
    func containsSecret(for account: String) throws -> Bool { false }
}
