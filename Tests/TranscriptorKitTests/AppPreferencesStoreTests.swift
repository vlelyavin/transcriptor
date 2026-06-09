import XCTest
@testable import TranscriptorKit

@MainActor
final class AppPreferencesStoreTests: XCTestCase {
    func testPreferencesRoundTripPersistsAcrossStoreInstances() {
        let suiteName = "TranscriptorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let snapshot = AppPreferencesSnapshot(
            launchAtLoginEnabled: true,
            showMenuBarIcon: false,
            insertTranscriptIntoActiveApp: false,
            alsoCopyTranscriptToClipboard: true,
            restoreClipboardAfterInsertion: false,
            recordingModeRawValue: RecordingMode.toggleToTalk.rawValue,
            hotkeyKeyCode: 15,
            hotkeyCarbonModifiers: 2,
            saveOriginalAudio: false,
            overlayEnabled: false,
            overlayIsNonActivating: true,
            overlayShowsLiveIndicator: false,
            overlayPositionRawValue: OverlayPosition.bottomCenter.rawValue,
            selectedModelID: "whisper-tiny",
            autoTranscribeAfterCapture: true,
            preferredLocalProviderID: "whisperkit-local",
            preferredProviderID: "openai",
            historyLimitMegabytes: 512,
            autoDeleteOldestHistory: false,
            excludesDownloadedModels: true,
            openAIEnabled: true,
            groqEnabled: true,
            openAIModelID: "gpt-4o-transcribe",
            groqModelID: "whisper-large-v3",
            openAIPrivacyAcknowledged: true,
            groqPrivacyAcknowledged: false
        )

        AppPreferencesStore(defaults: defaults).save(snapshot)
        let reloaded = AppPreferencesStore(defaults: defaults).load()

        XCTAssertEqual(reloaded, snapshot)
    }
}
