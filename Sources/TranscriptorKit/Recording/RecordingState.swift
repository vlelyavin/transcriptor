import Foundation

public struct RecordingState: Equatable, Sendable {
    public var mode: RecordingMode
    public var hotkey: HotkeyConfiguration

    public init(
        mode: RecordingMode = .holdToTalk,
        hotkey: HotkeyConfiguration = HotkeyConfiguration()
    ) {
        self.mode = mode
        self.hotkey = hotkey
    }
}
