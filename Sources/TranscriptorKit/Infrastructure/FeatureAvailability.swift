import Foundation

public enum FeatureAvailability: Equatable, Sendable {
    case available(note: String)
    case downloaded(note: String)
    case planned(blocker: String)
    case unavailable(blocker: String)

    public var badgeLabel: String {
        switch self {
        case .available:
            "Available"
        case .downloaded:
            "Downloaded"
        case .planned:
            "Planned"
        case .unavailable:
            "Unavailable"
        }
    }

    public var message: String {
        switch self {
        case let .available(note), let .downloaded(note):
            note
        case let .planned(blocker), let .unavailable(blocker):
            blocker
        }
    }
}
