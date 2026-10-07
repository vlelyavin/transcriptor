import Foundation

/// A transcription language choice. `code` is the ISO-639-1 code passed to
/// WhisperKit and to OpenAI-compatible APIs; an empty code means automatic
/// detection.
public struct TranscriptionLanguage: Identifiable, Hashable, Sendable {
    public let code: String
    public let title: String

    public var id: String { code }

    public static let choices: [TranscriptionLanguage] = [
        .init(code: "", title: "Detect automatically"),
        .init(code: "en", title: "English"),
        .init(code: "ru", title: "Russian"),
        .init(code: "uk", title: "Ukrainian"),
        .init(code: "de", title: "German"),
        .init(code: "fr", title: "French"),
        .init(code: "es", title: "Spanish"),
        .init(code: "it", title: "Italian"),
        .init(code: "pl", title: "Polish"),
        .init(code: "pt", title: "Portuguese"),
        .init(code: "tr", title: "Turkish"),
        .init(code: "zh", title: "Chinese"),
        .init(code: "ja", title: "Japanese"),
    ]
}
