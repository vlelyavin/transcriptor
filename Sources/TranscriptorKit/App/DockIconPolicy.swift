import Foundation

/// Decides whether Transcriptor should be a Dock (`.regular`) app or a
/// menu-bar-only (`.accessory`) app.
///
/// Pulled out of `AppDelegate` so the rules are testable and stated in one place:
///
/// * the user pinned a Dock icon in Settings, or
/// * one of the app's regular windows is open (a window without a Dock icon
///   cannot be focused reliably), or
/// * a recording is in progress and the user asked for a Dock icon while
///   recording — a visible reminder that the microphone is live.
///
/// Prompt-style `NSPanel`s (the recording overlay, the result card) never count
/// as a window: showing them must not drag the app into the Dock.
public enum DockIconPolicy {
    public struct Input: Equatable, Sendable {
        public var pinnedDockIcon: Bool
        public var showsDockIconWhileRecording: Bool
        public var hasVisibleWindow: Bool
        public var isRecording: Bool

        public init(
            pinnedDockIcon: Bool = false,
            showsDockIconWhileRecording: Bool = false,
            hasVisibleWindow: Bool = false,
            isRecording: Bool = false
        ) {
            self.pinnedDockIcon = pinnedDockIcon
            self.showsDockIconWhileRecording = showsDockIconWhileRecording
            self.hasVisibleWindow = hasVisibleWindow
            self.isRecording = isRecording
        }
    }

    public static func shouldShowDockIcon(for input: Input) -> Bool {
        input.pinnedDockIcon
            || input.hasVisibleWindow
            || (input.isRecording && input.showsDockIconWhileRecording)
    }
}
