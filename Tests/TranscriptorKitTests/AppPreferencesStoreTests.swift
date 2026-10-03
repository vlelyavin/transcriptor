import XCTest
@testable import TranscriptorKit

@MainActor
final class AppPreferencesStoreTests: XCTestCase {
    func testPreferencesRoundTripPersistsAcrossStoreInstances() {
        let suiteName = "TranscriptorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        // Each run makes a fresh suite; without this every test left a
        // TranscriptorTests.<UUID>.plist behind in ~/Library/Preferences.
        addTeardownBlock {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }

        let snapshot = AppPreferencesSnapshot(
            launchAtLoginEnabled: true,
            showMenuBarIcon: false,
            insertTranscriptIntoActiveApp: false,
            alsoCopyTranscriptToClipboard: true,
            restoreClipboardAfterInsertion: false,
            recordingModeRawValue: RecordingMode.toggleToTalk.rawValue,
            hotkeyKeyCode: 15,
            hotkeyCarbonModifiers: 2,
            overlayEnabled: false,
            overlayShowsLiveIndicator: false,
            overlayPositionRawValue: OverlayPosition.bottomCenter.rawValue,
            selectedModelID: "whisper-tiny",
            autoTranscribeAfterCapture: true,
            preferredLocalProviderID: "whisperkit-local",
            preferredProviderID: "openai",
            openAIEnabled: true,
            groqEnabled: true,
            openAIModelID: "gpt-4o-transcribe",
            groqModelID: "whisper-large-v3",
            openAIPrivacyAcknowledged: true,
            groqPrivacyAcknowledged: false,
            transcriptionLanguage: "ru",
            showDockIcon: true,
            customBaseURL: "https://server.example/v1",
            customModelID: "whisper-1",
            customPrivacyAcknowledged: true,
            customCredentialValidated: false
        )

        AppPreferencesStore(defaults: defaults).save(snapshot)
        let reloaded = AppPreferencesStore(defaults: defaults).load()

        XCTAssertEqual(reloaded, snapshot)
    }
}
