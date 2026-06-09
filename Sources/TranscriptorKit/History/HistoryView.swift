import SwiftUI

public struct HistoryView: View {
    @State private var searchText = ""
    @State private var selectedFilter: HistoryFilter = .all
    @State private var selectedEntryID: HistoryEntry.ID?
    @State private var entryPendingDeletion: HistoryEntry?
    @State private var showDeleteAllConfirmation = false
    @Bindable private var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
        _selectedEntryID = State(initialValue: appState.historyStore.entries.first?.id)
    }

    public var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 0) {
                headerControls

                Group {
                    if filteredEntries.isEmpty {
                        emptyState
                    } else {
                        List(filteredEntries, selection: $selectedEntryID) { entry in
                            historyRow(entry)
                                .tag(entry.id)
                                .contextMenu {
                                    if canTriggerTranscription(for: entry) {
                                        Button(entry.hasCompletedTranscript ? "Re-transcribe" : "Transcribe") {
                                            appState.transcribe(entry)
                                        }
                                    }

                                    if appState.transcriptionQueueController.isQueuedOrRunning(entryID: entry.id) {
                                        Button("Cancel Transcription") {
                                            appState.cancelTranscription(for: entry)
                                        }
                                    }

                                    Button("Play / Pause") {
                                        appState.togglePlayback(for: entry)
                                    }
                                    .disabled(!hasPlayableAudioFile(entry))

                                    Button("Copy Transcript") {
                                        appState.copyTranscript(for: entry)
                                    }
                                    .disabled(!entry.canCopyTranscript)

                                    Button("Export Transcript") {
                                        appState.exportTranscript(for: entry)
                                    }
                                    .disabled(!entry.canExportTranscript)

                                    Divider()

                                    Button("Delete", role: .destructive) {
                                        entryPendingDeletion = entry
                                    }
                                }
                        }
                        .listStyle(.inset(alternatesRowBackgrounds: true))
                    }
                }
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
                .searchable(text: $searchText, prompt: "Search transcripts, filenames, or models")
            }

            detailPane
                .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .onReceive(NotificationCenter.default.publisher(for: .transcriptorFocusHistorySearch)) { _ in
            appState.selectedScreen = .history
        }
        .navigationTitle("History")
        .alert("Delete History Item", isPresented: Binding(
            get: { entryPendingDeletion != nil },
            set: { newValue in
                if !newValue {
                    entryPendingDeletion = nil
                }
            }
        )) {
            Button("Delete", role: .destructive) {
                if let entryPendingDeletion {
                    appState.deleteHistoryEntry(entryPendingDeletion)
                }
                entryPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                entryPendingDeletion = nil
            }
        } message: {
            Text("This removes the history record and its managed local files.")
        }
        .confirmationDialog("Delete all history?", isPresented: $showDeleteAllConfirmation, titleVisibility: .visible) {
            Button("Delete All", role: .destructive) {
                appState.deleteAllHistory()
            }
        } message: {
            Text("This removes every stored history item and all managed audio files.")
        }
    }

    private var headerControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("History")
                .font(.title2.weight(.semibold))

            Picker("Source", selection: $selectedFilter) {
                ForEach(HistoryFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                if let historyActionMessage = appState.historyActionMessage {
                    Text(historyActionMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let storageWarningMessage = appState.storageWarningMessage {
                    Text(storageWarningMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("\(filteredEntries.count) item\(filteredEntries.count == 1 ? "" : "s") • \(megabyteString(for: appState.storageUsage.totalManagedBytes)) / \(appState.storageSettings.capMegabytes) MB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Delete All", role: .destructive) {
                    showDeleteAllConfirmation = true
                }
                .disabled(appState.historyStore.entries.isEmpty)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            searchText.isEmpty ? "No History Yet" : "No Matching Transcripts",
            systemImage: "text.quote",
            description: Text(searchText.isEmpty ? "Record or import audio to build a durable local history." : "Try a different filter or search term.")
        )
    }

    private var detailPane: some View {
        Group {
            if let entry = selectedEntry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(entry.displayName)
                                    .font(.title.weight(.semibold))
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)

                                Text("\(formattedDate(entry.createdAt)) • \(durationLabel(entry.durationSeconds)) • \(entry.characterCount) characters")
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 8) {
                                    detailTag(entry.transcriptionStatus.title)
                                    detailTag(entry.sourceType.title)
                                    if let modelName = entry.modelName {
                                        detailTag(modelName)
                                    }
                                    if let providerName = entry.providerName {
                                        detailTag(providerName)
                                    }
                                }
                            }

                            Spacer()
                        }

                        actionBar(for: entry)

                        if let progress = appState.transcriptionQueueController.progress(for: entry.id) {
                            progressCard(progress)
                        }

                        if let preferredCloudProvider = appState.preferredCloudProvider {
                            cloudPrivacyCard(for: preferredCloudProvider)
                        }

                        if let historyActionMessage = appState.historyActionMessage {
                            UnavailableActionBanner(message: historyActionMessage)
                        }

                        if hasMissingAudioFile(entry) {
                            UnavailableActionBanner(message: "The original audio file is missing from disk. Playback and re-transcription stay disabled until the file is restored.")
                        }

                        if let queueError = appState.transcriptionQueueController.lastErrorByEntryID[entry.id] {
                            UnavailableActionBanner(message: queueError)
                        }

                        if let errorMessage = entry.errorMessage {
                            UnavailableActionBanner(message: errorMessage)
                        }

                        if entry.transcriptionStatus != .completed && !appState.transcriptionQueueController.isQueuedOrRunning(entryID: entry.id) {
                            UnavailableActionBanner(
                                message: "This item has not been transcribed yet. Download a local Whisper model, then start transcription from this pane."
                            )
                        }

                        if entry.transcriptionStatus == .completed && !entry.canCopyTranscript {
                            UnavailableActionBanner(message: "This history item completed without transcript text, so copy and export remain disabled.")
                        }

                        Divider()

                        SectionCard(
                            title: "Transcript",
                            subtitle: "Latest saved transcript text for this history item."
                        ) {
                            if let latestVersion = entry.latestTranscriptVersion {
                                latestTranscriptSummary(version: latestVersion)
                            }

                            Text(displayTranscriptText(for: entry))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        SectionCard(
                            title: "Details",
                            subtitle: "Saved metadata, audio paths, and file information."
                        ) {
                            metadataGrid(for: entry)
                        }

                        transcriptVersionSection(for: entry)
                    }
                    .padding(24)
                }
            } else {
                ContentUnavailableView(
                    "Select a Transcript",
                    systemImage: "sidebar.right",
                    description: Text("Choose a history item to inspect its transcript, playback controls, and storage details.")
                )
            }
        }
    }

    private func actionBar(for entry: HistoryEntry) -> some View {
        HStack(spacing: 10) {
            if appState.transcriptionQueueController.isQueuedOrRunning(entryID: entry.id) {
                Button("Cancel") {
                    appState.cancelTranscription(for: entry)
                }
            } else if canTriggerTranscription(for: entry) {
                Button(entry.hasCompletedTranscript ? "Transcribe Again" : "Transcribe Now") {
                    appState.transcribe(entry)
                }
            }

            if !availableRetranscriptionPlans.isEmpty {
                Menu("Re-transcribe") {
                    if !downloadedWhisperModels.isEmpty {
                        Section("Local Models") {
                            ForEach(downloadedWhisperModels) { model in
                                Button(model.name) {
                                    appState.retranscribe(entry, using: model.id)
                                }
                            }
                        }
                    }

                    let cloudPlans = availableRetranscriptionPlans.filter { $0.kind == .cloud }
                    if !cloudPlans.isEmpty {
                        Section("Cloud Providers") {
                            ForEach(cloudPlans) { plan in
                                Button("\(plan.providerName) (\(plan.modelName))") {
                                    appState.retranscribe(entry, usingProvider: plan.providerID)
                                }
                            }
                        }
                    }
                }
                .disabled(availableRetranscriptionPlans.isEmpty || appState.transcriptionQueueController.isQueuedOrRunning(entryID: entry.id))
            }

            Button("Copy Transcript") {
                appState.copyTranscript(for: entry)
            }
            .disabled(!entry.canCopyTranscript)

            Button("Export .txt") {
                appState.exportTranscript(for: entry)
            }
            .disabled(!entry.canExportTranscript)

            Button(playbackButtonTitle(for: entry)) {
                appState.togglePlayback(for: entry)
            }
            .disabled(!hasPlayableAudioFile(entry))

            Spacer()

            Button("Delete", role: .destructive) {
                entryPendingDeletion = entry
            }
        }
    }

    private func progressCard(_ progress: TranscriptionProgress) -> some View {
        SectionCard(
            title: "Transcription Progress",
            subtitle: progress.statusMessage
        ) {
            if let fractionCompleted = progress.fractionCompleted {
                ProgressView(value: fractionCompleted)
            } else {
                ProgressView()
            }

            if !progress.partialText.isEmpty {
                Text(progress.partialText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
    }

    private func cloudPrivacyCard(for provider: ProviderDescriptor) -> some View {
        SectionCard(
            title: "Cloud Transcription",
            subtitle: "This provider uploads audio only after it is explicitly enabled."
        ) {
            Label("\(provider.privacySummary) Configure or disable this in Settings > Cloud Providers.", systemImage: "icloud.and.arrow.up")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func latestTranscriptSummary(version: TranscriptVersion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                detailTag(version.modelName ?? "Unknown Model")
                detailTag(version.providerName ?? "Local")
                detailTag(formattedDate(version.createdAt))
            }
        }
    }

    private func metadataGrid(for entry: HistoryEntry) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
            metadataRow(title: "Original Audio", value: entry.originalFilePath ?? "Unavailable")
            metadataRow(title: "Working Audio", value: entry.workingFilePath ?? "Unavailable")
            metadataRow(title: "File Size", value: byteCountFormatter.string(fromByteCount: entry.fileSizeBytes))
            metadataRow(title: "Language", value: entry.language ?? "Unknown")
            metadataRow(title: "Model", value: entry.modelName ?? "Not assigned")
            metadataRow(title: "Provider", value: entry.providerName ?? "Local")
        }
    }

    private func metadataRow(title: String, value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .font(title.contains("Audio") ? .system(.caption, design: .monospaced) : .body)
                .lineLimit(title.contains("Audio") ? 3 : 2)
                .truncationMode(title.contains("Audio") ? .middle : .tail)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func transcriptVersionSection(for entry: HistoryEntry) -> some View {
        if !entry.transcriptVersions.isEmpty {
            SectionCard(
                title: "Transcript Versions",
                subtitle: "Older transcripts are preserved when you re-transcribe with a different model or provider."
            ) {
                ForEach(entry.transcriptVersions.sorted(by: { $0.createdAt > $1.createdAt })) { version in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(version.modelName ?? "Unknown Model")
                                .font(.subheadline.weight(.semibold))
                            Text("\(formattedDate(version.createdAt)) • \(version.providerName ?? "Local")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(version.characterCount) chars")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var filteredEntries: [HistoryEntry] {
        appState.historyStore.entries.filter { entry in
            matchesFilter(entry) && matchesSearch(entry)
        }
    }

    private var selectedEntry: HistoryEntry? {
        filteredEntries.first { $0.id == selectedEntryID } ?? filteredEntries.first
    }

    private var downloadedWhisperModels: [ModelDescriptor] {
        appState.whisperModelManager.downloadedWhisperModels()
    }

    private var availableRetranscriptionPlans: [TranscriptionExecutionPlan] {
        appState.availableRetranscriptionPlans()
    }

    private func matchesFilter(_ entry: HistoryEntry) -> Bool {
        switch selectedFilter {
        case .all:
            true
        case .dictations:
            entry.sourceType == .dictation
        case .imports:
            entry.sourceType == .importedAudio
        }
    }

    private func matchesSearch(_ entry: HistoryEntry) -> Bool {
        guard !searchText.isEmpty else {
            return true
        }

        return entry.searchableText.localizedCaseInsensitiveContains(searchText)
    }

    private func canTriggerTranscription(for entry: HistoryEntry) -> Bool {
        guard hasPlayableAudioFile(entry) else {
            return false
        }

        return (try? appState.transcriptionTargetResolver.resolve(
            preferences: appState.transcriptionPreferences,
            providerSettings: appState.providerSettings,
            readyLocalModelIDs: appState.readyLocalModelIDs,
            providerStatesByID: appState.providerRuntimeStates
        )) != nil
    }

    private func historyRow(_ entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayPreviewText(for: entry))
                .font(.body.weight(.medium))
                .lineLimit(2)

            if let progress = appState.transcriptionQueueController.progress(for: entry.id) {
                if let fractionCompleted = progress.fractionCompleted {
                    ProgressView(value: fractionCompleted)
                        .progressViewStyle(.linear)
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                metadataLabel(systemImage: "calendar", text: formattedDate(entry.createdAt))
                metadataLabel(systemImage: "clock", text: durationLabel(entry.durationSeconds))
                metadataLabel(systemImage: "textformat.abc", text: "\(entry.characterCount) chars")
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                metadataLabel(systemImage: "tray.full", text: entry.sourceType.title)
                metadataLabel(systemImage: "waveform", text: rowStatusText(for: entry))

                if let modelName = entry.modelName {
                    metadataLabel(systemImage: "cube.transparent", text: modelName)
                }

                if let providerName = entry.providerName {
                    metadataLabel(systemImage: "network", text: providerName)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func displayTranscriptText(for entry: HistoryEntry) -> String {
        if !entry.transcriptText.isEmpty {
            return entry.transcriptText
        }

        if let partialText = appState.transcriptionQueueController.progress(for: entry.id)?.partialText,
           !partialText.isEmpty {
            return partialText
        }

        switch entry.transcriptionStatus {
        case .pending:
            return "Pending transcription..."
        case .transcribing:
            return "Transcribing..."
        case .completed:
            return "No transcript text available."
        case .failed:
            return entry.errorMessage ?? "This history item failed."
        }
    }

    private func displayPreviewText(for entry: HistoryEntry) -> String {
        if let partialText = appState.transcriptionQueueController.progress(for: entry.id)?.partialText,
           !partialText.isEmpty {
            return partialText
        }

        return entry.transcriptPreview
    }

    private func rowStatusText(for entry: HistoryEntry) -> String {
        if let progress = appState.transcriptionQueueController.progress(for: entry.id) {
            return progress.statusMessage
        }

        return entry.transcriptionStatus.title
    }

    private func hasPlayableAudioFile(_ entry: HistoryEntry) -> Bool {
        guard let playbackPath = entry.preferredPlaybackPath else {
            return false
        }

        return FileManager.default.fileExists(atPath: playbackPath)
    }

    private func hasMissingAudioFile(_ entry: HistoryEntry) -> Bool {
        entry.preferredPlaybackPath != nil && !hasPlayableAudioFile(entry)
    }

    private func playbackButtonTitle(for entry: HistoryEntry) -> String {
        if appState.audioPlaybackService.isPlaying,
           appState.audioPlaybackService.currentlyPlayingEntryID == entry.id {
            return "Pause"
        }

        return "Play"
    }

    private func detailTag(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
    }

    private func metadataLabel(systemImage: String, text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func durationLabel(_ durationSeconds: Int) -> String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func megabyteString(for bytes: Int64) -> String {
        String(format: "%.2f", Double(bytes) / 1_048_576)
    }

    private var byteCountFormatter: ByteCountFormatter {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter
    }
}

#if DEBUG
struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView(appState: .preview)
            .frame(width: 1280, height: 820)
    }
}
#endif
