import Foundation

public struct OverlayState: Equatable, Sendable {
    public var isNonActivating: Bool
    public var showsLiveAudioIndicator: Bool

    public init(
        isNonActivating: Bool = true,
        showsLiveAudioIndicator: Bool = true
    ) {
        self.isNonActivating = isNonActivating
        self.showsLiveAudioIndicator = showsLiveAudioIndicator
    }
}
