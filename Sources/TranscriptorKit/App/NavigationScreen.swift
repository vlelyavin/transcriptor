import Foundation

public enum NavigationScreen: String, CaseIterable, Identifiable, Hashable {
    case overview
    case history
    case importAudio
    case models

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
        }
    }

    public var systemImage: String {
        switch self {
        case .overview:
            "waveform"
        case .history:
            "clock.arrow.circlepath"
        case .importAudio:
            "square.and.arrow.down.fill"
        case .models:
            "cpu.fill"
        }
    }
}
