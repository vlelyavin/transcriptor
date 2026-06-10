import Foundation

/// One selectable row in the main window sidebar: either an app screen or a
/// settings pane. Settings live in the main window, like System Settings.
public enum SidebarItem: Hashable {
    case screen(NavigationScreen)
    case settings(SettingsPane)
}

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
