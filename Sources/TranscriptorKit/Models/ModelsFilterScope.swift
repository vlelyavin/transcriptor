import Foundation

/// The Local / Remote scope filter on the Models screen. Used by the Models
/// page itself and by onboarding shortcuts that jump straight to remote
/// providers.
public enum ModelsFilterScope: String, CaseIterable, Identifiable, Sendable {
    case all
    case local
    case remote

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all:
            "All"
        case .local:
            "Local"
        case .remote:
            "Remote"
        }
    }
}
