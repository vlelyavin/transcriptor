import Foundation

public struct RecordedAudioAsset: Equatable, Sendable {
    public var url: URL
    public var createdAt: Date
    public var durationSeconds: Int
    public var fileSizeBytes: Int64
    /// Exact captured length. `durationSeconds` is rounded for display and
    /// can't tell a 0.2 s accidental tap from a 1.4 s phrase.
    public var preciseDuration: TimeInterval

    public init(
        url: URL,
        createdAt: Date,
        durationSeconds: Int,
        fileSizeBytes: Int64,
        preciseDuration: TimeInterval? = nil
    ) {
        self.url = url
        self.createdAt = createdAt
        self.durationSeconds = durationSeconds
        self.fileSizeBytes = fileSizeBytes
        self.preciseDuration = preciseDuration ?? TimeInterval(durationSeconds)
    }
}
