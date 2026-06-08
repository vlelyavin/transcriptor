import Foundation

public enum FeatureAvailability: Equatable, Sendable {
    case planned(blocker: String)
    case unavailable(blocker: String)

    public var badgeLabel: String {
        switch self {
        case .planned:
            "Planned"
        case .unavailable:
            "Unavailable"
        }
    }

    public var blocker: String {
        switch self {
        case let .planned(blocker), let .unavailable(blocker):
            blocker
        }
    }
}
