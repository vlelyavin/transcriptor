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
    public var overlayEnabled: Bool
    public var overlayIsNonActivating: Bool
    public var overlayShowsLiveIndicator: Bool
    public var overlayPositionRawValue: String
    public var selectedModelID: String
    public var autoTranscribeAfterCapture: Bool
    public var preferredLocalProviderID: String
    public var preferredProviderID: String
    public var historyLimitMegabytes: Int
    public var autoDeleteOldestHistory: Bool
    public var excludesDownloadedModels: Bool
    public var openAIEnabled: Bool
    public var groqEnabled: Bool
    public var openAIModelID: String
    public var groqModelID: String
    public var openAIPrivacyAcknowledged: Bool
    public var groqPrivacyAcknowledged: Bool

    public init(
        launchAtLoginEnabled: Bool = false,
        showMenuBarIcon: Bool = true,
        insertTranscriptIntoActiveApp: Bool = true,
        alsoCopyTranscriptToClipboard: Bool = false,
        restoreClipboardAfterInsertion: Bool = true,
        recordingModeRawValue: String = RecordingMode.holdToTalk.rawValue,
        hotkeyKeyCode: UInt32 = UInt32(kVK_Space),
        hotkeyCarbonModifiers: UInt32 = UInt32(optionKey | shiftKey),
        saveOriginalAudio: Bool = true,
        overlayEnabled: Bool = true,
        overlayIsNonActivating: Bool = true,
        overlayShowsLiveIndicator: Bool = true,
        overlayPositionRawValue: String = OverlayPosition.topCenter.rawValue,
        selectedModelID: String = "whisper-large-v3-turbo",
        autoTranscribeAfterCapture: Bool = false,
        preferredLocalProviderID: String = "whisperkit-local",
        preferredProviderID: String = "whisperkit-local",
        historyLimitMegabytes: Int = 2_048,
        autoDeleteOldestHistory: Bool = true,
        excludesDownloadedModels: Bool = true,
        openAIEnabled: Bool = false,
        groqEnabled: Bool = false,
        openAIModelID: String = "gpt-4o-mini-transcribe",
        groqModelID: String = "whisper-large-v3-turbo",
        openAIPrivacyAcknowledged: Bool = false,
        groqPrivacyAcknowledged: Bool = false
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
        self.overlayEnabled = overlayEnabled
        self.overlayIsNonActivating = overlayIsNonActivating
        self.overlayShowsLiveIndicator = overlayShowsLiveIndicator
        self.overlayPositionRawValue = overlayPositionRawValue
        self.selectedModelID = selectedModelID
        self.autoTranscribeAfterCapture = autoTranscribeAfterCapture
        self.preferredLocalProviderID = preferredLocalProviderID
        self.preferredProviderID = preferredProviderID
        self.historyLimitMegabytes = historyLimitMegabytes
        self.autoDeleteOldestHistory = autoDeleteOldestHistory
        self.excludesDownloadedModels = excludesDownloadedModels
        self.openAIEnabled = openAIEnabled
        self.groqEnabled = groqEnabled
        self.openAIModelID = openAIModelID
        self.groqModelID = groqModelID
        self.openAIPrivacyAcknowledged = openAIPrivacyAcknowledged
        self.groqPrivacyAcknowledged = groqPrivacyAcknowledged
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
    var overlayEnabled: Bool
    var overlayIsNonActivating: Bool
    var overlayShowsLiveIndicator: Bool
    var overlayPositionRawValue: String
    var selectedModelID: String
    var autoTranscribeAfterCapture: Bool?
    var preferredLocalProviderID: String?
    var preferredProviderID: String?
    var historyLimitMegabytes: Int
    var autoDeleteOldestHistory: Bool
    var excludesDownloadedModels: Bool
    var openAIEnabled: Bool
    var groqEnabled: Bool
    var openAIModelID: String?
    var groqModelID: String?
    var openAIPrivacyAcknowledged: Bool?
    var groqPrivacyAcknowledged: Bool?
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
            hotkeyKeyCode: decoded.hotkeyKeyCode,
            hotkeyCarbonModifiers: decoded.hotkeyCarbonModifiers,
            saveOriginalAudio: decoded.saveOriginalAudio,
            overlayEnabled: decoded.overlayEnabled,
            overlayIsNonActivating: decoded.overlayIsNonActivating,
            overlayShowsLiveIndicator: decoded.overlayShowsLiveIndicator,
            overlayPositionRawValue: decoded.overlayPositionRawValue,
            selectedModelID: decoded.selectedModelID,
            autoTranscribeAfterCapture: decoded.autoTranscribeAfterCapture ?? false,
            preferredLocalProviderID: decoded.preferredLocalProviderID ?? "whisperkit-local",
            preferredProviderID: decoded.preferredProviderID ?? "whisperkit-local",
            historyLimitMegabytes: decoded.historyLimitMegabytes,
            autoDeleteOldestHistory: decoded.autoDeleteOldestHistory,
            excludesDownloadedModels: decoded.excludesDownloadedModels,
            openAIEnabled: decoded.openAIEnabled,
            groqEnabled: decoded.groqEnabled,
            openAIModelID: decoded.openAIModelID ?? "gpt-4o-mini-transcribe",
            groqModelID: decoded.groqModelID ?? "whisper-large-v3-turbo",
            openAIPrivacyAcknowledged: decoded.openAIPrivacyAcknowledged ?? false,
            groqPrivacyAcknowledged: decoded.groqPrivacyAcknowledged ?? false
        )
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
            overlayEnabled: snapshot.overlayEnabled,
            overlayIsNonActivating: snapshot.overlayIsNonActivating,
            overlayShowsLiveIndicator: snapshot.overlayShowsLiveIndicator,
            overlayPositionRawValue: snapshot.overlayPositionRawValue,
            selectedModelID: snapshot.selectedModelID,
            autoTranscribeAfterCapture: snapshot.autoTranscribeAfterCapture,
            preferredLocalProviderID: snapshot.preferredLocalProviderID,
            preferredProviderID: snapshot.preferredProviderID,
            historyLimitMegabytes: snapshot.historyLimitMegabytes,
            autoDeleteOldestHistory: snapshot.autoDeleteOldestHistory,
            excludesDownloadedModels: snapshot.excludesDownloadedModels,
            openAIEnabled: snapshot.openAIEnabled,
            groqEnabled: snapshot.groqEnabled,
            openAIModelID: snapshot.openAIModelID,
            groqModelID: snapshot.groqModelID,
            openAIPrivacyAcknowledged: snapshot.openAIPrivacyAcknowledged,
            groqPrivacyAcknowledged: snapshot.groqPrivacyAcknowledged
        )

        guard let data = try? encoder.encode(codableSnapshot) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
