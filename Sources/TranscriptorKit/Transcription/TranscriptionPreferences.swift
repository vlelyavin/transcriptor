import Foundation

public struct TranscriptionPreferences: Equatable, Sendable {
    public var selectedModelID: String
    public var autoTranscribeAfterCapture: Bool
    public var preferredLocalProviderID: String
    public var preferredProviderID: String
    /// ISO-639-1 code passed to every transcription engine, or "" for
    /// automatic detection.
    public var transcriptionLanguage: String

    public init(
        selectedModelID: String = "whisper-large-v3-turbo",
        autoTranscribeAfterCapture: Bool = false,
        preferredLocalProviderID: String = "whisperkit-local",
        preferredProviderID: String = "whisperkit-local",
        transcriptionLanguage: String = ""
    ) {
        self.selectedModelID = selectedModelID
        self.autoTranscribeAfterCapture = autoTranscribeAfterCapture
        self.preferredLocalProviderID = preferredLocalProviderID
        self.preferredProviderID = preferredProviderID
        self.transcriptionLanguage = transcriptionLanguage
    }

    /// The language hint for engines, `nil` when auto-detecting.
    public var languageHint: String? {
        let trimmed = transcriptionLanguage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }
}
