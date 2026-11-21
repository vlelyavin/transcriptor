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

/// How much chrome the recording overlay shows. `standard` is the status
/// strip; `compact` is the 40 pt pill for people who want it out of the way.
public enum OverlayDisplayMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    case standard
    case compact

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .standard:
            "Standard"
        case .compact:
            "Compact"
        }
    }
}

public struct OverlayState: Equatable, Sendable {
    public var isEnabled: Bool
    public var isNonActivating: Bool
    public var showsLiveAudioIndicator: Bool
    public var position: OverlayPosition
    public var displayMode: OverlayDisplayMode

    public init(
        isEnabled: Bool = true,
        isNonActivating: Bool = true,
        showsLiveAudioIndicator: Bool = true,
        position: OverlayPosition = .topCenter,
        displayMode: OverlayDisplayMode = .standard
    ) {
        self.isEnabled = isEnabled
        self.isNonActivating = isNonActivating
        self.showsLiveAudioIndicator = showsLiveAudioIndicator
        self.position = position
        self.displayMode = displayMode
    }
}
