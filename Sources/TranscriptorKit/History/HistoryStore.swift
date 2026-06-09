import Foundation

public enum HistorySourceType: String, CaseIterable, Identifiable, Sendable {
    case dictation
    case importedAudio

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dictation:
            "Dictation"
        case .importedAudio:
            "Import"
        }
    }
}

public enum HistoryTranscriptionStatus: String, CaseIterable, Identifiable, Sendable {
    case pending
    case transcribing
    case completed
    case failed

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .pending:
            "Pending transcription"
        case .transcribing:
            "Transcribing"
        case .completed:
            "Completed"
        case .failed:
            "Failed"
        }
    }
}

public struct HistoryEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var sourceType: HistorySourceType
    public var displayName: String
    public var originalFilePath: String?
    public var workingFilePath: String?
    public var transcriptText: String
    public var transcriptPreview: String
    public var transcriptVersions: [TranscriptVersion]
    public var createdAt: Date
    public var lastTranscriptionAt: Date?
    public var durationSeconds: Int
    public var characterCount: Int
    public var modelID: String?
    public var modelName: String?
    public var providerID: String?
    public var providerName: String?
    public var language: String?
    public var fileSizeBytes: Int64
    public var transcriptionStatus: HistoryTranscriptionStatus
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        sourceType: HistorySourceType,
        displayName: String,
        originalFilePath: String?,
        workingFilePath: String?,
        transcriptText: String,
        transcriptPreview: String,
        transcriptVersions: [TranscriptVersion] = [],
        createdAt: Date = .now,
        lastTranscriptionAt: Date? = nil,
        durationSeconds: Int,
        characterCount: Int,
        modelID: String? = nil,
        modelName: String? = nil,
        providerID: String? = nil,
        providerName: String? = nil,
        language: String? = nil,
        fileSizeBytes: Int64,
        transcriptionStatus: HistoryTranscriptionStatus,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.sourceType = sourceType
        self.displayName = displayName
        self.originalFilePath = originalFilePath
        self.workingFilePath = workingFilePath
        self.transcriptText = transcriptText
        self.transcriptPreview = transcriptPreview
        self.transcriptVersions = transcriptVersions
        self.createdAt = createdAt
        self.lastTranscriptionAt = lastTranscriptionAt
        self.durationSeconds = durationSeconds
        self.characterCount = characterCount
        self.modelID = modelID
        self.modelName = modelName
        self.providerID = providerID
        self.providerName = providerName
        self.language = language
        self.fileSizeBytes = fileSizeBytes
        self.transcriptionStatus = transcriptionStatus
        self.errorMessage = errorMessage
    }

    public var preferredPlaybackPath: String? {
        if let originalFilePath,
           FileManager.default.fileExists(atPath: originalFilePath) {
            return originalFilePath
        }

        if let workingFilePath,
           FileManager.default.fileExists(atPath: workingFilePath) {
            return workingFilePath
        }

        return originalFilePath ?? workingFilePath
    }

    public var searchableText: String {
        [
            displayName,
            transcriptPreview,
            transcriptText,
            transcriptVersions.map(\.transcriptText).joined(separator: "\n"),
            modelName ?? "",
            providerName ?? "",
            originalFileName ?? ""
        ]
        .joined(separator: "\n")
    }

    public var originalFileName: String? {
        guard let originalFilePath else {
            return nil
        }

        return URL(fileURLWithPath: originalFilePath).lastPathComponent
    }

    public var canCopyTranscript: Bool {
        transcriptionStatus == .completed && !transcriptText.isEmpty
    }

    public var canExportTranscript: Bool {
        canCopyTranscript
    }

    public var storageBytes: Int64 {
        fileSizeBytes
    }

    public var latestTranscriptVersion: TranscriptVersion? {
        transcriptVersions.sorted(by: { $0.createdAt > $1.createdAt }).first
    }

    public var hasTranscriptHistory: Bool {
        !transcriptVersions.isEmpty || !transcriptText.isEmpty
    }

    public var hasCompletedTranscript: Bool {
        !transcriptText.isEmpty && (transcriptionStatus == .completed || !transcriptVersions.isEmpty)
    }

    public mutating func appendTranscriptVersion(
        _ version: TranscriptVersion,
        replacingCurrentTranscript: Bool = true
    ) {
        if hasCompletedTranscript && transcriptVersions.isEmpty {
            transcriptVersions.append(
                TranscriptVersion(
                    createdAt: lastTranscriptionAt ?? createdAt,
                    transcriptText: transcriptText,
                    transcriptPreview: transcriptPreview,
                    characterCount: characterCount,
                    modelID: modelID,
                    modelName: modelName,
                    providerID: providerID,
                    providerName: providerName,
                    language: language
                )
            )
        }

        transcriptVersions.append(version)
        transcriptVersions.sort(by: { $0.createdAt > $1.createdAt })

        if replacingCurrentTranscript {
            transcriptText = version.transcriptText
            transcriptPreview = version.transcriptPreview
            characterCount = version.characterCount
            modelID = version.modelID
            modelName = version.modelName
            providerID = version.providerID
            providerName = version.providerName
            language = version.language
            lastTranscriptionAt = version.createdAt
        }
    }

    public static func pendingRecording(
        recording: RecordedAudioAsset,
        modelID: String?,
        modelName: String?
    ) -> HistoryEntry {
        let fileName = recording.url.lastPathComponent
        return HistoryEntry(
            sourceType: .dictation,
            displayName: fileName,
            originalFilePath: recording.url.path,
            workingFilePath: recording.url.path,
            transcriptText: "",
            transcriptPreview: "Saved locally as \(fileName). Waiting for transcription.",
            createdAt: recording.createdAt,
            durationSeconds: recording.durationSeconds,
            characterCount: 0,
            modelID: modelID,
            modelName: modelName,
            fileSizeBytes: recording.fileSizeBytes,
            transcriptionStatus: .pending
        )
    }

    public static let previewEntries: [HistoryEntry] = [
        HistoryEntry(
            sourceType: .dictation,
            displayName: "api-doc-reminder.wav",
            originalFilePath: nil,
            workingFilePath: nil,
            transcriptText: "Remember to update the API docs before the next release and include the keyboard shortcut migration notes.",
            transcriptPreview: "Remember to update the API docs before the next release and include the keyboard shortcut migration notes.",
            transcriptVersions: [
                TranscriptVersion(
                    createdAt: .now.addingTimeInterval(-1_100),
                    transcriptText: "Remember to update the API docs before the next release and include the keyboard shortcut migration notes.",
                    transcriptPreview: "Remember to update the API docs before the next release and include the keyboard shortcut migration notes.",
                    characterCount: 106,
                    modelID: "whisper-tiny",
                    modelName: "Tiny",
                    providerID: "whisperkit-local",
                    providerName: "WhisperKit Local",
                    language: "en"
                )
            ],
            createdAt: .now.addingTimeInterval(-1_200),
            lastTranscriptionAt: .now.addingTimeInterval(-1_100),
            durationSeconds: 42,
            characterCount: 106,
            modelID: "whisper-tiny",
            modelName: "Tiny",
            providerID: "whisperkit-local",
            providerName: "WhisperKit Local",
            language: "en",
            fileSizeBytes: 42_000,
            transcriptionStatus: .completed
        ),
        HistoryEntry(
            sourceType: .importedAudio,
            displayName: "podcast-clip.m4a",
            originalFilePath: nil,
            workingFilePath: nil,
            transcriptText: "",
            transcriptPreview: "Imported audio is ready and waiting for a future transcription pass.",
            createdAt: .now.addingTimeInterval(-86_400),
            durationSeconds: 143,
            characterCount: 0,
            modelID: "whisper-large-v3-turbo",
            modelName: "Large V3 Turbo",
            providerID: "whisperkit-local",
            providerName: "WhisperKit Local",
            language: nil,
            fileSizeBytes: 2_400_000,
            transcriptionStatus: .pending
        ),
        HistoryEntry(
            sourceType: .importedAudio,
            displayName: "meeting-note.webm",
            originalFilePath: nil,
            workingFilePath: nil,
            transcriptText: "",
            transcriptPreview: "Import failed because WebM conversion is not available yet in this build.",
            createdAt: .now.addingTimeInterval(-172_800),
            durationSeconds: 0,
            characterCount: 0,
            modelID: nil,
            modelName: nil,
            providerID: nil,
            providerName: nil,
            language: nil,
            fileSizeBytes: 1_800_000,
            transcriptionStatus: .failed,
            errorMessage: "WebM import is blocked because this build does not yet include a reliable decoder/transcoder for WebM audio."
        ),
    ]
}

public struct HistoryStore: Equatable, Sendable {
    public var entries: [HistoryEntry]

    public init(entries: [HistoryEntry] = []) {
        self.entries = entries
    }

    public mutating func replace(with entries: [HistoryEntry]) {
        self.entries = entries
    }

    public static let preview = HistoryStore(entries: HistoryEntry.previewEntries)
}
