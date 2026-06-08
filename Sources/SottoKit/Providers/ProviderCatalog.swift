import Foundation

public struct ProviderDescriptor: Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var modelLabel: String
    public var summary: String
    public var priceNote: String
    public var availability: FeatureAvailability

    public init(
        id: String,
        name: String,
        modelLabel: String,
        summary: String,
        priceNote: String,
        availability: FeatureAvailability
    ) {
        self.id = id
        self.name = name
        self.modelLabel = modelLabel
        self.summary = summary
        self.priceNote = priceNote
        self.availability = availability
    }
}

public struct ProviderCatalog: Equatable, Sendable {
    public var providers: [ProviderDescriptor]

    public init(providers: [ProviderDescriptor]) {
        self.providers = providers
    }

    public static let defaultCatalog = ProviderCatalog(
        providers: [
            ProviderDescriptor(
                id: "openai",
                name: "OpenAI",
                modelLabel: "gpt-4o-mini-transcribe",
                summary: "Industry-leading accuracy with OpenAI's latest speech models.",
                priceNote: "~$0.006/minute",
                availability: .unavailable(
                    blocker: "Cloud networking is intentionally out of scope for this initial scaffold."
                )
            ),
            ProviderDescriptor(
                id: "groq",
                name: "Groq",
                modelLabel: "whisper-large-v3-turbo",
                summary: "Fast, accurate results powered by Groq's inference engine.",
                priceNote: "~$0.006/minute",
                availability: .unavailable(
                    blocker: "Cloud networking is intentionally out of scope for this initial scaffold."
                )
            ),
        ]
    )
}
