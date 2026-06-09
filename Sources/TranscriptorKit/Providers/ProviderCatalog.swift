import Foundation

public struct ProviderDescriptor: Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var modelLabel: String
    public var summary: String
    public var priceNote: String
    public var privacySummary: String
    public var baseURL: URL
    public var directUploadLimitBytes: Int64
    public var keychainAccount: String
    public var availability: FeatureAvailability

    public init(
        id: String,
        name: String,
        modelLabel: String,
        summary: String,
        priceNote: String,
        privacySummary: String,
        baseURL: URL,
        directUploadLimitBytes: Int64,
        keychainAccount: String,
        availability: FeatureAvailability
    ) {
        self.id = id
        self.name = name
        self.modelLabel = modelLabel
        self.summary = summary
        self.priceNote = priceNote
        self.privacySummary = privacySummary
        self.baseURL = baseURL
        self.directUploadLimitBytes = directUploadLimitBytes
        self.keychainAccount = keychainAccount
        self.availability = availability
    }
}

public struct ProviderCatalog: Equatable, Sendable {
    public var providers: [ProviderDescriptor]

    public init(providers: [ProviderDescriptor]) {
        self.providers = providers
    }

    public func provider(id: String) -> ProviderDescriptor? {
        providers.first(where: { $0.id == id })
    }

    public static let defaultCatalog = ProviderCatalog(
        providers: [
            ProviderDescriptor(
                id: "openai",
                name: "OpenAI",
                modelLabel: "gpt-4o-mini-transcribe",
                summary: "Industry-leading accuracy with OpenAI's latest speech models.",
                priceNote: "~$0.006/minute",
                privacySummary: "Audio is uploaded to OpenAI for transcription.",
                baseURL: URL(string: "https://api.openai.com/v1")!,
                directUploadLimitBytes: 25 * 1_048_576,
                keychainAccount: "openai-api-key",
                availability: .available(
                    note: "Requires an OpenAI API key in Keychain and explicit cloud privacy consent."
                )
            ),
            ProviderDescriptor(
                id: "groq",
                name: "Groq",
                modelLabel: "whisper-large-v3-turbo",
                summary: "Fast, accurate results powered by Groq's inference engine.",
                priceNote: "~$0.04/hour",
                privacySummary: "Audio is uploaded to Groq for transcription.",
                baseURL: URL(string: "https://api.groq.com/openai/v1")!,
                directUploadLimitBytes: 25 * 1_048_576,
                keychainAccount: "groq-api-key",
                availability: .available(
                    note: "Requires a Groq API key in Keychain and explicit cloud privacy consent."
                )
            ),
        ]
    )
}
