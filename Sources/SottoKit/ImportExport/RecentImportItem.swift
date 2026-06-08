import Foundation

public struct RecentImportItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var fileName: String
    public var format: SupportedImportFormat
    public var importedAt: Date
    public var durationSeconds: Int

    public init(
        id: UUID = UUID(),
        fileName: String,
        format: SupportedImportFormat,
        importedAt: Date,
        durationSeconds: Int
    ) {
        self.id = id
        self.fileName = fileName
        self.format = format
        self.importedAt = importedAt
        self.durationSeconds = durationSeconds
    }

    public static let mockItems: [RecentImportItem] = [
        RecentImportItem(
            fileName: "team-standup-dec4.m4a",
            format: .m4a,
            importedAt: .now.addingTimeInterval(-4_300),
            durationSeconds: 154
        ),
        RecentImportItem(
            fileName: "voice-memo-ideas.mp3",
            format: .mp3,
            importedAt: .now.addingTimeInterval(-11_000),
            durationSeconds: 45
        ),
        RecentImportItem(
            fileName: "release-qa-notes.wav",
            format: .wav,
            importedAt: .now.addingTimeInterval(-86_400),
            durationSeconds: 187
        ),
    ]
}
