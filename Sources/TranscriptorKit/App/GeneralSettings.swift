import Foundation

public struct GeneralSettings: Equatable, Sendable {
    public var launchAtLoginEnabled: Bool
    public var showMenuBarIcon: Bool
    public var insertTranscriptIntoActiveApp: Bool
    public var alsoCopyTranscriptToClipboard: Bool
    public var restoreClipboardAfterInsertion: Bool

    public init(
        launchAtLoginEnabled: Bool = false,
        showMenuBarIcon: Bool = true,
        insertTranscriptIntoActiveApp: Bool = true,
        alsoCopyTranscriptToClipboard: Bool = false,
        restoreClipboardAfterInsertion: Bool = true
    ) {
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.showMenuBarIcon = showMenuBarIcon
        self.insertTranscriptIntoActiveApp = insertTranscriptIntoActiveApp
        self.alsoCopyTranscriptToClipboard = alsoCopyTranscriptToClipboard
        self.restoreClipboardAfterInsertion = restoreClipboardAfterInsertion
    }
}
