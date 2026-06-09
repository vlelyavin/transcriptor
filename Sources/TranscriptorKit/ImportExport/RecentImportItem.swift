import Foundation

public struct RecentImportItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var fileName: String
    public var format: SupportedImportFormat
    public var importedAt: Date
    public var durationSeconds: Int
    public var status: HistoryTranscriptionStatus

    public init(
        id: UUID = UUID(),
        fileName: String,
        format: SupportedImportFormat,
        importedAt: Date,
        durationSeconds: Int,
        status: HistoryTranscriptionStatus
    ) {
        self.id = id
        self.fileName = fileName
        self.format = format
        self.importedAt = importedAt
        self.durationSeconds = durationSeconds
        self.status = status
    }

    public init?(historyEntry: HistoryEntry) {
        guard historyEntry.sourceType == .importedAudio else {
            return nil
        }

        let fileName = historyEntry.originalFileName ?? historyEntry.displayName
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        guard let format = SupportedImportFormat(rawValue: fileExtension) else {
            return nil
        }

        self.init(
            id: historyEntry.id,
            fileName: fileName,
            format: format,
            importedAt: historyEntry.createdAt,
            durationSeconds: historyEntry.durationSeconds,
            status: historyEntry.transcriptionStatus
        )
    }

    public static let previewItems: [RecentImportItem] = [
        RecentImportItem(
            fileName: "team-standup-dec4.m4a",
            format: .m4a,
            importedAt: .now.addingTimeInterval(-4_300),
            durationSeconds: 154,
            status: .pending
        ),
        RecentImportItem(
            fileName: "voice-memo-ideas.mp3",
            format: .mp3,
            importedAt: .now.addingTimeInterval(-11_000),
            durationSeconds: 45,
            status: .pending
        ),
        RecentImportItem(
            fileName: "release-qa-notes.wav",
            format: .wav,
            importedAt: .now.addingTimeInterval(-86_400),
            durationSeconds: 187,
            status: .completed
        ),
    ]
}
