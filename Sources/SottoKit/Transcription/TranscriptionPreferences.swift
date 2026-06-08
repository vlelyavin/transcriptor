import Foundation

public struct TranscriptionPreferences: Equatable, Sendable {
    public var selectedModelID: String

    public init(
        selectedModelID: String = "whisper-large-v3-turbo"
    ) {
        self.selectedModelID = selectedModelID
    }
}
