import Foundation
import Observation

@MainActor
@Observable
public final class AppState {
    public var selectedScreen: NavigationScreen
    public var generalSettings: GeneralSettings {
        didSet { persistPreferences() }
    }
    public var recordingState: RecordingState {
        didSet {
            persistPreferences()
            voiceInputController.replaceRecordingModeProvider { [weak self] in
                self?.recordingState.mode ?? .holdToTalk
            }
            hotkeyManager.register(recordingState.hotkey)
            hotkeyRegistrationErrorMessage = hotkeyManager.lastErrorMessage
        }
    }
    public var audioCaptureState: AudioCaptureState
    public var overlayState: OverlayState {
        didSet {
            persistPreferences()
            recordingOverlayManager.refreshPresentation()
        }
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
    public let voiceInputController: VoiceInputController
    public private(set) var hotkeyRegistrationErrorMessage: String?
    @ObservationIgnored private let hotkeyManager: GlobalHotkeyManager
    @ObservationIgnored private let recordingOverlayManager: RecordingOverlayManager
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
        let hotkeyConfiguration = HotkeyConfiguration(
            keyCode: snapshot.hotkeyKeyCode,
            carbonModifiers: snapshot.hotkeyCarbonModifiers
        )
        let hotkeyManager = GlobalHotkeyManager(configuration: hotkeyConfiguration)
        let recordingOverlayManager = RecordingOverlayManager()
        let voiceInputController = VoiceInputController(
            recorder: AudioRecorderService(),
            recordingModeProvider: { recordingMode }
        )

        self.preferencesStore = preferencesStore
        self.hotkeyManager = hotkeyManager
        self.recordingOverlayManager = recordingOverlayManager
        self.selectedScreen = selectedScreen
        self.generalSettings = GeneralSettings(
            launchAtLoginEnabled: snapshot.launchAtLoginEnabled
        )
        self.recordingState = RecordingState(
            mode: recordingMode,
            hotkey: hotkeyConfiguration,
            savesAudioLocally: snapshot.saveOriginalAudio
        )
        self.audioCaptureState = audioCaptureState
        self.overlayState = OverlayState(
            isEnabled: snapshot.overlayEnabled,
            isNonActivating: snapshot.overlayIsNonActivating,
            showsLiveAudioIndicator: snapshot.overlayShowsLiveIndicator,
            position: OverlayPosition(rawValue: snapshot.overlayPositionRawValue) ?? .topCenter
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
        self.voiceInputController = voiceInputController
        self.hotkeyRegistrationErrorMessage = nil

        voiceInputController.replaceOnRecordingFinished { [weak self] recording in
            self?.appendPendingRecording(recording)
        }
        voiceInputController.replaceRecordingModeProvider { [weak self] in
            self?.recordingState.mode ?? .holdToTalk
        }
        hotkeyManager.onPressed = { [weak voiceInputController] in
            voiceInputController?.hotkeyPressed()
        }
        hotkeyManager.onReleased = { [weak voiceInputController] in
            voiceInputController?.hotkeyReleased()
        }
        hotkeyManager.register(hotkeyConfiguration)
        self.hotkeyRegistrationErrorMessage = hotkeyManager.lastErrorMessage
        recordingOverlayManager.bind(
            voiceInputController: voiceInputController,
            overlayStateProvider: { [weak self] in
                self?.overlayState ?? OverlayState()
            }
        )
    }

    public var selectedModel: ModelDescriptor? {
        modelCatalog.allModels.first { $0.id == transcriptionPreferences.selectedModelID }
    }

    private func persistPreferences() {
        preferencesStore.save(
            AppPreferencesSnapshot(
                launchAtLoginEnabled: generalSettings.launchAtLoginEnabled,
                recordingModeRawValue: recordingState.mode.rawValue,
                hotkeyKeyCode: recordingState.hotkey.keyCode,
                hotkeyCarbonModifiers: recordingState.hotkey.carbonModifiers,
                saveOriginalAudio: recordingState.savesAudioLocally,
                overlayEnabled: overlayState.isEnabled,
                overlayIsNonActivating: overlayState.isNonActivating,
                overlayShowsLiveIndicator: overlayState.showsLiveAudioIndicator,
                overlayPositionRawValue: overlayState.position.rawValue,
                selectedModelID: transcriptionPreferences.selectedModelID,
                historyLimitMegabytes: storageSettings.capMegabytes,
                autoDeleteOldestHistory: storageSettings.autoDeleteOldestHistory,
                excludesDownloadedModels: storageSettings.excludesDownloadedModels,
                openAIEnabled: providerSettings.openAIEnabled,
                groqEnabled: providerSettings.groqEnabled
            )
        )
    }

    private func appendPendingRecording(_ recording: RecordedAudioAsset) {
        let fileName = recording.url.deletingPathExtension().lastPathComponent
        let entry = HistoryEntry(
            createdAt: recording.createdAt,
            title: "Pending Dictation",
            transcriptPreview: "Saved locally as \(fileName). Waiting for transcription.",
            transcriptText: "",
            durationSeconds: recording.durationSeconds,
            characterCount: 0,
            modelName: selectedModel?.name ?? "Selected Model",
            sourceType: .dictation,
            transcriptionStatus: .pendingTranscription,
            audioFilePath: recording.url.path,
            fileSizeBytes: recording.fileSizeBytes
        )
        historyStore.prepend(entry)
    }
}
