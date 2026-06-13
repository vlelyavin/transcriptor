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
            .toolbar {
                // In the narrow single-column layout, a native toolbar back
                // button returns to the list — replacing the old in-content
                // breadcrumb so the detail starts directly with its content.
                if compact, isCompactDetailVisible, selectedEntry != nil {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            isCompactDetailVisible = false
                        } label: {
                            Image(systemName: "chevron.backward")
                        }
                        .help("Back to History")
                    }
                }
            }
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
                // A native grouped Form so section labels, the Details key/value
                // table, and spacing match the rest of the app exactly. The page
                // starts directly with its content — no breadcrumb.
                Form {
                    Section {
                        detailHeader(for: entry)
                            .listRowInsets(EdgeInsets(top: 8, leading: 2, bottom: 4, trailing: 2))
                            .listRowBackground(Color.clear)

                        actionBar(for: entry, isCompact: isCompact)
                            .listRowInsets(EdgeInsets(top: 4, leading: 2, bottom: 8, trailing: 2))
                            .listRowBackground(Color.clear)
                    }

                    if let progress = appState.transcriptionQueueController.progress(for: entry.id) {
                        Section {
                            progressContent(progress)
                        }
                    }

                    if hasAnyBanner(for: entry) {
                        Section {
                            detailBanners(for: entry)
                        }
                    }

                    Section("Transcript") {
                        if let latestVersion = entry.latestTranscriptVersion {
                            latestTranscriptSummary(version: latestVersion)
                        }

                        Text(displayTranscriptText(for: entry))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Section("Details") {
                        detailsRows(for: entry)
                    }

                    if !entry.transcriptVersions.isEmpty {
                        Section("Transcript Versions") {
                            ForEach(entry.transcriptVersions.sorted(by: { $0.createdAt > $1.createdAt })) { version in
                                transcriptVersionRow(version)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
            } else {
                ContentUnavailableView(
                    "Select a Transcript",
                    systemImage: "sidebar.right",
                    description: Text("Choose a history item to inspect its transcript, playback controls, and storage details.")
                )
            }
        }
    }

    private func detailHeader(for entry: HistoryEntry) -> some View {
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
    }

    /// A short, user-facing summary: just status and source. Model/provider live
    /// in the Details table below, so they are not repeated here.
    private func detailSummaryLine(for entry: HistoryEntry) -> String {
        [entry.transcriptionStatus.title, entry.sourceType.title].joined(separator: " • ")
    }

    /// True when at least one actionable/informative banner should be shown.
    /// Purely decorative status messages are intentionally excluded.
    private func hasAnyBanner(for entry: HistoryEntry) -> Bool {
        if hasMissingAudioFile(entry) { return true }
        if appState.transcriptionQueueController.lastErrorByEntryID[entry.id] != nil { return true }
        if entry.errorMessage != nil { return true }
        if needsSetupBanner(for: entry) { return true }
        if entry.transcriptionStatus == .completed && !entry.canCopyTranscript { return true }
        return false
    }

    /// Only shown when transcription is genuinely unavailable (not set up) — an
    /// actionable banner with a direct route to the Models screen. When a model
    /// is configured we don't nag with a "not transcribed yet" message, since the
    /// Transcribe button is right there in the action bar.
    private func needsSetupBanner(for entry: HistoryEntry) -> Bool {
        entry.transcriptionStatus != .completed
            && !appState.transcriptionQueueController.isQueuedOrRunning(entryID: entry.id)
            && !appState.isTranscriptionConfigured
    }

    @ViewBuilder
    private func detailBanners(for entry: HistoryEntry) -> some View {
        if hasMissingAudioFile(entry) {
            UnavailableActionBanner(message: "The original audio file is missing from disk. Playback and re-transcription stay disabled until the file is restored.")
        }

        if let queueError = appState.transcriptionQueueController.lastErrorByEntryID[entry.id] {
            UnavailableActionBanner(message: queueError)
        }

        if let errorMessage = entry.errorMessage {
            UnavailableActionBanner(message: errorMessage)
        }

        if needsSetupBanner(for: entry) {
            UnavailableActionBanner(
                message: "Transcription isn't set up yet. Download a model to transcribe this recording.",
                actionTitle: "Open Models"
            ) {
                appState.selectedScreen = .models
            }
        }

        if entry.transcriptionStatus == .completed && !entry.canCopyTranscript {
            UnavailableActionBanner(message: "This item finished without any transcript text, so copy and export stay disabled.")
        }
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
                Text("More…")
            }
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private func progressContent(_ progress: TranscriptionProgress) -> some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func latestTranscriptSummary(version: TranscriptVersion) -> some View {
        Text("\(humanizedModelName(version.modelName)) • \(humanizedProviderName(version.providerName)) • \(formattedDate(version.createdAt))")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// The Details key/value table, rendered with native `LabeledContent` rows so
    /// it matches the Current Selection / About-style tables elsewhere.
    @ViewBuilder
    private func detailsRows(for entry: HistoryEntry) -> some View {
        LabeledContent("Audio") {
            if let path = audioRevealPath(for: entry) {
                Button("Open in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text("Unavailable")
                    .foregroundStyle(.secondary)
            }
        }

        LabeledContent("File Size") {
            Text(byteCountFormatter.string(fromByteCount: entry.fileSizeBytes))
        }

        LabeledContent("Language") {
            Text(entry.language ?? "Unknown")
        }

        LabeledContent("Model") {
            Text(humanizedModelName(entry.modelName))
        }

        LabeledContent("Provider") {
            Text(humanizedProviderName(entry.providerName))
        }
    }

    private func transcriptVersionRow(_ version: TranscriptVersion) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(humanizedModelName(version.modelName))
                Text("\(formattedDate(version.createdAt)) • \(humanizedProviderName(version.providerName))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(version.characterCount) characters")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func audioRevealPath(for entry: HistoryEntry) -> String? {
        let candidates = [entry.preferredPlaybackPath, entry.workingFilePath, entry.originalFilePath]
        return candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0) }
    }

    /// Presents provider names without internal engine names. Legacy entries may
    /// have stored "WhisperKit Local"; surface them as the on-device label.
    private func humanizedProviderName(_ name: String?) -> String {
        guard let name, !name.isEmpty else { return "On-device" }
        if name.localizedCaseInsensitiveContains("whisperkit") {
            return "On-device (Whisper)"
        }
        return name
    }

    private func humanizedModelName(_ name: String?) -> String {
        guard let name, !name.isEmpty else { return "Not assigned" }
        return name.replacingOccurrences(of: "WhisperKit", with: "Whisper")
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
        if entry.modelName != nil {
            parts.append(humanizedModelName(entry.modelName))
        }
        if entry.providerName != nil {
            parts.append(humanizedProviderName(entry.providerName))
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
