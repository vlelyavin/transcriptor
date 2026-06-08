import Foundation

public enum SettingsPane: String, CaseIterable, Identifiable, Hashable, Sendable {
    case general
    case recording
    case keyboardShortcut
    case overlay
    case models
    case storage
    case cloudProviders
    case privacy

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .general:
            "General"
        case .recording:
            "Recording"
        case .keyboardShortcut:
            "Keyboard Shortcut"
        case .overlay:
            "Overlay"
        case .models:
            "Models"
        case .storage:
            "Storage"
        case .cloudProviders:
            "Cloud Providers"
        case .privacy:
            "Privacy"
        }
    }

    public var systemImage: String {
        switch self {
        case .general:
            "gearshape"
        case .recording:
            "mic"
        case .keyboardShortcut:
            "keyboard"
        case .overlay:
            "rectangle.inset.filled.and.person.filled"
        case .models:
            "cpu"
        case .storage:
            "internaldrive"
        case .cloudProviders:
            "cloud"
        case .privacy:
            "hand.raised"
        }
    }
}
