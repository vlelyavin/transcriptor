import Foundation

public enum HistoryFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all
    case dictations
    case imports

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all:
            "All"
        case .dictations:
            "Dictations"
        case .imports:
            "Imports"
        }
    }
}
