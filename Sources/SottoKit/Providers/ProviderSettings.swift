import Foundation

public struct ProviderSettings: Equatable, Sendable {
    public var openAIEnabled: Bool
    public var groqEnabled: Bool

    public init(
        openAIEnabled: Bool = false,
        groqEnabled: Bool = false
    ) {
        self.openAIEnabled = openAIEnabled
        self.groqEnabled = groqEnabled
    }
}
