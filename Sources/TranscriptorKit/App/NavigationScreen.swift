import Foundation

public enum NavigationScreen: String, CaseIterable, Identifiable, Hashable {
    case overview
    case history
    case importAudio
    case models
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .overview:
            "Overview"
        case .history:
            "History"
        case .importAudio:
            "Import Audio"
        case .models:
            "Models"
        case .settings:
            "Settings"
        }
    }

    public var systemImage: String {
        switch self {
        case .overview:
            "waveform.circle"
        case .history:
            "clock.arrow.circlepath"
        case .importAudio:
            "square.and.arrow.down"
        case .models:
            "cube.transparent"
        case .settings:
            "gearshape"
        }
    }
}
