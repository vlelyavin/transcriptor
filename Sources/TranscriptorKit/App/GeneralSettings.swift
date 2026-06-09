import Foundation

public struct GeneralSettings: Equatable, Sendable {
    public var launchAtLoginEnabled: Bool

    public init(launchAtLoginEnabled: Bool = false) {
        self.launchAtLoginEnabled = launchAtLoginEnabled
    }
}
