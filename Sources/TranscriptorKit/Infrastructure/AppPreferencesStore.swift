import Carbon
import Foundation

public struct AppPreferencesSnapshot: Equatable, Sendable {
    public var launchAtLoginEnabled: Bool
    public var showMenuBarIcon: Bool
    public var insertTranscriptIntoActiveApp: Bool
    public var alsoCopyTranscriptToClipboard: Bool
    public var restoreClipboardAfterInsertion: Bool
    public var recordingModeRawValue: String
    public var hotkeyKeyCode: UInt32
    public var hotkeyCarbonModifiers: UInt32
    public var saveOriginalAudio: Bool
    /// Days kept before audio is deleted; `0` keeps recordings forever. Stored
    /// separately from `saveOriginalAudio` so an older build can still read the
    /// checkbox and a newer build can add retention without losing it.
    public var audioRetentionDays: Int
    public var overlayEnabled: Bool
    public var overlayIsNonActivating: Bool
    public var overlayShowsLiveIndicator: Bool
    public var overlayPositionRawValue: String
    public var overlayDisplayModeRawValue: String
    public var selectedModelID: String
    public var autoTranscribeAfterCapture: Bool
    public var preferredLocalProviderID: String
    public var preferredProviderID: String
    public var historyLimitMegabytes: Int
    public var autoDeleteOldestHistory: Bool
    public var excludesDownloadedModels: Bool
    public var openAIEnabled: Bool
    public var groqEnabled: Bool
    public var elevenLabsEnabled: Bool
    public var openAIModelID: String
    public var groqModelID: String
    public var elevenLabsModelID: String
    public var openAIPrivacyAcknowledged: Bool
    public var groqPrivacyAcknowledged: Bool
    public var elevenLabsPrivacyAcknowledged: Bool
    public var openAICredentialValidated: Bool
    public var groqCredentialValidated: Bool
    public var elevenLabsCredentialValidated: Bool
    public var transcriptionLanguage: String
    public var showDockIcon: Bool
    public var customBaseURL: String
    public var customModelID: String
    public var customPrivacyAcknowledged: Bool
    public var customCredentialValidated: Bool

    public init(
        launchAtLoginEnabled: Bool = false,
        showMenuBarIcon: Bool = true,
        insertTranscriptIntoActiveApp: Bool = true,
        alsoCopyTranscriptToClipboard: Bool = false,
        restoreClipboardAfterInsertion: Bool = true,
        recordingModeRawValue: String = RecordingMode.holdToTalk.rawValue,
        hotkeyKeyCode: UInt32 = UInt32(kVK_ANSI_D),
        hotkeyCarbonModifiers: UInt32 = UInt32(optionKey),
        saveOriginalAudio: Bool = true,
        audioRetentionDays: Int = AudioRetentionWindow.forever.rawValue,
        overlayEnabled: Bool = true,
        overlayIsNonActivating: Bool = true,
        overlayShowsLiveIndicator: Bool = true,
        overlayPositionRawValue: String = OverlayPosition.topCenter.rawValue,
        overlayDisplayModeRawValue: String = OverlayDisplayMode.standard.rawValue,
        selectedModelID: String = "whisper-large-v3-turbo",
        autoTranscribeAfterCapture: Bool = false,
        preferredLocalProviderID: String = "whisperkit-local",
        preferredProviderID: String = "whisperkit-local",
        historyLimitMegabytes: Int = 2_048,
        autoDeleteOldestHistory: Bool = true,
        excludesDownloadedModels: Bool = true,
        openAIEnabled: Bool = false,
        groqEnabled: Bool = false,
        elevenLabsEnabled: Bool = false,
        openAIModelID: String = "gpt-4o-mini-transcribe",
        groqModelID: String = "whisper-large-v3-turbo",
        elevenLabsModelID: String = "scribe_v3",
        openAIPrivacyAcknowledged: Bool = false,
        groqPrivacyAcknowledged: Bool = false,
        elevenLabsPrivacyAcknowledged: Bool = false,
        openAICredentialValidated: Bool = false,
        groqCredentialValidated: Bool = false,
        elevenLabsCredentialValidated: Bool = false,
        transcriptionLanguage: String = "",
        showDockIcon: Bool = false,
        customBaseURL: String = "",
        customModelID: String = "whisper-1",
        customPrivacyAcknowledged: Bool = false,
        customCredentialValidated: Bool = false
    ) {
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.showMenuBarIcon = showMenuBarIcon
        self.insertTranscriptIntoActiveApp = insertTranscriptIntoActiveApp
        self.alsoCopyTranscriptToClipboard = alsoCopyTranscriptToClipboard
        self.restoreClipboardAfterInsertion = restoreClipboardAfterInsertion
        self.recordingModeRawValue = recordingModeRawValue
        self.hotkeyKeyCode = hotkeyKeyCode
        self.hotkeyCarbonModifiers = hotkeyCarbonModifiers
        self.saveOriginalAudio = saveOriginalAudio
        self.audioRetentionDays = audioRetentionDays
        self.overlayEnabled = overlayEnabled
        self.overlayIsNonActivating = overlayIsNonActivating
        self.overlayShowsLiveIndicator = overlayShowsLiveIndicator
        self.overlayPositionRawValue = overlayPositionRawValue
        self.overlayDisplayModeRawValue = overlayDisplayModeRawValue
        self.selectedModelID = selectedModelID
        self.autoTranscribeAfterCapture = autoTranscribeAfterCapture
        self.preferredLocalProviderID = preferredLocalProviderID
        self.preferredProviderID = preferredProviderID
        self.historyLimitMegabytes = historyLimitMegabytes
        self.autoDeleteOldestHistory = autoDeleteOldestHistory
        self.excludesDownloadedModels = excludesDownloadedModels
        self.openAIEnabled = openAIEnabled
        self.groqEnabled = groqEnabled
        self.elevenLabsEnabled = elevenLabsEnabled
        self.openAIModelID = openAIModelID
        self.groqModelID = groqModelID
        self.elevenLabsModelID = elevenLabsModelID
        self.openAIPrivacyAcknowledged = openAIPrivacyAcknowledged
        self.groqPrivacyAcknowledged = groqPrivacyAcknowledged
        self.elevenLabsPrivacyAcknowledged = elevenLabsPrivacyAcknowledged
        self.openAICredentialValidated = openAICredentialValidated
        self.groqCredentialValidated = groqCredentialValidated
        self.elevenLabsCredentialValidated = elevenLabsCredentialValidated
        self.transcriptionLanguage = transcriptionLanguage
        self.showDockIcon = showDockIcon
        self.customBaseURL = customBaseURL
        self.customModelID = customModelID
        self.customPrivacyAcknowledged = customPrivacyAcknowledged
        self.customCredentialValidated = customCredentialValidated
    }
}

private struct CodableAppPreferencesSnapshot: Codable {
    var launchAtLoginEnabled: Bool
    var showMenuBarIcon: Bool?
    var insertTranscriptIntoActiveApp: Bool?
    var alsoCopyTranscriptToClipboard: Bool?
    var restoreClipboardAfterInsertion: Bool?
    var recordingModeRawValue: String
    var hotkeyKeyCode: UInt32
    var hotkeyCarbonModifiers: UInt32
    var saveOriginalAudio: Bool
    var audioRetentionDays: Int?
    var overlayEnabled: Bool
    var overlayIsNonActivating: Bool
    var overlayShowsLiveIndicator: Bool
    var overlayPositionRawValue: String
    var overlayDisplayModeRawValue: String?
    var selectedModelID: String
    var autoTranscribeAfterCapture: Bool?
    var preferredLocalProviderID: String?
    var preferredProviderID: String?
    var historyLimitMegabytes: Int
    var autoDeleteOldestHistory: Bool
    var excludesDownloadedModels: Bool
    var openAIEnabled: Bool
    var groqEnabled: Bool
    var elevenLabsEnabled: Bool?
    var openAIModelID: String?
    var groqModelID: String?
    var elevenLabsModelID: String?
    var openAIPrivacyAcknowledged: Bool?
    var groqPrivacyAcknowledged: Bool?
    var elevenLabsPrivacyAcknowledged: Bool?
    var openAICredentialValidated: Bool?
    var groqCredentialValidated: Bool?
    var elevenLabsCredentialValidated: Bool?
    var transcriptionLanguage: String?
    var showDockIcon: Bool?
    var customBaseURL: String?
    var customModelID: String?
    var customPrivacyAcknowledged: Bool?
    var customCredentialValidated: Bool?
}

@MainActor
public final class AppPreferencesStore {
    public static let standard = AppPreferencesStore()

    private let defaults: UserDefaults
    private let key = "com.transcriptor.preferences"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppPreferencesSnapshot {
        guard
            let data = defaults.data(forKey: key),
            let decoded = try? decoder.decode(CodableAppPreferencesSnapshot.self, from: data)
        else {
            return AppPreferencesSnapshot()
        }

        return AppPreferencesSnapshot(
            launchAtLoginEnabled: decoded.launchAtLoginEnabled,
            showMenuBarIcon: decoded.showMenuBarIcon ?? true,
            insertTranscriptIntoActiveApp: decoded.insertTranscriptIntoActiveApp ?? true,
            alsoCopyTranscriptToClipboard: decoded.alsoCopyTranscriptToClipboard ?? false,
            restoreClipboardAfterInsertion: decoded.restoreClipboardAfterInsertion ?? true,
            recordingModeRawValue: decoded.recordingModeRawValue,
            hotkeyKeyCode: Self.migratedHotkeyKeyCode(
                keyCode: decoded.hotkeyKeyCode,
                carbonModifiers: decoded.hotkeyCarbonModifiers
            ),
            hotkeyCarbonModifiers: Self.migratedHotkeyModifiers(
                keyCode: decoded.hotkeyKeyCode,
                carbonModifiers: decoded.hotkeyCarbonModifiers
            ),
            saveOriginalAudio: decoded.saveOriginalAudio,
            audioRetentionDays: decoded.audioRetentionDays ?? AudioRetentionWindow.forever.rawValue,
            overlayEnabled: decoded.overlayEnabled,
            overlayIsNonActivating: decoded.overlayIsNonActivating,
            overlayShowsLiveIndicator: decoded.overlayShowsLiveIndicator,
            overlayPositionRawValue: decoded.overlayPositionRawValue,
            overlayDisplayModeRawValue: decoded.overlayDisplayModeRawValue ?? OverlayDisplayMode.standard.rawValue,
            selectedModelID: decoded.selectedModelID,
            autoTranscribeAfterCapture: decoded.autoTranscribeAfterCapture ?? false,
            preferredLocalProviderID: decoded.preferredLocalProviderID ?? "whisperkit-local",
            preferredProviderID: decoded.preferredProviderID ?? "whisperkit-local",
            historyLimitMegabytes: decoded.historyLimitMegabytes,
            autoDeleteOldestHistory: decoded.autoDeleteOldestHistory,
            excludesDownloadedModels: decoded.excludesDownloadedModels,
            openAIEnabled: decoded.openAIEnabled,
            groqEnabled: decoded.groqEnabled,
            elevenLabsEnabled: decoded.elevenLabsEnabled ?? false,
            openAIModelID: decoded.openAIModelID ?? "gpt-4o-mini-transcribe",
            groqModelID: decoded.groqModelID ?? "whisper-large-v3-turbo",
            // One-time migration: scribe_v1 and scribe_v2 are superseded by
            // scribe_v3 (same API, lower WER); stored IDs are bumped on load.
            elevenLabsModelID: (decoded.elevenLabsModelID.map { id in
                (id == "scribe_v1" || id == "scribe_v2") ? "scribe_v3" : id
            }) ?? "scribe_v3",
            openAIPrivacyAcknowledged: decoded.openAIPrivacyAcknowledged ?? false,
            groqPrivacyAcknowledged: decoded.groqPrivacyAcknowledged ?? false,
            elevenLabsPrivacyAcknowledged: decoded.elevenLabsPrivacyAcknowledged ?? false,
            openAICredentialValidated: decoded.openAICredentialValidated ?? false,
            groqCredentialValidated: decoded.groqCredentialValidated ?? false,
            elevenLabsCredentialValidated: decoded.elevenLabsCredentialValidated ?? false,
            transcriptionLanguage: decoded.transcriptionLanguage ?? "",
            showDockIcon: decoded.showDockIcon ?? false,
            customBaseURL: decoded.customBaseURL ?? "",
            customModelID: decoded.customModelID ?? "whisper-1",
            customPrivacyAcknowledged: decoded.customPrivacyAcknowledged ?? false,
            customCredentialValidated: decoded.customCredentialValidated ?? false
        )
    }

    /// One-time hotkey migration: builds before Option+D shipped defaulted to
    /// Option+Shift+Space. Only that exact old default is rewritten; any custom
    /// shortcut the user chose is left untouched.
    private static let legacyDefaultHotkeyKeyCode = UInt32(kVK_Space)
    private static let legacyDefaultHotkeyModifiers = UInt32(optionKey | shiftKey)
    private static let defaultHotkeyKeyCode = UInt32(kVK_ANSI_D)
    private static let defaultHotkeyModifiers = UInt32(optionKey)

    private static func usesLegacyDefaultHotkey(keyCode: UInt32, carbonModifiers: UInt32) -> Bool {
        keyCode == legacyDefaultHotkeyKeyCode && carbonModifiers == legacyDefaultHotkeyModifiers
    }

    static func migratedHotkeyKeyCode(keyCode: UInt32, carbonModifiers: UInt32) -> UInt32 {
        usesLegacyDefaultHotkey(keyCode: keyCode, carbonModifiers: carbonModifiers)
            ? defaultHotkeyKeyCode
            : keyCode
    }

    static func migratedHotkeyModifiers(keyCode: UInt32, carbonModifiers: UInt32) -> UInt32 {
        usesLegacyDefaultHotkey(keyCode: keyCode, carbonModifiers: carbonModifiers)
            ? defaultHotkeyModifiers
            : carbonModifiers
    }

    public func save(_ snapshot: AppPreferencesSnapshot) {
        let codableSnapshot = CodableAppPreferencesSnapshot(
            launchAtLoginEnabled: snapshot.launchAtLoginEnabled,
            showMenuBarIcon: snapshot.showMenuBarIcon,
            insertTranscriptIntoActiveApp: snapshot.insertTranscriptIntoActiveApp,
            alsoCopyTranscriptToClipboard: snapshot.alsoCopyTranscriptToClipboard,
            restoreClipboardAfterInsertion: snapshot.restoreClipboardAfterInsertion,
            recordingModeRawValue: snapshot.recordingModeRawValue,
            hotkeyKeyCode: snapshot.hotkeyKeyCode,
            hotkeyCarbonModifiers: snapshot.hotkeyCarbonModifiers,
            saveOriginalAudio: snapshot.saveOriginalAudio,
            audioRetentionDays: snapshot.audioRetentionDays,
            overlayEnabled: snapshot.overlayEnabled,
            overlayIsNonActivating: snapshot.overlayIsNonActivating,
            overlayShowsLiveIndicator: snapshot.overlayShowsLiveIndicator,
            overlayPositionRawValue: snapshot.overlayPositionRawValue,
            overlayDisplayModeRawValue: snapshot.overlayDisplayModeRawValue,
            selectedModelID: snapshot.selectedModelID,
            autoTranscribeAfterCapture: snapshot.autoTranscribeAfterCapture,
            preferredLocalProviderID: snapshot.preferredLocalProviderID,
            preferredProviderID: snapshot.preferredProviderID,
            historyLimitMegabytes: snapshot.historyLimitMegabytes,
            autoDeleteOldestHistory: snapshot.autoDeleteOldestHistory,
            excludesDownloadedModels: snapshot.excludesDownloadedModels,
            openAIEnabled: snapshot.openAIEnabled,
            groqEnabled: snapshot.groqEnabled,
            elevenLabsEnabled: snapshot.elevenLabsEnabled,
            openAIModelID: snapshot.openAIModelID,
            groqModelID: snapshot.groqModelID,
            elevenLabsModelID: snapshot.elevenLabsModelID,
            openAIPrivacyAcknowledged: snapshot.openAIPrivacyAcknowledged,
            groqPrivacyAcknowledged: snapshot.groqPrivacyAcknowledged,
            elevenLabsPrivacyAcknowledged: snapshot.elevenLabsPrivacyAcknowledged,
            openAICredentialValidated: snapshot.openAICredentialValidated,
            groqCredentialValidated: snapshot.groqCredentialValidated,
            elevenLabsCredentialValidated: snapshot.elevenLabsCredentialValidated,
            transcriptionLanguage: snapshot.transcriptionLanguage,
            showDockIcon: snapshot.showDockIcon,
            customBaseURL: snapshot.customBaseURL,
            customModelID: snapshot.customModelID,
            customPrivacyAcknowledged: snapshot.customPrivacyAcknowledged,
            customCredentialValidated: snapshot.customCredentialValidated
        )

        guard let data = try? encoder.encode(codableSnapshot) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
