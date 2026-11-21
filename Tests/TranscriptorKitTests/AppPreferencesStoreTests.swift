import Carbon
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
            elevenLabsEnabled: true,
            openAIModelID: "gpt-4o-transcribe",
            groqModelID: "whisper-large-v3",
            elevenLabsModelID: "scribe_v3",
            openAIPrivacyAcknowledged: true,
            groqPrivacyAcknowledged: false,
            elevenLabsPrivacyAcknowledged: true,
            elevenLabsCredentialValidated: true
        )

        AppPreferencesStore(defaults: defaults).save(snapshot)
        let reloaded = AppPreferencesStore(defaults: defaults).load()

        XCTAssertEqual(reloaded, snapshot)
    }

    func testElevenLabsModelMigratesFromOlderScribeVersions() {
        let suiteName = "TranscriptorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }

        let store = AppPreferencesStore(defaults: defaults)
        for storedModelID in ["scribe_v1", "scribe_v2"] {
            store.save(AppPreferencesSnapshot(elevenLabsModelID: storedModelID))
            XCTAssertEqual(store.load().elevenLabsModelID, "scribe_v3")
        }
    }

    func testLegacyDefaultHotkeyMigratesToOptionD() {
        let suiteName = "TranscriptorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }

        let legacyDefault = AppPreferencesSnapshot(
            hotkeyKeyCode: UInt32(kVK_Space),
            hotkeyCarbonModifiers: UInt32(optionKey | shiftKey)
        )
        AppPreferencesStore(defaults: defaults).save(legacyDefault)

        let loaded = AppPreferencesStore(defaults: defaults).load()
        XCTAssertEqual(loaded.hotkeyKeyCode, UInt32(kVK_ANSI_D))
        XCTAssertEqual(loaded.hotkeyCarbonModifiers, UInt32(optionKey))
    }

    func testCustomHotkeyIsNotMigrated() {
        let suiteName = "TranscriptorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }

        let custom = AppPreferencesSnapshot(
            hotkeyKeyCode: UInt32(kVK_ANSI_R),
            hotkeyCarbonModifiers: UInt32(controlKey | shiftKey)
        )
        AppPreferencesStore(defaults: defaults).save(custom)

        let loaded = AppPreferencesStore(defaults: defaults).load()
        XCTAssertEqual(loaded.hotkeyKeyCode, UInt32(kVK_ANSI_R))
        XCTAssertEqual(loaded.hotkeyCarbonModifiers, UInt32(controlKey | shiftKey))
    }

    func testPreferencesWithoutElevenLabsKeysDecodeToDefaults() throws {
        let suiteName = "TranscriptorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }

        let store = AppPreferencesStore(defaults: defaults)
        store.save(AppPreferencesSnapshot())

        // Simulate a preferences file written before ElevenLabs existed: all
        // its keys are absent and the loader must fall back to defaults.
        let key = "com.transcriptor.preferences"
        let data = try XCTUnwrap(defaults.data(forKey: key))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in [
            "elevenLabsEnabled",
            "elevenLabsModelID",
            "elevenLabsPrivacyAcknowledged",
            "elevenLabsCredentialValidated",
        ] {
            object.removeValue(forKey: key)
        }
        defaults.set(try JSONSerialization.data(withJSONObject: object), forKey: key)

        let loaded = store.load()
        XCTAssertFalse(loaded.elevenLabsEnabled)
        XCTAssertEqual(loaded.elevenLabsModelID, "scribe_v3")
        XCTAssertFalse(loaded.elevenLabsPrivacyAcknowledged)
        XCTAssertFalse(loaded.elevenLabsCredentialValidated)
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
