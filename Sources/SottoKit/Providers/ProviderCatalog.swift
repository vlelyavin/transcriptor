import Foundation

public struct ProviderDescriptor: Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var summary: String
    public var availability: FeatureAvailability

    public init(
        id: String,
        name: String,
        summary: String,
        availability: FeatureAvailability
    ) {
        self.id = id
        self.name = name
        self.summary = summary
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
                summary: "Future cloud transcription provider for remote model access.",
                availability: .unavailable(
                    blocker: "Cloud networking is intentionally out of scope for this initial scaffold."
                )
            ),
            ProviderDescriptor(
                id: "groq",
                name: "Groq",
                summary: "Future cloud transcription provider for low-latency remote inference.",
                availability: .unavailable(
                    blocker: "Cloud networking is intentionally out of scope for this initial scaffold."
                )
            ),
        ]
    )
}
