import Foundation

public struct GeneralSettings: Equatable, Sendable {
    public var launchAtLoginEnabled: Bool
    public var showMenuBarIcon: Bool
    public var insertTranscriptIntoActiveApp: Bool
    public var alsoCopyTranscriptToClipboard: Bool
    public var restoreClipboardAfterInsertion: Bool
    /// Keep a Dock icon even when no Transcriptor window is open. Off by
    /// default: Transcriptor is a menu bar app and only shows a Dock icon while
    /// its window is open.
    public var showDockIcon: Bool

    public init(
        launchAtLoginEnabled: Bool = false,
        showMenuBarIcon: Bool = true,
        insertTranscriptIntoActiveApp: Bool = true,
        alsoCopyTranscriptToClipboard: Bool = false,
        restoreClipboardAfterInsertion: Bool = true,
        showDockIcon: Bool = false
    ) {
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.showMenuBarIcon = showMenuBarIcon
        self.insertTranscriptIntoActiveApp = insertTranscriptIntoActiveApp
        self.alsoCopyTranscriptToClipboard = alsoCopyTranscriptToClipboard
        self.restoreClipboardAfterInsertion = restoreClipboardAfterInsertion
        self.showDockIcon = showDockIcon
    }
}
