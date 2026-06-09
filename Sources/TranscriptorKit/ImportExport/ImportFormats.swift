import Foundation

public enum SupportedImportFormat: String, CaseIterable, Identifiable, Sendable {
    case mp3
    case m4a
    case wav
    case webm

    public var id: String { rawValue }

    public var fileExtensionLabel: String {
        ".\(rawValue)"
    }
}
