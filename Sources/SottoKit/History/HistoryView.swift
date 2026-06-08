import SwiftUI

public struct HistoryView: View {
    @State private var searchText = ""
    private let historyStore: HistoryStore

    public init(historyStore: HistoryStore) {
        self.historyStore = historyStore
    }

    public var body: some View {
        List {
            Section {
                if historyStore.entries.isEmpty {
                    ContentUnavailableView(
                        "No Transcripts Yet",
                        systemImage: "text.quote",
                        description: Text("Saved transcript history, search, playback, and re-transcription will appear here once recording and transcription are implemented.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    ForEach(filteredEntries) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.title)
                                .font(.headline)

                            Text(entry.transcriptPreview)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)

                            Text(entry.sourceDescription)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Transcript History")
            } footer: {
                Text("Playback, copy, export, and re-transcribe actions are planned but not implemented in this scaffold.")
            }
        }
        .searchable(text: $searchText, prompt: "Search transcripts")
        .navigationTitle("History")
    }

    private var filteredEntries: [HistoryEntry] {
        guard !searchText.isEmpty else {
            return historyStore.entries
        }

        return historyStore.entries.filter { entry in
            entry.title.localizedCaseInsensitiveContains(searchText)
                || entry.transcriptPreview.localizedCaseInsensitiveContains(searchText)
        }
    }
}
