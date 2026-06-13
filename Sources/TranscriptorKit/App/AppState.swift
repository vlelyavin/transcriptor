import AppKit
import Foundation
import Observation

@MainActor
@Observable
public final class AppState {
    public var sidebarSelection: SidebarItem {
        didSet {
            guard !isPerformingHistoryNavigation, oldValue != sidebarSelection else {
                return
            }
            navigationBackStack.append(oldValue)
            navigationForwardStack.removeAll()
        }
    }
    public private(set) var navigationBackStack: [SidebarItem] = []
    public private(set) var navigationForwardStack: [SidebarItem] = []
    private var isPerformingHistoryNavigation = false

    /// When set, the History screen selects this entry on appearance. Used to
    /// open a specific item's detail (e.g. tapping a Recent Import).
    public var pendingHistoryEntryID: UUID?

    /// Navigates to the History screen and requests that `entryID` be selected.
    public func openHistoryEntry(_ entryID: UUID) {
        pendingHistoryEntryID = entryID
        sidebarSelection = .screen(.history)
    }

    // MARK: - Onboarding

    private static let welcomeGuideDefaultsKey = "com.transcriptor.hasSeenWelcomeGuide"

    /// Persisted flag: whether the first-launch welcome guide has been shown.
    public var hasSeenWelcomeGuide: Bool = UserDefaults.standard.bool(forKey: AppState.welcomeGuideDefaultsKey) {
        didSet { UserDefaults.standard.set(hasSeenWelcomeGuide, forKey: AppState.welcomeGuideDefaultsKey) }
    }

    /// Drives the welcome/setup guide sheet.
    public var isPresentingWelcomeGuide = false

    /// Setup is mandatory: the app requires at least one usable transcription
    /// path (a downloaded local model or a ready cloud provider) before it can
    /// be used. When this is true the setup gate must be shown and cannot be
    /// dismissed.
    public var requiresModelSetup: Bool { !isTranscriptionConfigured }

    /// Inserting dictated text into other apps — the app's core value — needs
    /// macOS Accessibility access, so it is a required part of initial setup.
    public var isAccessibilityGranted: Bool { accessibilityPermissionStatus == .granted }

    public var requiresAccessibilitySetup: Bool { !isAccessibilityGranted }

    /// Initial setup is mandatory and complete only when BOTH a transcription
    /// model is configured AND Accessibility access is granted.
    public var requiresSetup: Bool { requiresModelSetup || requiresAccessibilitySetup }

    /// QA/screenshot hook: when true, the mandatory setup gate is not
    /// auto-presented, so automated captures of other screens aren't blocked.
    /// Never set during a normal launch.
    public var suppressSetupGate = false

    /// The setup gate auto-presents on launch whenever setup is still required.
    public var shouldAutoPresentWelcomeGuide: Bool { requiresSetup && !suppressSetupGate }

    /// The model offered first in the mandatory setup flow — the catalog's
    /// flagged recommendation, falling back to the first downloadable WhisperKit
    /// model so there is always a one-click path to a working model.
    public var recommendedSetupModel: ModelDescriptor? {
        let whisper = modelCatalog.whisperModels
        return whisper.first(where: { $0.accentBadgeLabel == "Recommended" }) ?? whisper.first
    }

    /// Presents the setup guide (used by the first-launch auto-present and the
    /// Overview "set up transcription" row button).
    public func presentWelcomeGuide() {
        isPresentingWelcomeGuide = true
    }

    /// Dismisses the setup gate. Because setup is mandatory, this only succeeds
    /// once a transcription path has actually been configured.
    public func dismissWelcomeGuide() {
        guard !requiresSetup else { return }
        hasSeenWelcomeGuide = true
        isPresentingWelcomeGuide = false
    }

    /// Starts downloading the recommended model directly from the setup gate, so
    /// the user never has to leave the flow to get a working model.
    public func beginModelSetup() {
        guard let model = recommendedSetupModel else { return }
        whisperModelManager.download(model)
    }

    /// Selects a freshly downloaded model as the active one. Called by the setup
    /// gate once the recommended model finishes downloading so the user lands in
    /// a ready-to-use state automatically.
    public func finishModelSetupIfReady() {
        guard let model = recommendedSetupModel,
              readyLocalModelIDs.contains(model.id),
              transcriptionPreferences.selectedModelID != model.id
        else { return }
        selectLocalModel(model.id)
    }

    public var selectedScreen: NavigationScreen {
        get {
            if case let .screen(screen) = sidebarSelection {
                return screen
            }
            return .overview
        }
        set { sidebarSelection = .screen(newValue) }
    }

    public var selectedSettingsPane: SettingsPane? {
        get {
            if case let .settings(pane) = sidebarSelection {
                return pane
            }
            return nil
        }
        set {
            if let newValue {
                sidebarSelection = .settings(newValue)
            }
        }
    }
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
    public var overlaySupplementalPhase: OverlaySupplementalPhase?
    public let modelCatalog: ModelCatalog
    public let providerCatalog: ProviderCatalog
    public let voiceInputController: VoiceInputController
    public let audioPlaybackService: AudioPlaybackService
    public let localTranscriptionProvider: WhisperKitLocalTranscriptionProvider
    public let parakeetTranscriptionProvider: ParakeetLocalTranscriptionProvider
    public let openAITranscriptionProvider: OpenAICompatibleCloudTranscriptionProvider
    public let groqTranscriptionProvider: OpenAICompatibleCloudTranscriptionProvider
    public let whisperModelManager: WhisperModelManager
    public let parakeetModelManager: ParakeetModelManager
    public let transcriptionQueueController: TranscriptionQueueController
    public let transcriptionTargetResolver: TranscriptionTargetResolver
    public private(set) var storedAPIKeyProviderIDs: Set<String>
    public private(set) var providerCredentialValidationStates: [String: ProviderCredentialValidationState]
    public private(set) var hotkeyRegistrationErrorMessage: String?
    public private(set) var accessibilityPermissionStatus: AccessibilityPermissionStatus
    public private(set) var transcriptInsertionDebugSnapshot: TranscriptInsertionDebugSnapshot
    public private(set) var launchAtLoginStatus: LaunchAtLoginStatus
    @ObservationIgnored private let hotkeyManager: GlobalHotkeyManager
    @ObservationIgnored private let recordingOverlayManager: RecordingOverlayManager
    @ObservationIgnored private let preferencesStore: AppPreferencesStore
    @ObservationIgnored private let historyRepository: HistoryRepository
    @ObservationIgnored private let storageLayout: AppStorageLayout
    @ObservationIgnored private let importService: AudioImportService
    @ObservationIgnored private let storageQuotaService: StorageQuotaService
    @ObservationIgnored private let transcriptExportService: TranscriptExportService
    @ObservationIgnored private let transcriptInsertionService: any TranscriptInsertionServing
    @ObservationIgnored private let launchAtLoginService: any LaunchAtLoginServing
    @ObservationIgnored private let secretStore: any SecretStore
    @ObservationIgnored private var isEnforcingStorageCap = false
    @ObservationIgnored private var overlaySupplementalClearTask: Task<Void, Never>?
    @ObservationIgnored private var pendingInsertionEntryID: UUID?

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
        transcriptInsertionService: any TranscriptInsertionServing = TranscriptInsertionService(),
        launchAtLoginService: any LaunchAtLoginServing = LaunchAtLoginService(),
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
        let parakeetTranscriptionProvider = ParakeetLocalTranscriptionProvider(
            catalog: modelCatalog
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
        let parakeetModelManager = ParakeetModelManager(
            catalog: modelCatalog,
            provider: parakeetTranscriptionProvider
        )
        let transcriptionQueueController = TranscriptionQueueController(
            providers: [localTranscriptionProvider, parakeetTranscriptionProvider, openAIProvider, groqProvider]
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
        let launchAtLoginStatus = launchAtLoginService.refreshStatus()

        let persistedEntries = (try? resolvedHistoryRepository.fetchAll()) ?? historyStore.entries

        self.preferencesStore = preferencesStore
        self.hotkeyManager = hotkeyManager
        self.recordingOverlayManager = recordingOverlayManager
        self.historyRepository = resolvedHistoryRepository
        self.storageLayout = storageLayout
        self.importService = AudioImportService(layout: storageLayout)
        self.storageQuotaService = StorageQuotaService(layout: storageLayout)
        self.transcriptExportService = TranscriptExportService()
        self.transcriptInsertionService = transcriptInsertionService
        self.launchAtLoginService = launchAtLoginService
        self.secretStore = secretStore
        self.sidebarSelection = .screen(selectedScreen)
        self.generalSettings = GeneralSettings(
            launchAtLoginEnabled: launchAtLoginStatus.toggleValue,
            showMenuBarIcon: snapshot.showMenuBarIcon,
            insertTranscriptIntoActiveApp: snapshot.insertTranscriptIntoActiveApp,
            alsoCopyTranscriptToClipboard: snapshot.alsoCopyTranscriptToClipboard,
            restoreClipboardAfterInsertion: snapshot.restoreClipboardAfterInsertion
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
            groqPrivacyAcknowledged: snapshot.groqPrivacyAcknowledged,
            openAICredentialValidated: snapshot.openAICredentialValidated,
            groqCredentialValidated: snapshot.groqCredentialValidated
        )
        self.historyStore = HistoryStore(entries: persistedEntries)
        self.modelCatalog = modelCatalog
        self.providerCatalog = providerCatalog
        self.voiceInputController = voiceInputController
        self.audioPlaybackService = audioPlaybackService
        self.localTranscriptionProvider = localTranscriptionProvider
        self.parakeetTranscriptionProvider = parakeetTranscriptionProvider
        self.openAITranscriptionProvider = openAIProvider
        self.groqTranscriptionProvider = groqProvider
        self.whisperModelManager = whisperModelManager
        self.parakeetModelManager = parakeetModelManager
        self.transcriptionQueueController = transcriptionQueueController
        self.transcriptionTargetResolver = transcriptionTargetResolver
        self.storedAPIKeyProviderIDs = storedAPIKeyProviderIDs
        self.providerCredentialValidationStates = providerCredentialValidationStates
        self.hotkeyRegistrationErrorMessage = nil
        self.accessibilityPermissionStatus = transcriptInsertionService.accessibilityPermissionStatus
        self.transcriptInsertionDebugSnapshot = transcriptInsertionService.debugSnapshot
        self.launchAtLoginStatus = launchAtLoginStatus

        voiceInputController.replaceOnRecordingStarted { [weak self] in
            self?.beginVoiceInputCapture()
        }
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
            },
            recordingModeProvider: { [weak self] in
                self?.recordingState.mode ?? .holdToTalk
            },
            supplementalPhaseProvider: { [weak self] in
                self?.overlaySupplementalPhase
            },
            actionsProvider: { [weak self] in
                self?.makeOverlayActions() ?? RecordingOverlayActions()
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
        transcriptionQueueController.replaceOnCompletion { [weak self] entry in
            self?.handleCompletedTranscription(for: entry)
        }
        transcriptionQueueController.replaceOnFailure { [weak self] entryID, message in
            self?.handleFailedTranscription(for: entryID, message: message)
        }

        refreshStorageState()

        Task { [weak self] in
            await self?.autoLoadSelectedModelOnLaunch()
        }
    }

    /// Loads the active local model automatically so transcription is ready
    /// without a manual "Load" step.
    public func autoLoadSelectedModelOnLaunch() async {
        await whisperModelManager.refresh()
        await parakeetModelManager.refresh()
        loadSelectedModelIfDownloaded()
    }

    public func loadSelectedModelIfDownloaded() {
        guard let model = selectedModel else {
            return
        }

        if model.isParakeetLocalModel {
            if parakeetModelManager.item(for: model.id)?.state == .downloaded {
                parakeetModelManager.load(model)
            }
        } else if whisperModelManager.item(for: model.id)?.state == .downloaded {
            whisperModelManager.load(model)
        }
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
            .union(parakeetModelManager.downloadedParakeetModels().map(\.id))
    }

    /// True when there is at least one usable transcription path: a downloaded
    /// local model, or a cloud provider that is fully set up. The app must never
    /// imply transcription is available when this is false.
    public var isTranscriptionConfigured: Bool {
        !readyLocalModelIDs.isEmpty
            || providerRuntimeStates.values.contains { $0.isSelectable }
    }

    /// Auto-transcribe can only be enabled when transcription is actually
    /// configured — otherwise it would silently fail after every capture.
    public var canEnableAutoTranscribe: Bool {
        isTranscriptionConfigured
    }

    public var preferredCloudProvider: ProviderDescriptor? {
        guard !isLocalProviderID(transcriptionPreferences.preferredProviderID) else {
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

    public var canNavigateBack: Bool { !navigationBackStack.isEmpty }
    public var canNavigateForward: Bool { !navigationForwardStack.isEmpty }

    public func navigateBack() {
        guard let target = navigationBackStack.popLast() else {
            return
        }
        navigationForwardStack.append(sidebarSelection)
        isPerformingHistoryNavigation = true
        sidebarSelection = target
        isPerformingHistoryNavigation = false
    }

    public func navigateForward() {
        guard let target = navigationForwardStack.popLast() else {
            return
        }
        navigationBackStack.append(sidebarSelection)
        isPerformingHistoryNavigation = true
        sidebarSelection = target
        isPerformingHistoryNavigation = false
    }

    /// Selects a settings pane in the main window sidebar. Settings are part
    /// of the main window, so this never opens a second window.
    public func openSettings(pane: SettingsPane? = .general) {
        if let pane {
            sidebarSelection = .settings(pane)
        } else if selectedSettingsPane == nil {
            sidebarSelection = .settings(.general)
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    public func selectLocalModel(_ modelID: String) {
        guard let model = modelCatalog.model(id: modelID), let localProviderID = model.localProviderID else {
            transcriptionPreferences.selectedModelID = modelID
            return
        }

        // A local model can only be selected once its files are downloaded or
        // loaded — selecting an undownloaded model would only fail at transcribe
        // time and falsely imply transcription is ready.
        guard readyLocalModelIDs.contains(modelID) else {
            historyActionMessage = "Download \(model.name) before selecting it."
            return
        }

        transcriptionPreferences.selectedModelID = modelID
        transcriptionPreferences.preferredLocalProviderID = localProviderID
        transcriptionPreferences.preferredProviderID = localProviderID
        loadSelectedModelIfDownloaded()
    }

    public func selectPreferredLocalProvider(_ providerID: String) {
        transcriptionPreferences.preferredLocalProviderID = providerID
        transcriptionPreferences.preferredProviderID = providerID

        if let selectedModel, selectedModel.localProviderID == providerID {
            return
        }

        if let firstModel = modelCatalog.localModels.first(where: { $0.localProviderID == providerID }) {
            transcriptionPreferences.selectedModelID = firstModel.id
        }
    }

    // MARK: - Active transcription target

    /// The single, unified transcription target the user has chosen — either a
    /// downloaded local model or a ready cloud provider. This replaces the old
    /// two-knob "preferred provider + selected model" model in the UI.
    public enum ActiveTarget: Hashable, Sendable {
        case local(String)
        case cloud(String)
    }

    /// Every target the user can pick right now: downloaded local models first,
    /// then fully set-up cloud providers.
    public var availableTargets: [ActiveTarget] {
        var targets: [ActiveTarget] = []
        for model in modelCatalog.localModels where readyLocalModelIDs.contains(model.id) {
            targets.append(.local(model.id))
        }
        for provider in providerCatalog.providers where providerRuntimeState(for: provider).isReady {
            targets.append(.cloud(provider.id))
        }
        return targets
    }

    /// The currently active target, if it is still valid (downloaded / ready).
    public var activeTarget: ActiveTarget? {
        if isLocalProviderID(transcriptionPreferences.preferredProviderID) {
            let modelID = transcriptionPreferences.selectedModelID
            return readyLocalModelIDs.contains(modelID) ? .local(modelID) : nil
        }

        let providerID = transcriptionPreferences.preferredProviderID
        guard let provider = providerCatalog.provider(id: providerID),
              providerRuntimeState(for: provider).isReady else {
            return nil
        }
        return .cloud(providerID)
    }

    public func selectTarget(_ target: ActiveTarget) {
        switch target {
        case let .local(modelID):
            selectLocalModel(modelID)
        case let .cloud(providerID):
            transcriptionPreferences.preferredProviderID = providerID
        }
    }

    /// Commits the first available target when the stored selection no longer
    /// resolves to a ready model/provider (e.g. its files were never downloaded
    /// or were deleted), so the displayed selection always matches what would
    /// actually run. A no-op when the current selection is already valid or when
    /// nothing is ready.
    public func ensureActiveTargetValid() {
        if activeTarget == nil, let first = availableTargets.first {
            selectTarget(first)
        }
    }

    public func targetDisplayName(_ target: ActiveTarget) -> String {
        switch target {
        case let .local(modelID):
            return modelCatalog.model(id: modelID)?.name ?? modelID
        case let .cloud(providerID):
            return providerCatalog.provider(id: providerID)?.name ?? providerID
        }
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
            if entry.id == pendingInsertionEntryID {
                markPendingInsertionFailure(entryID: entry.id, message: error.localizedDescription)
                pendingInsertionEntryID = nil
                transcriptInsertionService.clearCapturedTarget()
                refreshTranscriptInsertionDebugSnapshot()
                setOverlaySupplementalPhase(.setupRequired(error.localizedDescription))
                scheduleOverlaySupplementalClear(after: .seconds(3.5))
            }
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
        Task {
            await whisperModelManager.refresh()
            await parakeetModelManager.refresh()
        }
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

        // A cloud provider is only "ready" once every requirement passes, in the
        // order the user fills them in:
        //   1. consent to send audio to the provider,
        //   2. an API key stored in Keychain,
        //   3. that key has passed a live validation (Test) against the provider.
        // It never reports Ready before validation has succeeded.
        guard providerSettings.hasPrivacyConsent(for: provider.id) else {
            return .privacyConsentRequired(message: "Turn on “Send audio to \(provider.name)” to set it up. Audio stays on this Mac until you do.")
        }

        guard hasStoredAPIKey(for: provider.id) else {
            return .missingAPIKey(message: "Add your \(provider.name) API key to continue.")
        }

        guard providerSettings.hasValidatedCredential(for: provider.id) else {
            return .needsValidation(message: "Test your \(provider.name) API key to finish setup.")
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

    public func isLocalProviderID(_ providerID: String) -> Bool {
        providerID == "whisperkit-local" || providerID == "parakeet-local"
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
            // A newly stored key has not been validated yet — readiness must wait
            // until the user tests this exact key successfully.
            providerSettings.setCredentialValidated(false, for: providerID)
            providerCredentialValidationStates[providerID] = .succeeded("\(provider.name) API key saved. Test it to finish setup.")
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
            providerSettings.setCredentialValidated(false, for: providerID)
            providerCredentialValidationStates[providerID] = .succeeded("\(provider.name) API key removed from Keychain.")
        } catch {
            providerCredentialValidationStates[providerID] = .failed(error.localizedDescription)
        }
    }

    /// Validates a provider's API key. If the user has typed a new key into the
    /// field (`enteredKey`), that exact key is stored and tested — so we never
    /// validate a stale stored key while a freshly entered one is waiting. When
    /// the field is empty, the already-stored key is tested instead. Readiness
    /// (the green "Ready" state) is only granted once this validation succeeds.
    public func testAPIKey(for providerID: String, enteredKey: String = "") {
        guard let provider = providerCatalog.provider(id: providerID) else {
            return
        }

        let trimmedEnteredKey = enteredKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedEnteredKey.isEmpty {
            do {
                try secretStore.saveSecret(trimmedEnteredKey, for: provider.keychainAccount)
                storedAPIKeyProviderIDs.insert(providerID)
            } catch {
                providerCredentialValidationStates[providerID] = .failed(error.localizedDescription)
                return
            }
        }

        guard hasStoredAPIKey(for: providerID) else {
            providerCredentialValidationStates[providerID] = .failed("Add a \(provider.name) API key before testing.")
            return
        }

        // Any test invalidates a prior validation until it succeeds again.
        providerSettings.setCredentialValidated(false, for: providerID)
        providerCredentialValidationStates[providerID] = .testing
        let modelID = providerSettings.modelID(for: providerID, fallback: provider.modelLabel)

        Task {
            do {
                try await cloudProvider(for: providerID)?.validateCredentials(modelID: modelID)
                await MainActor.run {
                    self.providerSettings.setCredentialValidated(true, for: providerID)
                    self.providerCredentialValidationStates[providerID] = .succeeded("\(provider.name) is ready. The key was accepted for model “\(modelID)”.")
                }
            } catch {
                await MainActor.run {
                    self.providerSettings.setCredentialValidated(false, for: providerID)
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

    public func requestAccessibilityPermissionPrompt() {
        transcriptInsertionService.requestAccessibilityPermissionPrompt()
        refreshAccessibilityPermissionStatus()
        refreshTranscriptInsertionDebugSnapshot()
    }

    public func openAccessibilityPrivacySettings() {
        transcriptInsertionService.openAccessibilitySettings()
        refreshAccessibilityPermissionStatus()
        refreshTranscriptInsertionDebugSnapshot()
    }

    public func refreshLaunchAtLoginStatus() {
        let status = launchAtLoginService.refreshStatus()
        launchAtLoginStatus = status
        generalSettings.launchAtLoginEnabled = status.toggleValue
    }

    public func setLaunchAtLoginEnabled(_ enabled: Bool) {
        let status = launchAtLoginService.setEnabled(enabled)
        launchAtLoginStatus = status
        generalSettings.launchAtLoginEnabled = status.toggleValue
    }

    public func openLoginItemsSettings() {
        launchAtLoginService.openSystemSettings()
    }

    public func refreshAccessibilityPermissionStatus() {
        transcriptInsertionService.refreshPermissionStatus()
        accessibilityPermissionStatus = transcriptInsertionService.accessibilityPermissionStatus
        refreshTranscriptInsertionDebugSnapshot()
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

    /// Resets a single cloud provider to its defaults: restores the default
    /// model ID, withdraws privacy consent, removes any stored API key, and
    /// clears its validation state. Other providers are untouched.
    public func resetCloudProvider(_ providerID: String) {
        let defaults = ProviderSettings()
        switch providerID {
        case "openai":
            providerSettings.openAIModelID = defaults.openAIModelID
            providerSettings.openAIPrivacyAcknowledged = false
            providerSettings.openAIEnabled = false
        case "groq":
            providerSettings.groqModelID = defaults.groqModelID
            providerSettings.groqPrivacyAcknowledged = false
            providerSettings.groqEnabled = false
        default:
            break
        }

        if hasStoredAPIKey(for: providerID) {
            removeAPIKey(for: providerID)
        }

        providerSettings.setCredentialValidated(false, for: providerID)
        providerCredentialValidationStates[providerID] = .idle
    }

    private func persistPreferences() {
        preferencesStore.save(
            AppPreferencesSnapshot(
                launchAtLoginEnabled: generalSettings.launchAtLoginEnabled,
                showMenuBarIcon: generalSettings.showMenuBarIcon,
                insertTranscriptIntoActiveApp: generalSettings.insertTranscriptIntoActiveApp,
                alsoCopyTranscriptToClipboard: generalSettings.alsoCopyTranscriptToClipboard,
                restoreClipboardAfterInsertion: generalSettings.restoreClipboardAfterInsertion,
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
                groqPrivacyAcknowledged: providerSettings.groqPrivacyAcknowledged,
                openAICredentialValidated: providerSettings.openAICredentialValidated,
                groqCredentialValidated: providerSettings.groqCredentialValidated
            )
        )
    }

    func appendPendingRecording(_ recording: RecordedAudioAsset) {
        let entry = HistoryEntry.pendingRecording(
            recording: recording,
            modelID: selectedModel?.id,
            modelName: selectedModel?.name
        )

        do {
            try persistHistoryEntry(entry)

            // Flow B: no transcription configured — keep the recording and show
            // the recorder result card. Never spin a "Transcribing…" state.
            guard isTranscriptionConfigured else {
                pendingInsertionEntryID = nil
                transcriptInsertionService.clearCapturedTarget()
                refreshTranscriptInsertionDebugSnapshot()
                setOverlaySupplementalPhase(.unconfigured(OverlayUnconfiguredPayload(
                    entryID: entry.id,
                    fileName: entry.displayName,
                    durationSeconds: entry.durationSeconds
                )))
                return
            }

            // Flow A: transcribe the dictation. handleCompletedTranscription then
            // inserts into the focused field, or shows the transcript preview.
            pendingInsertionEntryID = entry.id
            setOverlaySupplementalPhase(.transcribing("Transcribing your dictation…"))
            transcribe(entry)
        } catch {
            historyActionMessage = error.localizedDescription
            setOverlaySupplementalPhase(.error(error.localizedDescription))
            scheduleOverlaySupplementalClear(after: .seconds(2))
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
        guard transcriptionPreferences.autoTranscribeAfterCapture, isTranscriptionConfigured else {
            return
        }

        guard entry.transcriptionStatus == .pending else {
            return
        }

        transcribe(entry)
    }

    private func beginVoiceInputCapture() {
        guard generalSettings.insertTranscriptIntoActiveApp else {
            pendingInsertionEntryID = nil
            transcriptInsertionService.clearCapturedTarget()
            refreshTranscriptInsertionDebugSnapshot()
            return
        }

        refreshAccessibilityPermissionStatus()
        transcriptInsertionService.captureCurrentTargetIfNeeded()
        refreshTranscriptInsertionDebugSnapshot()
    }

    func handleCompletedTranscription(for entry: HistoryEntry) {
        guard entry.id == pendingInsertionEntryID else {
            return
        }

        pendingInsertionEntryID = nil

        Task { @MainActor in
            if generalSettings.insertTranscriptIntoActiveApp {
                setOverlaySupplementalPhase(.inserting("Restoring the previous app and inserting your transcript."))
            }

            let outcome = await transcriptInsertionService.insertCapturedTranscript(
                entry.transcriptText,
                settings: generalSettings
            )
            refreshTranscriptInsertionDebugSnapshot()
            historyActionMessage = outcome.message

            switch outcome {
            case let .inserted(message):
                // Pasted straight into the focused field — quick confirmation.
                setOverlaySupplementalPhase(.saved(message))
                scheduleOverlaySupplementalClear(after: .seconds(1.6))
            case .copiedToClipboard, .savedOnly:
                // No focused field to paste into — show the interactive preview.
                presentTranscriptPreview(for: entry)
            case let .failed(message):
                setOverlaySupplementalPhase(.error(message))
                scheduleOverlaySupplementalClear(after: .seconds(2))
            }
        }
    }

    private func presentTranscriptPreview(for entry: HistoryEntry) {
        setOverlaySupplementalPhase(.preview(OverlayPreviewPayload(
            entryID: entry.id,
            transcript: entry.transcriptText,
            modelName: entry.modelName,
            durationSeconds: entry.durationSeconds
        )))
    }

    /// Action callbacks for the overlay result cards (preview / unconfigured).
    private func makeOverlayActions() -> RecordingOverlayActions {
        RecordingOverlayActions(
            copy: { [weak self] id in
                guard let self, let entry = self.historyEntry(id: id) else { return }
                self.copyTranscript(for: entry)
            },
            save: { [weak self] _ in
                // Already persisted to history — Save just keeps it and dismisses.
                self?.dismissOverlayResult()
            },
            delete: { [weak self] id in
                guard let self, let entry = self.historyEntry(id: id) else { return }
                self.deleteHistoryEntry(entry)
                self.dismissOverlayResult()
            },
            showAll: { [weak self] id in
                guard let self else { return }
                self.dismissOverlayResult()
                self.openHistoryEntry(id)
                NSApplication.shared.activate(ignoringOtherApps: true)
            },
            retranscribe: { [weak self] id, option in
                guard let self, let entry = self.historyEntry(id: id) else { return }
                self.pendingInsertionEntryID = entry.id
                self.setOverlaySupplementalPhase(.transcribing("Re-transcribing…"))
                switch option.kind {
                case let .localModel(modelID):
                    self.retranscribe(entry, using: modelID)
                case let .cloudProvider(providerID):
                    self.retranscribe(entry, usingProvider: providerID)
                }
            },
            retranscribeOptions: { [weak self] in
                self?.overlayRetranscribeOptions() ?? []
            },
            configureTranscription: { [weak self] in
                guard let self else { return }
                self.dismissOverlayResult()
                self.sidebarSelection = .screen(.models)
                NSApplication.shared.activate(ignoringOtherApps: true)
            },
            dismiss: { [weak self] in
                self?.dismissOverlayResult()
            }
        )
    }

    /// Re-transcription choices for the preview menu: every downloaded local
    /// model plus every set-up cloud provider. Always non-empty in a configured
    /// state, so "Re-transcribe with Different Model" is always offered.
    private func overlayRetranscribeOptions() -> [OverlayRetranscribeOption] {
        var options: [OverlayRetranscribeOption] = []

        for model in modelCatalog.localModels where readyLocalModelIDs.contains(model.id) {
            options.append(OverlayRetranscribeOption(
                id: "local:\(model.id)",
                title: model.name,
                isCloud: false,
                kind: .localModel(model.id)
            ))
        }

        for provider in providerCatalog.providers where providerRuntimeState(for: provider).isSelectable {
            options.append(OverlayRetranscribeOption(
                id: "cloud:\(provider.id)",
                title: provider.name,
                isCloud: true,
                kind: .cloudProvider(provider.id)
            ))
        }

        return options
    }

    /// Dismisses any overlay result card.
    public func dismissOverlayResult() {
        overlaySupplementalClearTask?.cancel()
        overlaySupplementalPhase = nil
        recordingOverlayManager.refreshPresentation()
    }

    private func handleFailedTranscription(for entryID: UUID, message: String) {
        guard entryID == pendingInsertionEntryID else {
            return
        }

        pendingInsertionEntryID = nil
        transcriptInsertionService.clearCapturedTarget()
        refreshTranscriptInsertionDebugSnapshot()
        historyActionMessage = message
        setOverlaySupplementalPhase(.error(message))
        scheduleOverlaySupplementalClear(after: .seconds(2))
    }

    private func refreshTranscriptInsertionDebugSnapshot() {
        transcriptInsertionDebugSnapshot = transcriptInsertionService.debugSnapshot
    }

    private func markPendingInsertionFailure(entryID: UUID, message: String) {
        guard var entry = historyEntry(id: entryID), !entry.hasCompletedTranscript else {
            return
        }

        entry.transcriptionStatus = .failed
        entry.errorMessage = message
        entry.transcriptPreview = message
        try? persistHistoryEntry(entry)
    }

    private func setOverlaySupplementalPhase(_ phase: OverlaySupplementalPhase?) {
        overlaySupplementalClearTask?.cancel()
        overlaySupplementalPhase = phase
        recordingOverlayManager.refreshPresentation()
    }

    private func scheduleOverlaySupplementalClear(after duration: Duration) {
        overlaySupplementalClearTask?.cancel()
        overlaySupplementalClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: duration)
            self?.overlaySupplementalPhase = nil
            self?.recordingOverlayManager.refreshPresentation()
        }
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
