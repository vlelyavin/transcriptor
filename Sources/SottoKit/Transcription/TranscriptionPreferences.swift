import Foundation

public struct TranscriptionPreferences: Equatable, Sendable {
    public var preferredLocalModelID: String?
    public var preferredCloudProviderID: String?

    public init(
        preferredLocalModelID: String? = nil,
        preferredCloudProviderID: String? = nil
    ) {
        self.preferredLocalModelID = preferredLocalModelID
        self.preferredCloudProviderID = preferredCloudProviderID
    }
}
