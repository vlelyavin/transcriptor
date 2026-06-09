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
    public let openAITranscriptionProvider: OpenAICompatibleCloudTranscriptionProvider
    public let groqTranscriptionProvider: OpenAICompatibleCloudTranscriptionProvider
    public let whisperModelManager: WhisperModelManager
    public let transcriptionQueueController: TranscriptionQueueController
    public let transcriptionTargetResolver: TranscriptionTargetResolver
    public private(set) var storedAPIKeyProviderIDs: Set<String>
    public private(set) var providerCredentialValidationStates: [String: ProviderCredentialValidationState]
    public private(set) var hotkeyRegistrationErrorMessage: String?
    @ObservationIgnored private let hotkeyManager: GlobalHotkeyManager
    @ObservationIgnored private let recordingOverlayManager: RecordingOverlayManager
    @ObservationIgnored private let preferencesStore: AppPreferencesStore
    @ObservationIgnored private let historyRepository: HistoryRepository
    @ObservationIgnored private let storageLayout: AppStorageLayout
    @ObservationIgnored private let importService: AudioImportService
    @ObservationIgnored private let storageQuotaService: StorageQuotaService
    @ObservationIgnored private let transcriptExportService: TranscriptExportService
    @ObservationIgnored private let secretStore: any SecretStore
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
        audioPlaybackService: AudioPlaybackService = AudioPlaybackService(),
        secretStore: any SecretStore = KeychainSecretStore()
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
        let openAIProvider = OpenAICompatibleCloudTranscriptionProvider(
            descriptor: providerCatalog.provider(id: "openai")!,
            secretStore: secretStore
        )
        let groqProvider = OpenAICompatibleCloudTranscriptionProvider(
            descriptor: providerCatalog.provider(id: "groq")!,
            secretStore: secretStore
        )
        let whisperModelManager = WhisperModelManager(
            catalog: modelCatalog,
            provider: localTranscriptionProvider
        )
        let transcriptionQueueController = TranscriptionQueueController(
            providers: [localTranscriptionProvider, openAIProvider, groqProvider]
        )
        let transcriptionTargetResolver = TranscriptionTargetResolver(
            modelCatalog: modelCatalog,
            providerCatalog: providerCatalog
        )
        let storedAPIKeyProviderIDs = Set(
            providerCatalog.providers.compactMap { provider in
                ((try? secretStore.containsSecret(for: provider.keychainAccount)) == true) ? provider.id : nil
            }
        )
        let providerCredentialValidationStates = Dictionary(
            uniqueKeysWithValues: providerCatalog.providers.map { ($0.id, ProviderCredentialValidationState.idle) }
        )

        let persistedEntries = (try? resolvedHistoryRepository.fetchAll()) ?? historyStore.entries

        self.preferencesStore = preferencesStore
        self.hotkeyManager = hotkeyManager
        self.recordingOverlayManager = recordingOverlayManager
        self.historyRepository = resolvedHistoryRepository
        self.storageLayout = storageLayout
        self.importService = AudioImportService(layout: storageLayout)
        self.storageQuotaService = StorageQuotaService(layout: storageLayout)
        self.transcriptExportService = TranscriptExportService()
        self.secretStore = secretStore
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
            preferredLocalProviderID: snapshot.preferredLocalProviderID,
            preferredProviderID: snapshot.preferredProviderID
        )
        self.storageSettings = StorageSettings(
            capMegabytes: snapshot.historyLimitMegabytes,
            autoDeleteOldestHistory: snapshot.autoDeleteOldestHistory,
            excludesDownloadedModels: snapshot.excludesDownloadedModels
        )
        self.providerSettings = ProviderSettings(
            openAIEnabled: snapshot.openAIEnabled,
            groqEnabled: snapshot.groqEnabled,
            openAIModelID: snapshot.openAIModelID,
            groqModelID: snapshot.groqModelID,
            openAIPrivacyAcknowledged: snapshot.openAIPrivacyAcknowledged,
            groqPrivacyAcknowledged: snapshot.groqPrivacyAcknowledged
        )
        self.historyStore = HistoryStore(entries: persistedEntries)
        self.modelCatalog = modelCatalog
        self.providerCatalog = providerCatalog
        self.voiceInputController = voiceInputController
        self.audioPlaybackService = audioPlaybackService
        self.localTranscriptionProvider = localTranscriptionProvider
        self.openAITranscriptionProvider = openAIProvider
        self.groqTranscriptionProvider = groqProvider
        self.whisperModelManager = whisperModelManager
        self.transcriptionQueueController = transcriptionQueueController
        self.transcriptionTargetResolver = transcriptionTargetResolver
        self.storedAPIKeyProviderIDs = storedAPIKeyProviderIDs
        self.providerCredentialValidationStates = providerCredentialValidationStates
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

    public var readyLocalModelIDs: Set<String> {
        Set(whisperModelManager.downloadedWhisperModels().map(\.id))
    }

    public var preferredCloudProvider: ProviderDescriptor? {
        guard transcriptionPreferences.preferredProviderID != "whisperkit-local" else {
            return nil
        }

        return providerCatalog.provider(id: transcriptionPreferences.preferredProviderID)
    }

    public var providerRuntimeStates: [String: ProviderRuntimeState] {
        Dictionary(
            uniqueKeysWithValues: providerCatalog.providers.map { provider in
                (provider.id, providerRuntimeState(for: provider))
            }
        )
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
        panel.nameFieldStringValue = transcriptExportService.suggestedFilename(for: entry)
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

    public func transcribe(_ entry: HistoryEntry, using selection: TranscriptionTargetSelection = .preferred) {
        do {
            let plan = try transcriptionTargetResolver.resolve(
                selection: selection,
                preferences: transcriptionPreferences,
                providerSettings: providerSettings,
                readyLocalModelIDs: readyLocalModelIDs,
                providerStatesByID: providerRuntimeStates
            )

            transcriptionQueueController.enqueue(
                entryID: entry.id,
                providerID: plan.providerID,
                providerName: plan.providerName,
                modelID: plan.modelID,
                modelName: plan.modelName
            )
            historyActionMessage = "Queued \(entry.displayName) for \(plan.providerName) transcription."
        } catch {
            historyActionMessage = error.localizedDescription
        }
    }

    public func transcribe(_ entry: HistoryEntry, using requestedModelID: String) {
        transcribe(entry, using: .localModel(requestedModelID))
    }

    public func retranscribe(_ entry: HistoryEntry, using requestedModelID: String) {
        transcribe(entry, using: .localModel(requestedModelID))
    }

    public func retranscribe(_ entry: HistoryEntry, usingProvider providerID: String) {
        transcribe(entry, using: .provider(providerID))
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

    public func hasStoredAPIKey(for providerID: String) -> Bool {
        storedAPIKeyProviderIDs.contains(providerID)
    }

    public func providerRuntimeState(for provider: ProviderDescriptor) -> ProviderRuntimeState {
        switch provider.availability {
        case let .unavailable(blocker), let .planned(blocker):
            return .unavailable(message: blocker)
        case .available, .downloaded:
            break
        }

        guard providerSettings.isEnabled(providerID: provider.id) else {
            return .disabled(message: "Enable \(provider.name) in Settings before using this provider.")
        }

        guard hasStoredAPIKey(for: provider.id) else {
            return .missingAPIKey(message: "Add a \(provider.name) API key in Settings. Audio will stay on this Mac until you do.")
        }

        guard providerSettings.hasPrivacyConsent(for: provider.id) else {
            return .privacyConsentRequired(message: "Confirm the cloud privacy warning in Settings before sending audio to \(provider.name).")
        }

        let configuredModelID = providerSettings.modelID(for: provider.id, fallback: provider.modelLabel)
        return .ready(message: "\(provider.privacySummary) Current model: \(configuredModelID).")
    }

    public func availableRetranscriptionPlans() -> [TranscriptionExecutionPlan] {
        transcriptionTargetResolver.availableRetranscriptionPlans(
            providerSettings: providerSettings,
            readyLocalModelIDs: readyLocalModelIDs,
            providerStatesByID: providerRuntimeStates
        )
    }

    public func saveAPIKey(_ apiKey: String, for providerID: String) {
        guard let provider = providerCatalog.provider(id: providerID) else {
            return
        }

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            providerCredentialValidationStates[providerID] = .failed("Enter a non-empty API key before saving.")
            return
        }

        do {
            try secretStore.saveSecret(trimmedKey, for: provider.keychainAccount)
            storedAPIKeyProviderIDs.insert(providerID)
            providerCredentialValidationStates[providerID] = .succeeded("\(provider.name) API key saved to Keychain.")
        } catch {
            providerCredentialValidationStates[providerID] = .failed(error.localizedDescription)
        }
    }

    public func removeAPIKey(for providerID: String) {
        guard let provider = providerCatalog.provider(id: providerID) else {
            return
        }

        do {
            try secretStore.deleteSecret(for: provider.keychainAccount)
            storedAPIKeyProviderIDs.remove(providerID)
            providerCredentialValidationStates[providerID] = .succeeded("\(provider.name) API key removed from Keychain.")
        } catch {
            providerCredentialValidationStates[providerID] = .failed(error.localizedDescription)
        }
    }

    public func testAPIKey(for providerID: String) {
        guard let provider = providerCatalog.provider(id: providerID) else {
            return
        }

        providerCredentialValidationStates[providerID] = .testing
        let modelID = providerSettings.modelID(for: providerID, fallback: provider.modelLabel)

        Task {
            do {
                try await cloudProvider(for: providerID)?.validateCredentials(modelID: modelID)
                await MainActor.run {
                    self.providerCredentialValidationStates[providerID] = .succeeded("\(provider.name) accepted the stored key for model '\(modelID)'.")
                }
            } catch {
                await MainActor.run {
                    self.providerCredentialValidationStates[providerID] = .failed(error.localizedDescription)
                }
            }
        }
    }

    public func openMicrophonePrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    public func resetHotkeyToRecommendedDefault() {
        recordingState.hotkey = HotkeyConfiguration()
    }

    public func resetOverlayDefaults() {
        overlayState = OverlayState()
    }

    public func resetStorageDefaults() {
        storageSettings = StorageSettings()
    }

    public func resetCloudProviderDefaults() {
        providerSettings.openAIModelID = "gpt-4o-mini-transcribe"
        providerSettings.groqModelID = "whisper-large-v3-turbo"
        providerSettings.openAIPrivacyAcknowledged = false
        providerSettings.groqPrivacyAcknowledged = false
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
                preferredProviderID: transcriptionPreferences.preferredProviderID,
                historyLimitMegabytes: storageSettings.capMegabytes,
                autoDeleteOldestHistory: storageSettings.autoDeleteOldestHistory,
                excludesDownloadedModels: storageSettings.excludesDownloadedModels,
                openAIEnabled: providerSettings.openAIEnabled,
                groqEnabled: providerSettings.groqEnabled,
                openAIModelID: providerSettings.openAIModelID,
                groqModelID: providerSettings.groqModelID,
                openAIPrivacyAcknowledged: providerSettings.openAIPrivacyAcknowledged,
                groqPrivacyAcknowledged: providerSettings.groqPrivacyAcknowledged
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
            storageWarningMessage = "Transcriptor removed \(enforcement.prunedEntryIDs.count) oldest history item(s) to stay within the storage cap."
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

        transcribe(entry)
    }

    private func cloudProvider(for providerID: String) -> (any CloudTranscriptionProvider)? {
        switch providerID {
        case "openai":
            openAITranscriptionProvider
        case "groq":
            groqTranscriptionProvider
        default:
            nil
        }
    }
}
