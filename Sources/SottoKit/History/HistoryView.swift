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
                                    Button("Play / Pause") {
                                        appState.togglePlayback(for: entry)
                                    }
                                    .disabled(entry.preferredPlaybackPath == nil)

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
                        .listStyle(.inset)
                    }
                }
                .frame(minWidth: 420)
                .searchable(text: $searchText, prompt: "Search transcripts, filenames, or models")
            }

            detailPane
                .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
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
                    Text("\(filteredEntries.count) item\(filteredEntries.count == 1 ? "" : "s")")
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
                                    .font(.largeTitle.weight(.semibold))

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

                        HStack(spacing: 10) {
                            Button("Copy Transcript") {
                                appState.copyTranscript(for: entry)
                            }
                            .disabled(!entry.canCopyTranscript)

                            Button("Export .txt") {
                                appState.exportTranscript(for: entry)
                            }
                            .disabled(!entry.canExportTranscript)

                            Button("Re-transcribe") {}
                                .disabled(true)

                            Button(playbackButtonTitle(for: entry)) {
                                appState.togglePlayback(for: entry)
                            }
                            .disabled(entry.preferredPlaybackPath == nil)

                            Spacer()

                            Button("Delete", role: .destructive) {
                                entryPendingDeletion = entry
                            }
                        }

                        if let historyActionMessage = appState.historyActionMessage {
                            UnavailableActionBanner(message: historyActionMessage)
                        }

                        if let errorMessage = entry.errorMessage {
                            UnavailableActionBanner(message: errorMessage)
                        }

                        if entry.transcriptionStatus != .completed {
                            UnavailableActionBanner(
                                message: "This item has not been transcribed yet. Copy and export unlock when real transcript text exists."
                            )
                        }

                        Divider()

                        metadataGrid(for: entry)

                        Text(displayTranscriptText(for: entry))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                .textSelection(.enabled)
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

    private func historyRow(_ entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formattedDate(entry.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let modelName = entry.modelName {
                    detailTag(modelName)
                }
            }

            Text(displayPreviewText(for: entry))
                .font(.headline)
                .lineLimit(2)

            HStack(spacing: 12) {
                metadataLabel(systemImage: "clock", text: durationLabel(entry.durationSeconds))
                metadataLabel(systemImage: "textformat.abc", text: "\(entry.characterCount) chars")
                metadataLabel(systemImage: "tray.full", text: entry.sourceType.title)
                metadataLabel(systemImage: "waveform", text: entry.transcriptionStatus.title)
            }
        }
        .padding(.vertical, 6)
    }

    private func displayTranscriptText(for entry: HistoryEntry) -> String {
        if !entry.transcriptText.isEmpty {
            return entry.transcriptText
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
        if !entry.transcriptPreview.isEmpty {
            return entry.transcriptPreview
        }
        return displayTranscriptText(for: entry)
    }

    private func playbackButtonTitle(for entry: HistoryEntry) -> String {
        if appState.audioPlaybackService.currentlyPlayingEntryID == entry.id,
           appState.audioPlaybackService.isPlaying {
            return "Pause"
        }
        return "Play"
    }

    private func metadataLabel(systemImage: String, text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func detailTag(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary, in: Capsule())
    }

    private func durationLabel(_ duration: Int) -> String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var byteCountFormatter: ByteCountFormatter {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }
}

#if DEBUG
struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView(appState: .preview)
            .frame(width: 1280, height: 860)
    }
}
#endif
