import Carbon
import Foundation

public struct AppPreferencesSnapshot: Equatable, Sendable {
    public var launchAtLoginEnabled: Bool
    public var recordingModeRawValue: String
    public var hotkeyKeyCode: UInt32
    public var hotkeyCarbonModifiers: UInt32
    public var saveOriginalAudio: Bool
    public var overlayEnabled: Bool
    public var overlayIsNonActivating: Bool
    public var overlayShowsLiveIndicator: Bool
    public var overlayPositionRawValue: String
    public var selectedModelID: String
    public var historyLimitMegabytes: Int
    public var autoDeleteOldestHistory: Bool
    public var excludesDownloadedModels: Bool
    public var openAIEnabled: Bool
    public var groqEnabled: Bool

    public init(
        launchAtLoginEnabled: Bool = false,
        recordingModeRawValue: String = RecordingMode.holdToTalk.rawValue,
        hotkeyKeyCode: UInt32 = UInt32(kVK_Space),
        hotkeyCarbonModifiers: UInt32 = UInt32(optionKey | shiftKey),
        saveOriginalAudio: Bool = true,
        overlayEnabled: Bool = true,
        overlayIsNonActivating: Bool = true,
        overlayShowsLiveIndicator: Bool = true,
        overlayPositionRawValue: String = OverlayPosition.topCenter.rawValue,
        selectedModelID: String = "whisper-large-v3-turbo",
        historyLimitMegabytes: Int = 2_048,
        autoDeleteOldestHistory: Bool = true,
        excludesDownloadedModels: Bool = true,
        openAIEnabled: Bool = false,
        groqEnabled: Bool = false
    ) {
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.recordingModeRawValue = recordingModeRawValue
        self.hotkeyKeyCode = hotkeyKeyCode
        self.hotkeyCarbonModifiers = hotkeyCarbonModifiers
        self.saveOriginalAudio = saveOriginalAudio
        self.overlayEnabled = overlayEnabled
        self.overlayIsNonActivating = overlayIsNonActivating
        self.overlayShowsLiveIndicator = overlayShowsLiveIndicator
        self.overlayPositionRawValue = overlayPositionRawValue
        self.selectedModelID = selectedModelID
        self.historyLimitMegabytes = historyLimitMegabytes
        self.autoDeleteOldestHistory = autoDeleteOldestHistory
        self.excludesDownloadedModels = excludesDownloadedModels
        self.openAIEnabled = openAIEnabled
        self.groqEnabled = groqEnabled
    }
}

private struct CodableAppPreferencesSnapshot: Codable {
    var launchAtLoginEnabled: Bool
    var recordingModeRawValue: String
    var hotkeyKeyCode: UInt32
    var hotkeyCarbonModifiers: UInt32
    var saveOriginalAudio: Bool
    var overlayEnabled: Bool
    var overlayIsNonActivating: Bool
    var overlayShowsLiveIndicator: Bool
    var overlayPositionRawValue: String
    var selectedModelID: String
    var historyLimitMegabytes: Int
    var autoDeleteOldestHistory: Bool
    var excludesDownloadedModels: Bool
    var openAIEnabled: Bool
    var groqEnabled: Bool
}

public final class AppPreferencesStore {
    public static let standard = AppPreferencesStore()

    private let defaults: UserDefaults
    private let key = "com.sotto.preferences"
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
            recordingModeRawValue: decoded.recordingModeRawValue,
            hotkeyKeyCode: decoded.hotkeyKeyCode,
            hotkeyCarbonModifiers: decoded.hotkeyCarbonModifiers,
            saveOriginalAudio: decoded.saveOriginalAudio,
            overlayEnabled: decoded.overlayEnabled,
            overlayIsNonActivating: decoded.overlayIsNonActivating,
            overlayShowsLiveIndicator: decoded.overlayShowsLiveIndicator,
            overlayPositionRawValue: decoded.overlayPositionRawValue,
            selectedModelID: decoded.selectedModelID,
            historyLimitMegabytes: decoded.historyLimitMegabytes,
            autoDeleteOldestHistory: decoded.autoDeleteOldestHistory,
            excludesDownloadedModels: decoded.excludesDownloadedModels,
            openAIEnabled: decoded.openAIEnabled,
            groqEnabled: decoded.groqEnabled
        )
    }

    public func save(_ snapshot: AppPreferencesSnapshot) {
        let codableSnapshot = CodableAppPreferencesSnapshot(
            launchAtLoginEnabled: snapshot.launchAtLoginEnabled,
            recordingModeRawValue: snapshot.recordingModeRawValue,
            hotkeyKeyCode: snapshot.hotkeyKeyCode,
            hotkeyCarbonModifiers: snapshot.hotkeyCarbonModifiers,
            saveOriginalAudio: snapshot.saveOriginalAudio,
            overlayEnabled: snapshot.overlayEnabled,
            overlayIsNonActivating: snapshot.overlayIsNonActivating,
            overlayShowsLiveIndicator: snapshot.overlayShowsLiveIndicator,
            overlayPositionRawValue: snapshot.overlayPositionRawValue,
            selectedModelID: snapshot.selectedModelID,
            historyLimitMegabytes: snapshot.historyLimitMegabytes,
            autoDeleteOldestHistory: snapshot.autoDeleteOldestHistory,
            excludesDownloadedModels: snapshot.excludesDownloadedModels,
            openAIEnabled: snapshot.openAIEnabled,
            groqEnabled: snapshot.groqEnabled
        )

        guard let data = try? encoder.encode(codableSnapshot) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
