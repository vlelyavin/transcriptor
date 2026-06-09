import Foundation

public enum TranscriptExportError: Error, LocalizedError {
    case transcriptUnavailable

    public var errorDescription: String? {
        switch self {
        case .transcriptUnavailable:
            "Only completed transcripts can be copied or exported."
        }
    }
}

public struct TranscriptExportService {
    public init() {}

    public func formattedText(for entry: HistoryEntry) throws -> String {
        guard entry.canExportTranscript else {
            throw TranscriptExportError.transcriptUnavailable
        }

        let lines = [
            "Transcriptor Transcript",
            "",
            "Title: \(entry.displayName)",
            "Created: \(entry.createdAt.ISO8601Format())",
            "Source: \(entry.sourceType.title)",
            "Duration: \(entry.durationSeconds) seconds",
            "Model: \(entry.modelName ?? "Unknown")",
            "Provider: \(entry.providerName ?? "Local")",
            "Language: \(entry.language ?? "Unknown")",
            "",
            entry.transcriptText
        ]

        return lines.joined(separator: "\n")
    }

    public func export(entry: HistoryEntry, to destinationURL: URL) throws {
        let text = try formattedText(for: entry)
        try text.write(to: destinationURL, atomically: true, encoding: .utf8)
    }
}
