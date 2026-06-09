import Foundation

public struct AudioCaptureState: Equatable, Sendable {
    public var inputDeviceName: String
    public var sampleRate: Int

    public init(
        inputDeviceName: String = "System Default",
        sampleRate: Int = 16_000
    ) {
        self.inputDeviceName = inputDeviceName
        self.sampleRate = sampleRate
    }
}
