import AppKit
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
        didSet {
            persistPreferences()
            refreshStorageState()
        }
    }
    public var providerSettings: ProviderSettings {
        didSet { persistPreferences() }
    }
    public var historyStore: HistoryStore
    public var storageUsage = ManagedStorageUsage()
    public var storageWarningMessage: String?
    public var importFeedbackMessage: String?
    public var historyActionMessage: String?
    public let modelCatalog: ModelCatalog
    public let providerCatalog: ProviderCatalog
    public let voiceInputController: VoiceInputController
    public let audioPlaybackService: AudioPlaybackService
    public let localTranscriptionProvider: WhisperKitLocalTranscriptionProvider
    public let whisperModelManager: WhisperModelManager
    public let transcriptionQueueController: TranscriptionQueueController
    public private(set) var hotkeyRegistrationErrorMessage: String?
    @ObservationIgnored private let hotkeyManager: GlobalHotkeyManager
    @ObservationIgnored private let recordingOverlayManager: RecordingOverlayManager
    @ObservationIgnored private let preferencesStore: AppPreferencesStore
    @ObservationIgnored private let historyRepository: HistoryRepository
    @ObservationIgnored private let storageLayout: AppStorageLayout
    @ObservationIgnored private let importService: AudioImportService
    @ObservationIgnored private let storageQuotaService: StorageQuotaService
    @ObservationIgnored private let transcriptExportService: TranscriptExportService
    @ObservationIgnored private var isEnforcingStorageCap = false

    public init(
        selectedScreen: NavigationScreen = .overview,
        audioCaptureState: AudioCaptureState = AudioCaptureState(),
        historyStore: HistoryStore = HistoryStore(),
        modelCatalog: ModelCatalog = .defaultCatalog,
        providerCatalog: ProviderCatalog = .defaultCatalog,
        preferencesStore: AppPreferencesStore = .standard,
        storageLayout: AppStorageLayout = AppStorageLayout(),
        historyRepository: HistoryRepository? = nil,
        audioPlaybackService: AudioPlaybackService = AudioPlaybackService()
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
            recorder: AudioRecorderService(storage: RecordingStorage(layout: storageLayout)),
            recordingModeProvider: { recordingMode }
        )
        let resolvedHistoryRepository = historyRepository
            ?? (try? HistoryRepository(layout: storageLayout))
            ?? (try! HistoryRepository(inMemory: true))

        let localTranscriptionProvider = WhisperKitLocalTranscriptionProvider(
            catalog: modelCatalog,
            storageLayout: storageLayout
        )
        let whisperModelManager = WhisperModelManager(
            catalog: modelCatalog,
            provider: localTranscriptionProvider
        )
        let transcriptionQueueController = TranscriptionQueueController(provider: localTranscriptionProvider)

        let persistedEntries = (try? resolvedHistoryRepository.fetchAll()) ?? historyStore.entries

        self.preferencesStore = preferencesStore
        self.hotkeyManager = hotkeyManager
        self.recordingOverlayManager = recordingOverlayManager
        self.historyRepository = resolvedHistoryRepository
        self.storageLayout = storageLayout
        self.importService = AudioImportService(layout: storageLayout)
        self.storageQuotaService = StorageQuotaService(layout: storageLayout)
        self.transcriptExportService = TranscriptExportService()
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
            selectedModelID: snapshot.selectedModelID,
            autoTranscribeAfterCapture: snapshot.autoTranscribeAfterCapture,
            preferredLocalProviderID: snapshot.preferredLocalProviderID
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
        self.historyStore = HistoryStore(entries: persistedEntries)
        self.modelCatalog = modelCatalog
        self.providerCatalog = providerCatalog
        self.voiceInputController = voiceInputController
        self.audioPlaybackService = audioPlaybackService
        self.localTranscriptionProvider = localTranscriptionProvider
        self.whisperModelManager = whisperModelManager
        self.transcriptionQueueController = transcriptionQueueController
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

        transcriptionQueueController.replaceEntryLookup { [weak self] id in
            self?.historyStore.entries.first(where: { $0.id == id })
        }
        transcriptionQueueController.replacePersistEntry { [weak self] entry in
            guard let self else {
                return
            }
            try self.persistHistoryEntry(entry)
        }
        transcriptionQueueController.replaceModelLookup { [weak self] modelID in
            self?.modelCatalog.model(id: modelID)
        }

        refreshStorageState()
    }

    public var selectedModel: ModelDescriptor? {
        modelCatalog.model(id: transcriptionPreferences.selectedModelID)
    }

    public var recentImports: [RecentImportItem] {
        historyStore.entries
            .filter { $0.sourceType == .importedAudio }
            .prefix(5)
            .compactMap(RecentImportItem.init)
    }

    public func historyEntry(id: UUID) -> HistoryEntry? {
        historyStore.entries.first(where: { $0.id == id })
    }

    public func importAudio(from sourceURLs: [URL]) {
        for sourceURL in sourceURLs {
            do {
                let projectedBytes = try fileSizeForIncomingImport(sourceURL)
                try storageQuotaService.validateImportCanProceed(
                    additionalBytes: projectedBytes,
                    settings: storageSettings
                )

                let prepared = try importService.prepareImport(from: sourceURL)
                let entry = HistoryEntry(
                    sourceType: .importedAudio,
                    displayName: prepared.displayName,
                    originalFilePath: prepared.originalFileURL.path,
                    workingFilePath: prepared.workingFileURL?.path,
                    transcriptText: "",
                    transcriptPreview: importPreview(for: prepared),
                    createdAt: .now,
                    durationSeconds: prepared.durationSeconds,
                    characterCount: 0,
                    modelID: selectedModel?.id,
                    modelName: selectedModel?.name,
                    providerID: nil,
                    providerName: nil,
                    language: nil,
                    fileSizeBytes: prepared.fileSizeBytes,
                    transcriptionStatus: prepared.status,
                    errorMessage: prepared.errorMessage
                )

                try persistHistoryEntry(entry)
                importFeedbackMessage = prepared.errorMessage ?? "Imported \(prepared.displayName)."
                queueAutomaticTranscriptionIfNeeded(for: entry)
            } catch {
                importFeedbackMessage = error.localizedDescription
            }
        }
    }

    public func togglePlayback(for entry: HistoryEntry) {
        do {
            try audioPlaybackService.togglePlayback(for: entry)
            historyActionMessage = nil
        } catch {
            historyActionMessage = error.localizedDescription
        }
    }

    public func copyTranscript(for entry: HistoryEntry) {
        guard entry.canCopyTranscript else {
            historyActionMessage = TranscriptExportError.transcriptUnavailable.localizedDescription
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.transcriptText, forType: .string)
        historyActionMessage = "Transcript copied to the clipboard."
    }

    public func exportTranscript(for entry: HistoryEntry) {
        guard entry.canExportTranscript else {
            historyActionMessage = TranscriptExportError.transcriptUnavailable.localizedDescription
            return
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = entry.displayName.replacingOccurrences(of: ".", with: "-") + ".txt"
        panel.allowedContentTypes = [.plainText]

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        do {
            try transcriptExportService.export(entry: entry, to: destinationURL)
            historyActionMessage = "Transcript exported to \(destinationURL.lastPathComponent)."
        } catch {
            historyActionMessage = error.localizedDescription
        }
    }

    public func transcribe(_ entry: HistoryEntry, using requestedModelID: String? = nil) {
        guard let model = resolveRequestedModel(for: requestedModelID ?? transcriptionPreferences.selectedModelID) else {
            historyActionMessage = "Choose a supported local Whisper model before transcribing."
            return
        }

        guard localModelReadyForTranscription(model) else {
            historyActionMessage = "Download and load \(model.name) from Models before transcribing."
            return
        }

        transcriptionQueueController.enqueue(
            entryID: entry.id,
            modelID: model.id,
            modelName: model.name
        )
        historyActionMessage = "Queued \(entry.displayName) for local transcription."
    }

    public func retranscribe(_ entry: HistoryEntry, using requestedModelID: String) {
        transcribe(entry, using: requestedModelID)
    }

    public func cancelTranscription(for entry: HistoryEntry) {
        transcriptionQueueController.cancel(entryID: entry.id)
        historyActionMessage = "Cancelled transcription for \(entry.displayName)."
    }

    public func deleteHistoryEntry(_ entry: HistoryEntry) {
        transcriptionQueueController.cancel(entryID: entry.id)

        do {
            let deletedEntry = try historyRepository.delete(id: entry.id)
            removeManagedFiles(for: deletedEntry)
            reloadHistory()
            refreshStorageState()
            historyActionMessage = "Deleted \(entry.displayName)."
        } catch {
            historyActionMessage = error.localizedDescription
        }
    }

    public func deleteAllHistory() {
        for entry in historyStore.entries {
            transcriptionQueueController.cancel(entryID: entry.id)
        }

        do {
            let deletedEntries = try historyRepository.deleteAll()
            deletedEntries.forEach(removeManagedFiles(for:))
            audioPlaybackService.stop()
            reloadHistory()
            refreshStorageState()
            historyActionMessage = "Deleted all history items."
        } catch {
            historyActionMessage = error.localizedDescription
        }
    }

    public func persistHistoryEntry(_ entry: HistoryEntry) throws {
        try historyRepository.upsert(entry)
        reloadHistory()
        refreshStorageState()
    }

    public func refreshModelInventory() {
        Task { await whisperModelManager.refresh() }
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
                autoTranscribeAfterCapture: transcriptionPreferences.autoTranscribeAfterCapture,
                preferredLocalProviderID: transcriptionPreferences.preferredLocalProviderID,
                historyLimitMegabytes: storageSettings.capMegabytes,
                autoDeleteOldestHistory: storageSettings.autoDeleteOldestHistory,
                excludesDownloadedModels: storageSettings.excludesDownloadedModels,
                openAIEnabled: providerSettings.openAIEnabled,
                groqEnabled: providerSettings.groqEnabled
            )
        )
    }

    private func appendPendingRecording(_ recording: RecordedAudioAsset) {
        let entry = HistoryEntry.pendingRecording(
            recording: recording,
            modelID: selectedModel?.id,
            modelName: selectedModel?.name
        )

        do {
            try persistHistoryEntry(entry)
            queueAutomaticTranscriptionIfNeeded(for: entry)
        } catch {
            historyActionMessage = error.localizedDescription
        }
    }

    private func reloadHistory() {
        let persistedEntries = (try? historyRepository.fetchAll()) ?? []
        historyStore.replace(with: persistedEntries)
    }

    private func refreshStorageState() {
        storageUsage = (try? storageQuotaService.currentUsage()) ?? ManagedStorageUsage()

        guard !isEnforcingStorageCap else {
            return
        }

        do {
            let enforcement = try storageQuotaService.pruneEntriesIfNeeded(
                entries: historyStore.entries,
                settings: storageSettings
            )

            if enforcement.prunedEntryIDs.isEmpty {
                storageWarningMessage = enforcement.warningMessage
                storageUsage = enforcement.usage
                return
            }

            isEnforcingStorageCap = true
            for prunedID in enforcement.prunedEntryIDs {
                if let prunedEntry = historyStore.entries.first(where: { $0.id == prunedID }) {
                    transcriptionQueueController.cancel(entryID: prunedID)
                    _ = try? historyRepository.delete(id: prunedID)
                    removeManagedFiles(for: prunedEntry)
                }
            }
            isEnforcingStorageCap = false

            reloadHistory()
            storageUsage = (try? storageQuotaService.currentUsage()) ?? ManagedStorageUsage()
            storageWarningMessage = "Sotto removed \(enforcement.prunedEntryIDs.count) oldest history item(s) to stay within the storage cap."
        } catch {
            storageWarningMessage = error.localizedDescription
        }
    }

    private func removeManagedFiles(for entry: HistoryEntry?) {
        guard let entry else {
            return
        }

        let paths = Set([entry.originalFilePath, entry.workingFilePath].compactMap { $0 })
        for path in paths {
            _ = storageLayout.removeManagedFileIfPresent(atPath: path)
        }
    }

    private func importPreview(for prepared: ImportedAudioPreparationResult) -> String {
        switch prepared.status {
        case .pending:
            "Imported audio is stored locally and waiting for transcription."
        case .failed:
            prepared.errorMessage ?? "Import failed."
        case .transcribing:
            "Imported audio is currently transcribing."
        case .completed:
            "Imported audio is ready."
        }
    }

    private func fileSizeForIncomingImport(_ sourceURL: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func queueAutomaticTranscriptionIfNeeded(for entry: HistoryEntry) {
        guard transcriptionPreferences.autoTranscribeAfterCapture else {
            return
        }

        guard entry.transcriptionStatus == .pending else {
            return
        }

        transcribe(entry, using: transcriptionPreferences.selectedModelID)
    }

    private func resolveRequestedModel(for modelID: String) -> ModelDescriptor? {
        guard let model = modelCatalog.model(id: modelID), model.isWhisperKitLocalModel else {
            return nil
        }

        return model
    }

    private func localModelReadyForTranscription(_ model: ModelDescriptor) -> Bool {
        guard let item = whisperModelManager.item(for: model.id) else {
            return false
        }

        return switch item.state {
        case .downloaded, .loaded:
            true
        default:
            false
        }
    }
}
