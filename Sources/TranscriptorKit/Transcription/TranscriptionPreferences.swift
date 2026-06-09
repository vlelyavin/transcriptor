import Foundation

public struct TranscriptionPreferences: Equatable, Sendable {
    public var selectedModelID: String
    public var autoTranscribeAfterCapture: Bool
    public var preferredLocalProviderID: String
    public var preferredProviderID: String

    public init(
        selectedModelID: String = "whisper-large-v3-turbo",
        autoTranscribeAfterCapture: Bool = false,
        preferredLocalProviderID: String = "whisperkit-local",
        preferredProviderID: String = "whisperkit-local"
    ) {
        self.selectedModelID = selectedModelID
        self.autoTranscribeAfterCapture = autoTranscribeAfterCapture
        self.preferredLocalProviderID = preferredLocalProviderID
        self.preferredProviderID = preferredProviderID
    }
}
