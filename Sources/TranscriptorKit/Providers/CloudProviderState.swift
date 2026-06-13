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
    /// A key is stored and consent is given, but the key has not yet passed a
    /// live validation against the provider — so it is not yet usable.
    case needsValidation(message: String)
    case unavailable(message: String)

    public var title: String {
        switch self {
        case .ready:
            "Ready"
        case .disabled:
            "Disabled"
        case .missingAPIKey:
            "Not Ready"
        case .privacyConsentRequired:
            "Not Ready"
        case .needsValidation:
            "Not Verified"
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
             let .needsValidation(message),
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

    /// True when the provider is fully set up and usable. Drives the green/red
    /// status indicator: green only when ready, red for every not-ready state.
    public var isReady: Bool { isSelectable }
}
