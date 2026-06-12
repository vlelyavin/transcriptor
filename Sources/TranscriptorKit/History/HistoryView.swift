import AppKit
import SwiftUI

public struct HistoryView: View {
    @State private var searchText = ""
    @State private var selectedFilter: HistoryFilter = .all
    @State private var selectedEntryID: HistoryEntry.ID?
    @State private var isCompactDetailVisible = false
    @State private var entryPendingDeletion: HistoryEntry?
    @State private var showDeleteAllConfirmation = false
    @Bindable private var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
        let initialID = appState.pendingHistoryEntryID ?? appState.historyStore.entries.first?.id
        _selectedEntryID = State(initialValue: initialID)
        _isCompactDetailVisible = State(initialValue: appState.pendingHistoryEntryID != nil)
    }

    public var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 980

            Group {
                if compact {
                    if isCompactDetailVisible, selectedEntry != nil {
                        detailPane(isCompact: true)
                    } else {
                        historyListPane(isCompact: true)
                    }
                } else {
                    HSplitView {
                        historyListPane(isCompact: false)
                            .frame(minWidth: 320, idealWidth: 380, maxWidth: 460, maxHeight: .infinity)

                        detailPane(isCompact: false)
                            .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .onReceive(NotificationCenter.default.publisher(for: .transcriptorFocusHistorySearch)) { _ in
            appState.selectedScreen = .history
        }
        .onAppear {
            if let pending = appState.pendingHistoryEntryID {
                selectedEntryID = pending
                isCompactDetailVisible = true
                appState.pendingHistoryEntryID = nil
            }
        }
        .onChange(of: appState.pendingHistoryEntryID) { _, newValue in
            if let newValue {
                selectedEntryID = newValue
                isCompactDetailVisible = true
                appState.pendingHistoryEntryID = nil
            }
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

    private func historyListPane(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            headerControls(isCompact: isCompact)

            Group {
                if filteredEntries.isEmpty {
                    emptyState
                } else {
                    List(filteredEntries, selection: isCompact ? .constant(nil) : $selectedEntryID) { entry in
                        Button {
                            selectedEntryID = entry.id
                            if isCompact {
                                isCompactDetailVisible = true
                            }
                        } label: {
                            historyRow(entry)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .tag(entry.id)
                        .contextMenu {
                            if canTriggerTranscription(for: entry) {
                                Button(entry.hasCompletedTranscript ? "Re-transcribe" : "Transcribe") {
                                    appState.transcribe(entry)
                                }
                            } else if !appState.isTranscriptionConfigured {
                                Button("Set Up Transcription…") {
                                    appState.selectedScreen = .models
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
                    .listStyle(.inset(alternatesRowBackgrounds: false))
                }
            }
            .searchable(text: $searchText, prompt: "Search transcripts, filenames, or models")
        }
    }

    private func headerControls(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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

                if !isCompact {
                    Button("Delete All", role: .destructive) {
                        showDeleteAllConfirmation = true
                    }
                    .disabled(appState.historyStore.entries.isEmpty)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            searchText.isEmpty ? "No History Yet" : "No Matching Transcripts",
            systemImage: "text.quote",
            description: Text(searchText.isEmpty ? "Record or import audio to build a durable local history." : "Try a different filter or search term.")
        )
    }

    private func detailPane(isCompact: Bool) -> some View {
        Group {
            if let entry = selectedEntry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if isCompact {
                            Button {
                                isCompactDetailVisible = false
                            } label: {
                                Label("History", systemImage: "chevron.backward")
                            }
                            .buttonStyle(.borderless)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.displayName)
                                .font(.title3.weight(.semibold))
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)

                            Text("\(formattedDate(entry.createdAt)) • \(durationLabel(entry.durationSeconds)) • \(entry.characterCount) characters")
                                .font(.callout)
                                .foregroundStyle(.secondary)

                            Text(detailSummaryLine(for: entry))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        actionBar(for: entry, isCompact: isCompact)

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
                            if appState.isTranscriptionConfigured {
                                UnavailableActionBanner(
                                    message: "This item has not been transcribed yet. Use Transcribe Now above to generate a transcript."
                                )
                            } else {
                                UnavailableActionBanner(
                                    message: "Transcription isn't set up yet. Download a model to transcribe this recording.",
                                    actionTitle: "Open Models"
                                ) {
                                    appState.selectedScreen = .models
                                }
                            }
                        }

                        if entry.transcriptionStatus == .completed && !entry.canCopyTranscript {
                            UnavailableActionBanner(message: "This history item completed without transcript text, so copy and export remain disabled.")
                        }

                        GroupBox(label: historySectionHeader("Transcript")) {
                            VStack(alignment: .leading, spacing: 8) {
                                if let latestVersion = entry.latestTranscriptVersion {
                                    latestTranscriptSummary(version: latestVersion)
                                }

                                Text(displayTranscriptText(for: entry))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(6)
                        }

                        GroupBox(label: historySectionHeader("Details")) {
                            metadataGrid(for: entry)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(6)
                        }

                        transcriptVersionSection(for: entry)
                    }
                    .padding(.horizontal, isCompact ? 20 : 24)
                    .padding(.vertical, isCompact ? 18 : 24)
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

    private func detailSummaryLine(for entry: HistoryEntry) -> String {
        var parts = [entry.transcriptionStatus.title, entry.sourceType.title]
        if let modelName = entry.modelName {
            parts.append(modelName)
        }
        if let providerName = entry.providerName {
            parts.append(providerName)
        }
        return parts.joined(separator: " • ")
    }

    private func actionBar(for entry: HistoryEntry, isCompact: Bool) -> some View {
        HStack(spacing: 8) {
            if appState.transcriptionQueueController.isQueuedOrRunning(entryID: entry.id) {
                Button("Cancel") {
                    appState.cancelTranscription(for: entry)
                }
            } else if canTriggerTranscription(for: entry) {
                Button(entry.hasCompletedTranscript ? "Transcribe Again" : "Transcribe Now") {
                    appState.transcribe(entry)
                }
            }

            Button(playbackButtonTitle(for: entry), systemImage: playbackButtonSymbol(for: entry)) {
                appState.togglePlayback(for: entry)
            }
            .disabled(!hasPlayableAudioFile(entry))

            Button("Copy") {
                appState.copyTranscript(for: entry)
            }
            .disabled(!entry.canCopyTranscript)

            Spacer()

            Menu {
                if !availableRetranscriptionPlans.isEmpty {
                    Menu("Re-transcribe With") {
                        if !downloadedLocalModels.isEmpty {
                            Section("Local Models") {
                                ForEach(downloadedLocalModels) { model in
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
                    .disabled(appState.transcriptionQueueController.isQueuedOrRunning(entryID: entry.id))
                }

                Button("Export Transcript…") {
                    appState.exportTranscript(for: entry)
                }
                .disabled(!entry.canExportTranscript)

                Divider()

                Button("Delete…", role: .destructive) {
                    entryPendingDeletion = entry
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private func progressCard(_ progress: TranscriptionProgress) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text(progress.statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)

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
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func cloudPrivacyCard(for provider: ProviderDescriptor) -> some View {
        Label("\(provider.privacySummary) Configure or disable this in Settings > Cloud Providers.", systemImage: "icloud.and.arrow.up")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func latestTranscriptSummary(version: TranscriptVersion) -> some View {
        Text("\(version.modelName ?? "Unknown Model") • \(version.providerName ?? "Local") • \(formattedDate(version.createdAt))")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// Section header styled to match the grouped-form section labels used on
    /// the other pages (small, semibold, secondary) instead of the heavier
    /// default `GroupBox` title.
    private func historySectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func metadataGrid(for entry: HistoryEntry) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
            audioMetadataRow(for: entry)
            metadataRow(title: "File Size", value: byteCountFormatter.string(fromByteCount: entry.fileSizeBytes))
            metadataRow(title: "Language", value: entry.language ?? "Unknown")
            metadataRow(title: "Model", value: entry.modelName ?? "Not assigned")
            metadataRow(title: "Provider", value: entry.providerName ?? "Local")
        }
    }

    /// A single "Audio" row that replaces the two raw file-path rows. The path is
    /// surfaced as a "View in Finder" button rather than printed in full.
    private func audioMetadataRow(for entry: HistoryEntry) -> some View {
        GridRow {
            Text("Audio")
                .foregroundStyle(.secondary)
            if let path = audioRevealPath(for: entry) {
                Button("View in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                }
                .buttonStyle(.link)
                .gridColumnAlignment(.leading)
            } else {
                Text("Unavailable")
            }
        }
    }

    private func audioRevealPath(for entry: HistoryEntry) -> String? {
        let candidates = [entry.preferredPlaybackPath, entry.workingFilePath, entry.originalFilePath]
        return candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0) }
    }

    private func metadataRow(title: String, value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func transcriptVersionSection(for entry: HistoryEntry) -> some View {
        if !entry.transcriptVersions.isEmpty {
            GroupBox(label: historySectionHeader("Transcript Versions")) {
                VStack(spacing: 0) {
                    ForEach(entry.transcriptVersions.sorted(by: { $0.createdAt > $1.createdAt })) { version in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(version.modelName ?? "Unknown Model")
                                    .font(.subheadline)
                                Text("\(formattedDate(version.createdAt)) • \(version.providerName ?? "Local")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(version.characterCount) characters")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
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

    private var downloadedLocalModels: [ModelDescriptor] {
        appState.modelCatalog.localModels.filter { appState.readyLocalModelIDs.contains($0.id) }
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

            Text("\(formattedDate(entry.createdAt)) • \(durationLabel(entry.durationSeconds)) • \(entry.characterCount) characters")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(rowDetailLine(for: entry))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.vertical, 4)
    }

    private func rowDetailLine(for entry: HistoryEntry) -> String {
        var parts = [entry.sourceType.title, rowStatusText(for: entry)]
        if let modelName = entry.modelName {
            parts.append(modelName)
        }
        if let providerName = entry.providerName {
            parts.append(providerName)
        }
        return parts.joined(separator: " • ")
    }

    private func playbackButtonSymbol(for entry: HistoryEntry) -> String {
        if appState.audioPlaybackService.isPlaying,
           appState.audioPlaybackService.currentlyPlayingEntryID == entry.id {
            return "pause.fill"
        }

        return "play.fill"
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
