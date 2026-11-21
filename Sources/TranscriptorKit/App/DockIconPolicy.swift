import Foundation

/// Decides whether Transcriptor should be a Dock (`.regular`) app or a
/// menu-bar-only (`.accessory`) app.
///
/// Pulled out of `AppDelegate` so the rules are testable and stated in one place:
///
/// * the user pinned a Dock icon in Settings, or
/// * a recording is in progress and the user asked for a Dock icon while
///   recording — a visible reminder that the microphone is live.
///
/// An open window does NOT imply a Dock icon. With "Always show Dock icon"
/// off, Transcriptor stays `.accessory` even while its main/settings window is
/// open; the window still becomes key because opening it goes through
/// `AppState.showMainWindow()`, which activates the app. A Dock icon is a
/// user preference, not a prerequisite for a keyable window.
///
/// Prompt-style `NSPanel`s (the recording overlay, the result card) never count
/// as a window: showing them must not drag the app into the Dock.
public enum DockIconPolicy {
    public struct Input: Equatable, Sendable {
        public var pinnedDockIcon: Bool
        public var showsDockIconWhileRecording: Bool
        public var isRecording: Bool

        public init(
            pinnedDockIcon: Bool = false,
            showsDockIconWhileRecording: Bool = false,
            isRecording: Bool = false
        ) {
            self.pinnedDockIcon = pinnedDockIcon
            self.showsDockIconWhileRecording = showsDockIconWhileRecording
            self.isRecording = isRecording
        }
    }

    public static func shouldShowDockIcon(for input: Input) -> Bool {
        input.pinnedDockIcon
            || (input.isRecording && input.showsDockIconWhileRecording)
    }
}
