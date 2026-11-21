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
            saveOriginalAudio: false,
            audioRetentionDays: 30,
            overlayEnabled: false,
            overlayIsNonActivating: true,
            overlayShowsLiveIndicator: false,
            overlayPositionRawValue: OverlayPosition.bottomCenter.rawValue,
            overlayDisplayModeRawValue: OverlayDisplayMode.compact.rawValue,
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

    func testOverlayDisplayModeFallsBackWhenKeyIsMissing() throws {
        let suiteName = "TranscriptorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }

        let store = AppPreferencesStore(defaults: defaults)
        store.save(
            AppPreferencesSnapshot(overlayDisplayModeRawValue: OverlayDisplayMode.compact.rawValue)
        )

        // Simulate a preferences file written before the compact pill existed:
        // the new key is absent, and the loader must fall back to standard
        // instead of failing the whole decode.
        let key = "com.transcriptor.preferences"
        let data = try XCTUnwrap(defaults.data(forKey: key))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "overlayDisplayModeRawValue")
        defaults.set(try JSONSerialization.data(withJSONObject: object), forKey: key)

        XCTAssertEqual(store.load().overlayDisplayModeRawValue, OverlayDisplayMode.standard.rawValue)
    }
}
