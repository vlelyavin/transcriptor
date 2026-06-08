import Foundation
import SwiftData

@Model
final class PersistedHistoryRecord {
    @Attribute(.unique) var id: UUID
    var sourceTypeRawValue: String
    var displayName: String
    var originalFilePath: String?
    var workingFilePath: String?
    var transcriptText: String
    var transcriptPreview: String
    var transcriptVersionsData: Data?
    var createdAt: Date
    var lastTranscriptionAt: Date?
    var durationSeconds: Int
    var characterCount: Int
    var modelID: String?
    var modelName: String?
    var providerID: String?
    var providerName: String?
    var language: String?
    var fileSizeBytes: Int64
    var transcriptionStatusRawValue: String
    var errorMessage: String?

    init(entry: HistoryEntry) {
        id = entry.id
        sourceTypeRawValue = entry.sourceType.rawValue
        displayName = entry.displayName
        originalFilePath = entry.originalFilePath
        workingFilePath = entry.workingFilePath
        transcriptText = entry.transcriptText
        transcriptPreview = entry.transcriptPreview
        transcriptVersionsData = Self.encodeVersions(entry.transcriptVersions)
        createdAt = entry.createdAt
        lastTranscriptionAt = entry.lastTranscriptionAt
        durationSeconds = entry.durationSeconds
        characterCount = entry.characterCount
        modelID = entry.modelID
        modelName = entry.modelName
        providerID = entry.providerID
        providerName = entry.providerName
        language = entry.language
        fileSizeBytes = entry.fileSizeBytes
        transcriptionStatusRawValue = entry.transcriptionStatus.rawValue
        errorMessage = entry.errorMessage
    }

    func update(from entry: HistoryEntry) {
        sourceTypeRawValue = entry.sourceType.rawValue
        displayName = entry.displayName
        originalFilePath = entry.originalFilePath
        workingFilePath = entry.workingFilePath
        transcriptText = entry.transcriptText
        transcriptPreview = entry.transcriptPreview
        transcriptVersionsData = Self.encodeVersions(entry.transcriptVersions)
        createdAt = entry.createdAt
        lastTranscriptionAt = entry.lastTranscriptionAt
        durationSeconds = entry.durationSeconds
        characterCount = entry.characterCount
        modelID = entry.modelID
        modelName = entry.modelName
        providerID = entry.providerID
        providerName = entry.providerName
        language = entry.language
        fileSizeBytes = entry.fileSizeBytes
        transcriptionStatusRawValue = entry.transcriptionStatus.rawValue
        errorMessage = entry.errorMessage
    }

    var entry: HistoryEntry {
        HistoryEntry(
            id: id,
            sourceType: HistorySourceType(rawValue: sourceTypeRawValue) ?? .dictation,
            displayName: displayName,
            originalFilePath: originalFilePath,
            workingFilePath: workingFilePath,
            transcriptText: transcriptText,
            transcriptPreview: transcriptPreview,
            transcriptVersions: Self.decodeVersions(transcriptVersionsData),
            createdAt: createdAt,
            lastTranscriptionAt: lastTranscriptionAt,
            durationSeconds: durationSeconds,
            characterCount: characterCount,
            modelID: modelID,
            modelName: modelName,
            providerID: providerID,
            providerName: providerName,
            language: language,
            fileSizeBytes: fileSizeBytes,
            transcriptionStatus: HistoryTranscriptionStatus(rawValue: transcriptionStatusRawValue) ?? .pending,
            errorMessage: errorMessage
        )
    }

    private static func encodeVersions(_ versions: [TranscriptVersion]) -> Data? {
        guard !versions.isEmpty else {
            return nil
        }

        return try? JSONEncoder().encode(versions)
    }

    private static func decodeVersions(_ data: Data?) -> [TranscriptVersion] {
        guard let data else {
            return []
        }

        return (try? JSONDecoder().decode([TranscriptVersion].self, from: data)) ?? []
    }
}
