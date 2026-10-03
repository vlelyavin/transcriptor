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
    /// Any OpenAI-compatible `/audio/transcriptions` server (a proxy, a
    /// self-hosted Whisper server, another vendor).
    public var customBaseURL: String
    public var customModelID: String
    public var customPrivacyAcknowledged: Bool
    public var customCredentialValidated: Bool

    public init(
        openAIEnabled: Bool = false,
        groqEnabled: Bool = false,
        openAIModelID: String = "gpt-4o-mini-transcribe",
        groqModelID: String = "whisper-large-v3-turbo",
        openAIPrivacyAcknowledged: Bool = false,
        groqPrivacyAcknowledged: Bool = false,
        openAICredentialValidated: Bool = false,
        groqCredentialValidated: Bool = false,
        customBaseURL: String = "",
        customModelID: String = "whisper-1",
        customPrivacyAcknowledged: Bool = false,
        customCredentialValidated: Bool = false
    ) {
        self.openAIEnabled = openAIEnabled
        self.groqEnabled = groqEnabled
        self.openAIModelID = openAIModelID
        self.groqModelID = groqModelID
        self.openAIPrivacyAcknowledged = openAIPrivacyAcknowledged
        self.groqPrivacyAcknowledged = groqPrivacyAcknowledged
        self.openAICredentialValidated = openAICredentialValidated
        self.groqCredentialValidated = groqCredentialValidated
        self.customBaseURL = customBaseURL
        self.customModelID = customModelID
        self.customPrivacyAcknowledged = customPrivacyAcknowledged
        self.customCredentialValidated = customCredentialValidated
    }

    /// The custom server's base URL (e.g. `https://host/v1`), or `nil` while
    /// the field is empty or not an http(s) URL.
    public var customBaseURLValue: URL? {
        let trimmed = customBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host?.isEmpty == false else {
            return nil
        }
        return url
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
        case "custom":
            customModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? fallback
                : customModelID.trimmingCharacters(in: .whitespacesAndNewlines)
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
        case "custom":
            customPrivacyAcknowledged
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
        case "custom":
            customCredentialValidated
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
        case "custom":
            customCredentialValidated = validated
        default:
            break
        }
    }
}
