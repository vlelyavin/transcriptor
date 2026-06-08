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

public struct HistoryEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var createdAt: Date
    public var title: String
    public var transcriptPreview: String
    public var transcriptText: String
    public var durationSeconds: Int
    public var characterCount: Int
    public var modelName: String
    public var sourceType: HistorySourceType

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        title: String,
        transcriptPreview: String,
        transcriptText: String,
        durationSeconds: Int,
        characterCount: Int,
        modelName: String,
        sourceType: HistorySourceType
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.transcriptPreview = transcriptPreview
        self.transcriptText = transcriptText
        self.durationSeconds = durationSeconds
        self.characterCount = characterCount
        self.modelName = modelName
        self.sourceType = sourceType
    }
}

public struct HistoryStore: Equatable, Sendable {
    public var entries: [HistoryEntry]

    public init(entries: [HistoryEntry] = []) {
        self.entries = entries
    }

    public static let mock = HistoryStore(
        entries: [
            HistoryEntry(
                createdAt: .now.addingTimeInterval(-1_200),
                title: "API doc reminder",
                transcriptPreview: "Remember to update the API docs before the next release and include the keyboard shortcut migration notes.",
                transcriptText: "Remember to update the API docs before the next release and include the keyboard shortcut migration notes. Also check whether the import flow still says beta in the onboarding copy.",
                durationSeconds: 42,
                characterCount: 178,
                modelName: "Whisper Tiny",
                sourceType: .dictation
            ),
            HistoryEntry(
                createdAt: .now.addingTimeInterval(-15_200),
                title: "Q3 planning notes",
                transcriptPreview: "Meeting notes: discussed Q3 roadmap, storage retention defaults, and whether model switching should stay one click away.",
                transcriptText: "Meeting notes: discussed Q3 roadmap, storage retention defaults, and whether model switching should stay one click away. Action items include validating the settings sidebar labels and clarifying cloud provider copy before alpha.",
                durationSeconds: 75,
                characterCount: 224,
                modelName: "Large V3 Turbo",
                sourceType: .dictation
            ),
            HistoryEntry(
                createdAt: .now.addingTimeInterval(-86_400),
                title: "Podcast clip import",
                transcriptPreview: "Quick reminder about the deployment checklist, release channel names, and keeping unavailable providers visibly disabled in the UI.",
                transcriptText: "Quick reminder about the deployment checklist, release channel names, and keeping unavailable providers visibly disabled in the UI. The history detail pane also needs explicit not implemented messaging for playback and export.",
                durationSeconds: 143,
                characterCount: 217,
                modelName: "OpenAI",
                sourceType: .importedAudio
            ),
            HistoryEntry(
                createdAt: .now.addingTimeInterval(-172_800),
                title: "Voice memo ideas",
                transcriptPreview: "Ideas for Sotto onboarding: emphasize local-first storage, import shortcuts, and model management without implying live transcription already works.",
                transcriptText: "Ideas for Sotto onboarding: emphasize local-first storage, import shortcuts, and model management without implying live transcription already works. Keep the language honest and default to native macOS interactions everywhere.",
                durationSeconds: 94,
                characterCount: 221,
                modelName: "Base (English)",
                sourceType: .importedAudio
            ),
        ]
    )
}
