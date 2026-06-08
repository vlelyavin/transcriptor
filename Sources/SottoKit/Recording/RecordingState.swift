import Foundation

public struct RecordingState: Equatable, Sendable {
    public var mode: RecordingMode
    public var hotkey: HotkeyConfiguration
    public var savesAudioLocally: Bool

    public init(
        mode: RecordingMode = .holdToTalk,
        hotkey: HotkeyConfiguration = HotkeyConfiguration(),
        savesAudioLocally: Bool = true
    ) {
        self.mode = mode
        self.hotkey = hotkey
        self.savesAudioLocally = savesAudioLocally
    }
}
