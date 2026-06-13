import Foundation

/// A sidebar-search result: the pane that matched plus the individual
/// settings inside it that matched the query.
public struct SettingsSearchResult: Hashable, Identifiable, Sendable {
    public let pane: SettingsPane
    public let matchedSettingTitles: [String]

    public var id: String { pane.id }

    public init(pane: SettingsPane, matchedSettingTitles: [String]) {
        self.pane = pane
        self.matchedSettingTitles = matchedSettingTitles
    }
}

public enum SettingsPane: String, CaseIterable, Identifiable, Hashable, Sendable {
    case general
    case recording
    case keyboardShortcut
    case overlay
    case models
    case storage
    case cloudProviders
    case privacy
    case advanced

    public var id: String { rawValue }

    /// The categories shown as always-visible rows in the sidebar. Everything
    /// else is reachable through Advanced, Overview deep links, or search.
    public static let sidebarVisiblePanes: [SettingsPane] = [.general, .keyboardShortcut, .advanced]

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
        case .advanced:
            "Advanced"
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
        case .advanced:
            "slider.horizontal.3"
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
        case .advanced:
            "Less-common options for recording, overlay, transcription, storage, providers, and privacy."
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

    /// User-visible setting titles inside this pane, used by sidebar search so
    /// results can point at the individual setting (like System Settings).
    public var settingTitles: [String] {
        switch self {
        case .general:
            [
                "Show Transcriptor in menu bar",
                "Launch at login",
                "Login items status",
            ]
        case .recording:
            [
                "Voice input mode",
                "Save original audio",
                "Microphone permission",
                "Insert transcript into active app",
                "Also copy transcript to clipboard",
                "Restore previous clipboard after insertion",
            ]
        case .keyboardShortcut:
            [
                "Global voice input shortcut",
                "Restore recommended shortcut",
                "Menu shortcuts",
            ]
        case .overlay:
            [
                "Show recording overlay",
                "Use non-activating overlay",
                "Show live audio indicator",
                "Overlay position",
            ]
        case .models:
            [
                "Preferred transcription provider",
                "Preferred local provider",
                "Default local model",
                "Auto-transcribe after recording or import",
            ]
        case .storage:
            [
                "History storage limit",
                "Auto-delete oldest history when over limit",
                "Exclude downloaded model files from cap",
                "Storage usage",
            ]
        case .cloudProviders:
            [
                "OpenAI API key",
                "OpenAI model ID",
                "Groq API key",
                "Groq model ID",
                "Cloud privacy consent",
            ]
        case .privacy:
            [
                "Local transcription privacy",
                "Cloud transcription privacy",
                "Model download sources",
            ]
        case .advanced:
            [
                "Microphone and audio",
                "Overlay options",
                "Transcription providers",
                "Default local model",
                "Storage limit",
                "API providers",
                "Privacy summary",
            ]
        }
    }

    /// One search result per pane: whether the pane itself matched, plus the
    /// individual settings inside it that matched.
    public static func searchResults(matching query: String) -> [SettingsSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return []
        }

        return SettingsPane.allCases.compactMap { pane in
            let paneHaystack = ([pane.title, pane.subtitle] + pane.searchTokens).joined(separator: " ")
            let paneMatches = paneHaystack.localizedCaseInsensitiveContains(trimmed)
            let matchedSettings = pane.settingTitles.filter {
                $0.localizedCaseInsensitiveContains(trimmed)
            }

            guard paneMatches || !matchedSettings.isEmpty else {
                return nil
            }

            return SettingsSearchResult(pane: pane, matchedSettingTitles: matchedSettings)
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
        case .advanced:
            ["advanced", "more", "extra", "diagnostics", "options"]
        }
    }
}
