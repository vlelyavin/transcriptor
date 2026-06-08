import Foundation

public struct StorageSettings: Equatable, Sendable {
    public var capMegabytes: Int
    public var excludesDownloadedModels: Bool

    public init(
        capMegabytes: Int = 2_048,
        excludesDownloadedModels: Bool = true
    ) {
        self.capMegabytes = capMegabytes
        self.excludesDownloadedModels = excludesDownloadedModels
    }
}
