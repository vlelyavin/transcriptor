import SwiftUI

public struct HistoryView: View {
    @State private var searchText = ""
    @State private var selectedFilter: HistoryFilter = .all
    @State private var selectedEntryID: HistoryEntry.ID?

    private let historyStore: HistoryStore

    public init(historyStore: HistoryStore) {
        self.historyStore = historyStore
        _selectedEntryID = State(initialValue: historyStore.entries.first?.id)
    }

    public var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 0) {
                Picker("Source", selection: $selectedFilter) {
                    ForEach(HistoryFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Group {
                    if filteredEntries.isEmpty {
                        ContentUnavailableView(
                            "No Matching Transcripts",
                            systemImage: "text.quote",
                            description: Text("Try a different filter or search term. Playback, copy, export, and re-transcription remain mocked in this build.")
                        )
                    } else {
                        List(filteredEntries, selection: $selectedEntryID) { entry in
                            historyRow(entry)
                                .tag(entry.id)
                        }
                        .listStyle(.inset)
                    }
                }
                .frame(minWidth: 420)
                .searchable(text: $searchText, prompt: "Search transcripts")
            }

            detailPane
                .frame(minWidth: 340, maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
        }
        .navigationTitle("History")
    }

    private var detailPane: some View {
        Group {
            if let entry = selectedEntry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(entry.title)
                                    .font(.largeTitle.weight(.semibold))

                                Text("\(formattedDate(entry.createdAt)) • \(durationLabel(entry.durationSeconds)) • \(entry.characterCount) characters")
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 8) {
                                    detailTag(entry.sourceType.title)
                                    detailTag(entry.modelName)
                                }
                            }

                            Spacer()
                        }

                        HStack(spacing: 10) {
                            Button("Copy Transcript") {}
                                .disabled(true)
                            Button("Export .txt") {}
                                .disabled(true)
                            Button("Re-transcribe") {}
                                .disabled(true)
                            Button("Playback") {}
                                .disabled(true)
                        }

                        UnavailableActionBanner(
                            message: "Copy, export, re-transcribe, and playback controls are intentionally disabled until the backend exists."
                        )

                        Divider()

                        Text(entry.transcriptText)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(24)
                }
            } else {
                ContentUnavailableView(
                    "Select a Transcript",
                    systemImage: "sidebar.right",
                    description: Text("Choose a history item to inspect transcript details and future actions.")
                )
            }
        }
    }

    private var filteredEntries: [HistoryEntry] {
        historyStore.entries.filter { entry in
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

        return entry.title.localizedCaseInsensitiveContains(searchText)
            || entry.transcriptPreview.localizedCaseInsensitiveContains(searchText)
            || entry.transcriptText.localizedCaseInsensitiveContains(searchText)
    }

    private func historyRow(_ entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formattedDate(entry.createdAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                detailTag(entry.modelName)
            }

            Text(entry.transcriptPreview)
                .font(.headline)
                .lineLimit(2)

            HStack(spacing: 12) {
                metadataLabel(systemImage: "clock", text: durationLabel(entry.durationSeconds))
                metadataLabel(systemImage: "textformat.abc", text: "\(entry.characterCount) chars")
                metadataLabel(systemImage: "tray.full", text: entry.sourceType.title)
            }
        }
        .padding(.vertical, 6)
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
}

#if DEBUG
struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView(historyStore: .mock)
            .frame(width: 1280, height: 860)
    }
}
#endif
