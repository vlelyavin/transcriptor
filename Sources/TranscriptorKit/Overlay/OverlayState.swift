import Foundation

public enum OverlayPosition: String, CaseIterable, Identifiable, Hashable, Sendable {
    case topCenter
    case bottomCenter

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .topCenter:
            "Top Center"
        case .bottomCenter:
            "Bottom Center"
        }
    }
}

public struct OverlayState: Equatable, Sendable {
    public var isEnabled: Bool
    public var isNonActivating: Bool
    public var showsLiveAudioIndicator: Bool
    public var position: OverlayPosition

    public init(
        isEnabled: Bool = true,
        isNonActivating: Bool = true,
        showsLiveAudioIndicator: Bool = true,
        position: OverlayPosition = .topCenter
    ) {
        self.isEnabled = isEnabled
        self.isNonActivating = isNonActivating
        self.showsLiveAudioIndicator = showsLiveAudioIndicator
        self.position = position
    }
}
