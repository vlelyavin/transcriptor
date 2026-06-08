import Foundation

public enum RecordingMode: String, CaseIterable, Identifiable, Sendable {
    case holdToTalk
    case togglePushToTalk

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .holdToTalk:
            "Hold to Talk"
        case .togglePushToTalk:
            "Toggle Push to Talk"
        }
    }
}

public struct HotkeyConfiguration: Equatable, Sendable {
    public var key: String
    public var modifiers: [String]

    public init(
        key: String = "Space",
        modifiers: [String] = ["Option", "Shift"]
    ) {
        self.key = key
        self.modifiers = modifiers
    }
}
