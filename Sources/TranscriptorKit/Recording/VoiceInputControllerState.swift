import Foundation

public enum VoiceInputControllerState: String, Equatable, Sendable {
    case idle
    case requestingPermission
    case recording
    case stopping
    case pendingTranscription
    case failed
}
