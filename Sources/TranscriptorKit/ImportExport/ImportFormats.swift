import Foundation

public enum SupportedImportFormat: String, CaseIterable, Identifiable, Sendable {
    case mp3
    case m4a
    case wav
    case ogg
    case oga
    case opus

    public var id: String { rawValue }

    public var fileExtensionLabel: String {
        ".\(rawValue)"
    }

    /// Ogg-container audio (Telegram voice messages and similar) is decoded by
    /// CoreAudio but converted to WAV at import time so every transcription
    /// provider consumes the same working format.
    public var requiresWAVConversion: Bool {
        switch self {
        case .ogg, .oga, .opus:
            true
        case .mp3, .m4a, .wav:
            false
        }
    }
}
