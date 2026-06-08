import Foundation

public struct AudioLevelSnapshot: Equatable, Sendable {
    public var rms: Float
    public var peak: Float
    public var bars: [Float]

    public init(
        rms: Float,
        peak: Float,
        bars: [Float]
    ) {
        self.rms = rms
        self.peak = peak
        self.bars = bars
    }

    public static let zero = AudioLevelSnapshot(
        rms: 0,
        peak: 0,
        bars: Array(repeating: 0, count: 12)
    )
}
