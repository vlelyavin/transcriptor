import Foundation

public struct StorageSettings: Equatable, Sendable {
    public var capMegabytes: Int
    public var autoDeleteOldestHistory: Bool
    public var excludesDownloadedModels: Bool

    public init(
        capMegabytes: Int = 2_048,
        autoDeleteOldestHistory: Bool = true,
        excludesDownloadedModels: Bool = true
    ) {
        self.capMegabytes = capMegabytes
        self.autoDeleteOldestHistory = autoDeleteOldestHistory
        self.excludesDownloadedModels = excludesDownloadedModels
    }
}
