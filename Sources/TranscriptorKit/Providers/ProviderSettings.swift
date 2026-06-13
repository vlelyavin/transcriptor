import Foundation

public struct ProviderSettings: Equatable, Sendable {
    public var openAIEnabled: Bool
    public var groqEnabled: Bool
    public var openAIModelID: String
    public var groqModelID: String
    public var openAIPrivacyAcknowledged: Bool
    public var groqPrivacyAcknowledged: Bool
    /// Whether the currently stored API key has passed a live validation against
    /// the provider. A provider is only "ready" once this is true, and it is
    /// reset whenever the stored key changes (see `AppState.saveAPIKey`). Persisted
    /// so a validated provider stays ready across launches without re-testing.
    public var openAICredentialValidated: Bool
    public var groqCredentialValidated: Bool

    public init(
        openAIEnabled: Bool = false,
        groqEnabled: Bool = false,
        openAIModelID: String = "gpt-4o-mini-transcribe",
        groqModelID: String = "whisper-large-v3-turbo",
        openAIPrivacyAcknowledged: Bool = false,
        groqPrivacyAcknowledged: Bool = false,
        openAICredentialValidated: Bool = false,
        groqCredentialValidated: Bool = false
    ) {
        self.openAIEnabled = openAIEnabled
        self.groqEnabled = groqEnabled
        self.openAIModelID = openAIModelID
        self.groqModelID = groqModelID
        self.openAIPrivacyAcknowledged = openAIPrivacyAcknowledged
        self.groqPrivacyAcknowledged = groqPrivacyAcknowledged
        self.openAICredentialValidated = openAICredentialValidated
        self.groqCredentialValidated = groqCredentialValidated
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

    public func hasValidatedCredential(for providerID: String) -> Bool {
        switch providerID {
        case "openai":
            openAICredentialValidated
        case "groq":
            groqCredentialValidated
        default:
            false
        }
    }

    public mutating func setCredentialValidated(_ validated: Bool, for providerID: String) {
        switch providerID {
        case "openai":
            openAICredentialValidated = validated
        case "groq":
            groqCredentialValidated = validated
        default:
            break
        }
    }
}
