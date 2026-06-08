import Foundation

public struct HistoryEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var createdAt: Date
    public var title: String
    public var transcriptPreview: String
    public var sourceDescription: String

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        title: String,
        transcriptPreview: String,
        sourceDescription: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.transcriptPreview = transcriptPreview
        self.sourceDescription = sourceDescription
    }
}

public struct HistoryStore: Equatable, Sendable {
    public var entries: [HistoryEntry]

    public init(entries: [HistoryEntry] = []) {
        self.entries = entries
    }
}
