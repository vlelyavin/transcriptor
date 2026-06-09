import Foundation

public enum MicrophonePermissionStatus: String, Equatable, Sendable {
    case undetermined
    case granted
    case denied
    case restricted
}
