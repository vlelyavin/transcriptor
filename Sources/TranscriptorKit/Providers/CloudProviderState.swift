import Foundation

public enum ProviderCredentialValidationState: Equatable, Sendable {
    case idle
    case testing
    case succeeded(String)
    case failed(String)

    public var message: String? {
        switch self {
        case .idle:
            nil
        case .testing:
            "Testing API key…"
        case let .succeeded(message), let .failed(message):
            message
        }
    }
}

public enum ProviderRuntimeState: Equatable, Sendable {
    case ready(message: String)
    case disabled(message: String)
    case missingAPIKey(message: String)
    case privacyConsentRequired(message: String)
    case unavailable(message: String)

    public var title: String {
        switch self {
        case .ready:
            "Ready"
        case .disabled:
            "Disabled"
        case .missingAPIKey:
            "API Key Needed"
        case .privacyConsentRequired:
            "Privacy Consent Needed"
        case .unavailable:
            "Unavailable"
        }
    }

    public var message: String {
        switch self {
        case let .ready(message),
             let .disabled(message),
             let .missingAPIKey(message),
             let .privacyConsentRequired(message),
             let .unavailable(message):
            message
        }
    }

    public var isSelectable: Bool {
        if case .ready = self {
            return true
        }

        return false
    }
}
