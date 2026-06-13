import XCTest
@testable import TranscriptorKit

@MainActor
final class AppStateInsertionFlowTests: XCTestCase {
    func testInsertionEnabledQueuesTranscriptionImmediatelyAfterRecording() throws {
        let context = try makeReadyCloudContext()
        let appState = context.appState
        appState.generalSettings.insertTranscriptIntoActiveApp = true
        appState.transcriptionPreferences.autoTranscribeAfterCapture = false

        appState.appendPendingRecording(try makeRecording(in: context.rootDirectory))

        let entry = try XCTUnwrap(appState.historyStore.entries.first)
        XCTAssertTrue(appState.transcriptionQueueController.isQueuedOrRunning(entryID: entry.id))
        XCTAssertEqual(appState.historyActionMessage?.hasPrefix("Queued"), true)
    }

    func testConfiguredDictationTranscribesEvenWithInsertionOff() throws {
        // When a transcription provider is configured, a dictation capture
        // always transcribes (Flow A) so the user gets a transcript preview;
        // the insertion toggle only controls whether it pastes vs. previews.
        let context = try makeReadyCloudContext()
        let appState = context.appState
        appState.generalSettings.insertTranscriptIntoActiveApp = false
        appState.transcriptionPreferences.autoTranscribeAfterCapture = false

        appState.appendPendingRecording(try makeRecording(in: context.rootDirectory))

        let entry = try XCTUnwrap(appState.historyStore.entries.first)
        XCTAssertTrue(appState.transcriptionQueueController.isQueuedOrRunning(entryID: entry.id))
    }

    func testCompletedTranscriptionCallsInsertionService() async throws {
        let context = try makeReadyCloudContext()
        let appState = context.appState
        appState.generalSettings.insertTranscriptIntoActiveApp = true

        appState.appendPendingRecording(try makeRecording(in: context.rootDirectory))

        var entry = try XCTUnwrap(appState.historyStore.entries.first)
        entry.transcriptText = "Dictated text"
        entry.transcriptionStatus = .completed
        appState.handleCompletedTranscription(for: entry)

        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(context.insertionService.insertedTexts, ["Dictated text"])
        if case .saved = appState.overlaySupplementalPhase {
        } else {
            XCTFail("Expected saved overlay phase, got \(String(describing: appState.overlaySupplementalPhase))")
        }
    }

    func testMissingSetupShowsUnconfiguredCardAndKeepsRecording() throws {
        // Flow B: no transcription configured. The recording is kept (pending,
        // not failed) and the overlay shows the recorder result card rather than
        // attempting and failing a transcription.
        let context = try makeContext(secrets: [:])
        let appState = context.appState
        appState.generalSettings.insertTranscriptIntoActiveApp = true

        appState.appendPendingRecording(try makeRecording(in: context.rootDirectory))

        let entry = try XCTUnwrap(appState.historyStore.entries.first)
        XCTAssertEqual(entry.transcriptionStatus, .pending)
        XCTAssertFalse(appState.transcriptionQueueController.isQueuedOrRunning(entryID: entry.id))
        XCTAssertTrue(context.insertionService.clearCapturedTargetCallCount >= 1)

        if case let .unconfigured(payload) = appState.overlaySupplementalPhase {
            XCTAssertEqual(payload.entryID, entry.id)
        } else {
            XCTFail("Expected unconfigured overlay phase, got \(String(describing: appState.overlaySupplementalPhase))")
        }
    }

    func testCompletedTranscriptionWithoutFocusedFieldShowsPreview() async throws {
        // Flow A, no focused field: insertion service reports savedOnly, so the
        // overlay shows the interactive transcript preview.
        let context = try makeReadyCloudContext()
        let appState = context.appState
        appState.generalSettings.insertTranscriptIntoActiveApp = false

        appState.appendPendingRecording(try makeRecording(in: context.rootDirectory))

        var entry = try XCTUnwrap(appState.historyStore.entries.first)
        entry.transcriptText = "Preview me"
        entry.transcriptionStatus = .completed
        appState.handleCompletedTranscription(for: entry)

        try await Task.sleep(for: .milliseconds(100))

        if case let .preview(payload) = appState.overlaySupplementalPhase {
            XCTAssertEqual(payload.transcript, "Preview me")
        } else {
            XCTFail("Expected preview overlay phase, got \(String(describing: appState.overlaySupplementalPhase))")
        }
    }

    // MARK: - Mandatory setup gate

    func testSetupGateRequiredWhenNothingConfigured() throws {
        let appState = try makeContext(secrets: [:]).appState

        XCTAssertFalse(appState.isTranscriptionConfigured)
        XCTAssertTrue(appState.requiresModelSetup)
        XCTAssertTrue(appState.shouldAutoPresentWelcomeGuide)
        XCTAssertNotNil(appState.recommendedSetupModel, "There must always be a recommended model to offer.")
    }

    func testSetupGateCannotBeDismissedUntilConfigured() throws {
        let appState = try makeContext(secrets: [:]).appState
        appState.presentWelcomeGuide()
        XCTAssertTrue(appState.isPresentingWelcomeGuide)

        // Dismissal is blocked while setup is still required.
        appState.dismissWelcomeGuide()
        XCTAssertTrue(appState.isPresentingWelcomeGuide)
    }

    func testSetupGateDismissesOnceProviderIsReady() throws {
        let appState = try makeReadyCloudContext().appState
        appState.presentWelcomeGuide()

        XCTAssertFalse(appState.requiresModelSetup)
        XCTAssertFalse(appState.shouldAutoPresentWelcomeGuide)

        appState.dismissWelcomeGuide()
        XCTAssertFalse(appState.isPresentingWelcomeGuide)
    }

    func testSuppressSetupGateBlocksAutoPresentForQA() throws {
        let appState = try makeContext(secrets: [:]).appState
        appState.suppressSetupGate = true

        XCTAssertTrue(appState.requiresModelSetup)
        XCTAssertFalse(appState.shouldAutoPresentWelcomeGuide)
    }

    // MARK: - Helpers

    private struct Context {
        let appState: AppState
        let insertionService: MockInsertionService
        let rootDirectory: URL
    }

    /// Cloud-ready configuration: OpenAI enabled, key stored, privacy acknowledged,
    /// and a hanging stub provider so queued jobs stay deterministic during asserts.
    private func makeReadyCloudContext() throws -> Context {
        let context = try makeContext(secrets: ["openai-api-key": "sk-test"])
        context.appState.providerSettings.openAIEnabled = true
        context.appState.providerSettings.openAIPrivacyAcknowledged = true
        context.appState.transcriptionPreferences.preferredProviderID = "openai"
        context.appState.transcriptionQueueController.replaceProviders([HangingProvider()])
        return context
    }

    private func makeContext(secrets: [String: String]) throws -> Context {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppStateInsertionFlowTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)

        let layout = AppStorageLayout(
            fileManager: .default,
            applicationSupportURLProvider: { rootDirectory }
        )
        let suiteName = "TranscriptorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let insertionService = MockInsertionService()
        let appState = AppState(
            preferencesStore: AppPreferencesStore(defaults: defaults),
            storageLayout: layout,
            historyRepository: try HistoryRepository(inMemory: true),
            transcriptInsertionService: insertionService,
            launchAtLoginService: StubLaunchAtLoginService(),
            secretStore: InMemoryFlowSecretStore(secrets: secrets)
        )

        return Context(appState: appState, insertionService: insertionService, rootDirectory: rootDirectory)
    }

    private func makeRecording(in rootDirectory: URL) throws -> RecordedAudioAsset {
        let audioURL = rootDirectory.appendingPathComponent("dictation-\(UUID().uuidString).wav")
        try Data("fake audio".utf8).write(to: audioURL)

        return RecordedAudioAsset(
            url: audioURL,
            createdAt: .now,
            durationSeconds: 2,
            fileSizeBytes: 10
        )
    }
}

@MainActor
private final class MockInsertionService: TranscriptInsertionServing {
    var accessibilityPermissionStatus: AccessibilityPermissionStatus = .granted
    var hasCapturedTarget = false
    var debugSnapshot = TranscriptInsertionDebugSnapshot()
    var insertedTexts: [String] = []
    var clearCapturedTargetCallCount = 0

    func refreshPermissionStatus() {}
    func requestAccessibilityPermissionPrompt() {}
    func openAccessibilitySettings() {}

    func captureCurrentTargetIfNeeded() {
        hasCapturedTarget = true
    }

    func clearCapturedTarget() {
        clearCapturedTargetCallCount += 1
        hasCapturedTarget = false
    }

    func insertCapturedTranscript(_ text: String, settings: GeneralSettings) async -> TranscriptInsertionOutcome {
        insertedTexts.append(text)
        guard settings.insertTranscriptIntoActiveApp else {
            return .savedOnly("Transcript saved to history.")
        }
        return .inserted("Transcript inserted into the active app.")
    }
}

@MainActor
private final class StubLaunchAtLoginService: LaunchAtLoginServing {
    var status = LaunchAtLoginStatus.needsPackagedApp

    func refreshStatus() -> LaunchAtLoginStatus { status }
    func setEnabled(_ enabled: Bool) -> LaunchAtLoginStatus { status }
    func openSystemSettings() {}
}

private struct InMemoryFlowSecretStore: SecretStore {
    var secrets: [String: String]

    func secret(for account: String) throws -> String? { secrets[account] }
    func saveSecret(_ secret: String, for account: String) throws {}
    func deleteSecret(for account: String) throws {}
    func containsSecret(for account: String) throws -> Bool { secrets[account] != nil }
}

private struct HangingProvider: TranscriptionProvider {
    let id = "openai"
    let displayName = "OpenAI"
    let kind = TranscriptionProviderKind.cloud

    func transcribe(
        job: TranscriptionJob,
        progressHandler: @escaping @Sendable (TranscriptionProgress) -> Void
    ) async throws -> TranscriptionResult {
        try await Task.sleep(for: .seconds(60))
        throw TranscriptionError.cancelled
    }
}
