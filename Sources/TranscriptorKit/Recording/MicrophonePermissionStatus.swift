import Foundation

public enum MicrophonePermissionStatus: String, Equatable, Sendable {
    case undetermined
    case granted
    case denied
    case restricted

    /// The status label shown in Settings — keeps the same consistent
    /// capitalization System Settings uses.
    public var title: String {
        switch self {
        case .undetermined:
            "Not Determined"
        case .granted:
            "Granted"
        case .denied:
            "Denied"
        case .restricted:
            "Restricted"
        }
    }
}
