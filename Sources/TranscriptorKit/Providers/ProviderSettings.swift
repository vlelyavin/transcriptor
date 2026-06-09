import Foundation

public struct ProviderSettings: Equatable, Sendable {
    public var openAIEnabled: Bool
    public var groqEnabled: Bool
    public var openAIModelID: String
    public var groqModelID: String
    public var openAIPrivacyAcknowledged: Bool
    public var groqPrivacyAcknowledged: Bool

    public init(
        openAIEnabled: Bool = false,
        groqEnabled: Bool = false,
        openAIModelID: String = "gpt-4o-mini-transcribe",
        groqModelID: String = "whisper-large-v3-turbo",
        openAIPrivacyAcknowledged: Bool = false,
        groqPrivacyAcknowledged: Bool = false
    ) {
        self.openAIEnabled = openAIEnabled
        self.groqEnabled = groqEnabled
        self.openAIModelID = openAIModelID
        self.groqModelID = groqModelID
        self.openAIPrivacyAcknowledged = openAIPrivacyAcknowledged
        self.groqPrivacyAcknowledged = groqPrivacyAcknowledged
    }

    public func isEnabled(providerID: String) -> Bool {
        switch providerID {
        case "openai":
            openAIEnabled
        case "groq":
            groqEnabled
        default:
            false
        }
    }

    public func modelID(for providerID: String, fallback: String) -> String {
        switch providerID {
        case "openai":
            openAIModelID
        case "groq":
            groqModelID
        default:
            fallback
        }
    }

    public func hasPrivacyConsent(for providerID: String) -> Bool {
        switch providerID {
        case "openai":
            openAIPrivacyAcknowledged
        case "groq":
            groqPrivacyAcknowledged
        default:
            false
        }
    }
}
