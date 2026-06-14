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
    case storage
    case privacy
    case advanced

    public var id: String { rawValue }

    /// Every settings category is shown as its own always-visible row in the
    /// sidebar, like System Settings, so each page can be reached directly
    /// instead of being buried under Advanced or only reachable via search.
    public static let sidebarVisiblePanes: [SettingsPane] = [
        .general,
        .recording,
        .keyboardShortcut,
        .overlay,
        .storage,
        .privacy,
        .advanced,
    ]

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
        case .storage:
            "Storage"
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
        case .storage:
            "internaldrive"
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
        case .storage:
            "Manage retained local history, audio files, and storage limits."
        case .privacy:
            "Review what stays local, what requires permission, and what remains blocked."
        case .advanced:
            "Diagnostics and less-common options."
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
        case .storage:
            [
                "History storage limit",
                "Auto-delete oldest history when over limit",
                "Exclude downloaded model files from cap",
                "Storage usage",
            ]
        case .privacy:
            [
                "Local transcription privacy",
                "Cloud transcription privacy",
                "Model download sources",
            ]
        case .advanced:
            [
                "Last insertion attempt",
                "Insertion diagnostics",
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
        case .storage:
            ["history", "storage", "cap", "prune", "delete"]
        case .privacy:
            ["accessibility", "microphone", "permissions", "local", "cloud"]
        case .advanced:
            ["advanced", "more", "extra", "diagnostics", "options", "insertion"]
        }
    }
}
