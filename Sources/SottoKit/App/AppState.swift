import Foundation
import Observation

@Observable
public final class AppState {
    public var selectedScreen: NavigationScreen
    public var recordingState: RecordingState
    public var audioCaptureState: AudioCaptureState
    public var overlayState: OverlayState
    public var transcriptionPreferences: TranscriptionPreferences
    public var storageSettings: StorageSettings
    public var historyStore: HistoryStore
    public let modelCatalog: ModelCatalog
    public let providerCatalog: ProviderCatalog

    public init(
        selectedScreen: NavigationScreen = .overview,
        recordingState: RecordingState = RecordingState(),
        audioCaptureState: AudioCaptureState = AudioCaptureState(),
        overlayState: OverlayState = OverlayState(),
        transcriptionPreferences: TranscriptionPreferences = TranscriptionPreferences(),
        storageSettings: StorageSettings = StorageSettings(),
        historyStore: HistoryStore = HistoryStore(),
        modelCatalog: ModelCatalog = .defaultCatalog,
        providerCatalog: ProviderCatalog = .defaultCatalog
    ) {
        self.selectedScreen = selectedScreen
        self.recordingState = recordingState
        self.audioCaptureState = audioCaptureState
        self.overlayState = overlayState
        self.transcriptionPreferences = transcriptionPreferences
        self.storageSettings = storageSettings
        self.historyStore = historyStore
        self.modelCatalog = modelCatalog
        self.providerCatalog = providerCatalog
    }
}
