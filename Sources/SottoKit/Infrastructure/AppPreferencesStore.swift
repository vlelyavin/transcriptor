import Foundation

public struct AppPreferencesSnapshot: Equatable, Sendable {
    public var launchAtLoginEnabled: Bool
    public var recordingModeRawValue: String
    public var saveOriginalAudio: Bool
    public var overlayIsNonActivating: Bool
    public var overlayShowsLiveIndicator: Bool
    public var selectedModelID: String
    public var historyLimitMegabytes: Int
    public var autoDeleteOldestHistory: Bool
    public var excludesDownloadedModels: Bool
    public var openAIEnabled: Bool
    public var groqEnabled: Bool

    public init(
        launchAtLoginEnabled: Bool = false,
        recordingModeRawValue: String = RecordingMode.holdToTalk.rawValue,
        saveOriginalAudio: Bool = true,
        overlayIsNonActivating: Bool = true,
        overlayShowsLiveIndicator: Bool = true,
        selectedModelID: String = "whisper-large-v3-turbo",
        historyLimitMegabytes: Int = 2_048,
        autoDeleteOldestHistory: Bool = true,
        excludesDownloadedModels: Bool = true,
        openAIEnabled: Bool = false,
        groqEnabled: Bool = false
    ) {
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.recordingModeRawValue = recordingModeRawValue
        self.saveOriginalAudio = saveOriginalAudio
        self.overlayIsNonActivating = overlayIsNonActivating
        self.overlayShowsLiveIndicator = overlayShowsLiveIndicator
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
    var saveOriginalAudio: Bool
    var overlayIsNonActivating: Bool
    var overlayShowsLiveIndicator: Bool
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
            saveOriginalAudio: decoded.saveOriginalAudio,
            overlayIsNonActivating: decoded.overlayIsNonActivating,
            overlayShowsLiveIndicator: decoded.overlayShowsLiveIndicator,
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
            saveOriginalAudio: snapshot.saveOriginalAudio,
            overlayIsNonActivating: snapshot.overlayIsNonActivating,
            overlayShowsLiveIndicator: snapshot.overlayShowsLiveIndicator,
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
