import Foundation

public struct RecordedAudioAsset: Equatable, Sendable {
    public var url: URL
    public var createdAt: Date
    public var durationSeconds: Int
    public var fileSizeBytes: Int64

    public init(
        url: URL,
        createdAt: Date,
        durationSeconds: Int,
        fileSizeBytes: Int64
    ) {
        self.url = url
        self.createdAt = createdAt
        self.durationSeconds = durationSeconds
        self.fileSizeBytes = fileSizeBytes
    }
}
