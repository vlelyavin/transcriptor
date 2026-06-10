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

    public var subtitle: String {
        switch self {
        case .general:
            "App-wide behavior and launch defaults."
        case .recording:
            "Voice capture behavior, microphone access, and local recording defaults."
        case .keyboardShortcut:
            "Configure the global shortcut Transcriptor listens for while it is running."
        case .overlay:
            "Control the voice input overlay that appears during dictation."
        case .models:
            "Choose default transcription providers, local models, and automation behavior."
        case .storage:
            "Manage retained local history, audio files, and storage limits."
        case .cloudProviders:
            "Store API keys in Keychain and review cloud privacy controls."
        case .privacy:
            "Review what stays local, what requires permission, and what remains blocked."
        }
    }

    /// Panes whose title, subtitle, or search tokens match the query.
    /// An empty or whitespace-only query returns every pane.
    public static func matching(query: String) -> [SettingsPane] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SettingsPane.allCases
        }

        return SettingsPane.allCases.filter { pane in
            let haystack = ([pane.title, pane.subtitle] + pane.searchTokens).joined(separator: " ")
            return haystack.localizedCaseInsensitiveContains(trimmed)
        }
    }

    public var searchTokens: [String] {
        switch self {
        case .general:
            ["launch", "login", "defaults", "startup"]
        case .recording:
            ["microphone", "audio", "recording", "save", "input"]
        case .keyboardShortcut:
            ["shortcut", "hotkey", "keyboard", "global"]
        case .overlay:
            ["overlay", "indicator", "position", "done"]
        case .models:
            ["whisper", "provider", "auto-transcribe", "model"]
        case .storage:
            ["history", "storage", "cap", "prune", "delete"]
        case .cloudProviders:
            ["openai", "groq", "api", "keychain", "privacy"]
        case .privacy:
            ["accessibility", "microphone", "permissions", "local", "cloud"]
        }
    }
}
