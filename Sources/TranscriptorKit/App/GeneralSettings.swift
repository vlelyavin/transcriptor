import Foundation

public struct GeneralSettings: Equatable, Sendable {
    public var launchAtLoginEnabled: Bool
    public var showMenuBarIcon: Bool
    public var insertTranscriptIntoActiveApp: Bool
    public var alsoCopyTranscriptToClipboard: Bool
    public var restoreClipboardAfterInsertion: Bool
    /// Keep a Dock icon even when no Transcriptor window is open. Off by
    /// default: Transcriptor is a menu bar app and stays menu-bar-only even
    /// while its window is open unless this is on.
    public var showDockIcon: Bool
    /// Show a Dock icon for the duration of a recording even when
    /// `showDockIcon` is off — a visible "the microphone is live" reminder.
    public var showDockIconWhileRecording: Bool

    public init(
        launchAtLoginEnabled: Bool = false,
        showMenuBarIcon: Bool = true,
        insertTranscriptIntoActiveApp: Bool = true,
        alsoCopyTranscriptToClipboard: Bool = false,
        restoreClipboardAfterInsertion: Bool = true,
        showDockIcon: Bool = false,
        showDockIconWhileRecording: Bool = false
    ) {
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.showMenuBarIcon = showMenuBarIcon
        self.insertTranscriptIntoActiveApp = insertTranscriptIntoActiveApp
        self.alsoCopyTranscriptToClipboard = alsoCopyTranscriptToClipboard
        self.restoreClipboardAfterInsertion = restoreClipboardAfterInsertion
        self.showDockIcon = showDockIcon
        self.showDockIconWhileRecording = showDockIconWhileRecording
    }
}
