import Foundation
import Observation

@Observable
public final class AppState {
    public var selectedScreen: NavigationScreen
    public var generalSettings: GeneralSettings {
        didSet { persistPreferences() }
    }
    public var recordingState: RecordingState {
        didSet { persistPreferences() }
    }
    public var audioCaptureState: AudioCaptureState
    public var overlayState: OverlayState {
        didSet { persistPreferences() }
    }
    public var transcriptionPreferences: TranscriptionPreferences {
        didSet { persistPreferences() }
    }
    public var storageSettings: StorageSettings {
        didSet { persistPreferences() }
    }
    public var providerSettings: ProviderSettings {
        didSet { persistPreferences() }
    }
    public var historyStore: HistoryStore
    public let modelCatalog: ModelCatalog
    public let providerCatalog: ProviderCatalog
    @ObservationIgnored private let preferencesStore: AppPreferencesStore

    public init(
        selectedScreen: NavigationScreen = .overview,
        audioCaptureState: AudioCaptureState = AudioCaptureState(),
        historyStore: HistoryStore = .mock,
        modelCatalog: ModelCatalog = .defaultCatalog,
        providerCatalog: ProviderCatalog = .defaultCatalog,
        preferencesStore: AppPreferencesStore = .standard
    ) {
        let snapshot = preferencesStore.load()
        let recordingMode = RecordingMode(rawValue: snapshot.recordingModeRawValue) ?? .holdToTalk

        self.preferencesStore = preferencesStore
        self.selectedScreen = selectedScreen
        self.generalSettings = GeneralSettings(
            launchAtLoginEnabled: snapshot.launchAtLoginEnabled
        )
        self.recordingState = RecordingState(
            mode: recordingMode,
            hotkey: HotkeyConfiguration(),
            savesAudioLocally: snapshot.saveOriginalAudio
        )
        self.audioCaptureState = audioCaptureState
        self.overlayState = OverlayState(
            isNonActivating: snapshot.overlayIsNonActivating,
            showsLiveAudioIndicator: snapshot.overlayShowsLiveIndicator
        )
        self.transcriptionPreferences = TranscriptionPreferences(
            selectedModelID: snapshot.selectedModelID
        )
        self.storageSettings = StorageSettings(
            capMegabytes: snapshot.historyLimitMegabytes,
            autoDeleteOldestHistory: snapshot.autoDeleteOldestHistory,
            excludesDownloadedModels: snapshot.excludesDownloadedModels
        )
        self.providerSettings = ProviderSettings(
            openAIEnabled: snapshot.openAIEnabled,
            groqEnabled: snapshot.groqEnabled
        )
        self.historyStore = historyStore
        self.modelCatalog = modelCatalog
        self.providerCatalog = providerCatalog
    }

    public var selectedModel: ModelDescriptor? {
        modelCatalog.allModels.first { $0.id == transcriptionPreferences.selectedModelID }
    }

    private func persistPreferences() {
        preferencesStore.save(
            AppPreferencesSnapshot(
                launchAtLoginEnabled: generalSettings.launchAtLoginEnabled,
                recordingModeRawValue: recordingState.mode.rawValue,
                saveOriginalAudio: recordingState.savesAudioLocally,
                overlayIsNonActivating: overlayState.isNonActivating,
                overlayShowsLiveIndicator: overlayState.showsLiveAudioIndicator,
                selectedModelID: transcriptionPreferences.selectedModelID,
                historyLimitMegabytes: storageSettings.capMegabytes,
                autoDeleteOldestHistory: storageSettings.autoDeleteOldestHistory,
                excludesDownloadedModels: storageSettings.excludesDownloadedModels,
                openAIEnabled: providerSettings.openAIEnabled,
                groqEnabled: providerSettings.groqEnabled
            )
        )
    }
}
