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
    case storage

    public var id: String { rawValue }

    /// Every settings category is shown as its own always-visible row in the
    /// sidebar, like System Settings, so each page can be reached directly
    /// instead of being buried under Advanced or only reachable via search.
    public static let sidebarVisiblePanes: [SettingsPane] = [
        .general,
        .storage,
    ]

    public var title: String {
        switch self {
        case .general:
            "General"
        case .storage:
            "Storage"
        }
    }

    public var systemImage: String {
        switch self {
        case .general:
            "gearshape"
        case .storage:
            "internaldrive"
        }
    }

    public var subtitle: String {
        switch self {
        case .general:
            "App-wide behavior, permissions, and the voice input shortcut."
        case .storage:
            "Manage retained local history and audio files."
        }
    }

    /// Panes whose title, subtitle, or search tokens match the query.
    /// An empty or whitespace-only query returns every visible pane. Hidden panes
    /// (not in `sidebarVisiblePanes`) are never surfaced.
    public static func matching(query: String) -> [SettingsPane] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SettingsPane.sidebarVisiblePanes
        }

        return SettingsPane.sidebarVisiblePanes.filter { pane in
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
                "Voice input mode",
                "Transcription language",
                "Microphone",
                "Accessibility",
                "Insert transcript into active app",
                "Also copy transcript to clipboard",
                "Restore previous clipboard after insertion",
                "Show Transcriptor in menu bar",
                "Always show Dock icon",
                "Launch at login",
                "Global voice input shortcut",
                "Restore recommended shortcut",
            ]
        case .storage:
            [
                "Storage usage",
                "Clear History…",
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

        return SettingsPane.sidebarVisiblePanes.compactMap { pane in
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
            [
                "launch", "login", "defaults", "startup",
                "microphone", "audio", "recording", "input", "permissions", "accessibility",
                "shortcut", "hotkey", "keyboard", "global",
            ]
        case .storage:
            ["history", "storage", "usage", "delete", "clear"]
        }
    }
}
