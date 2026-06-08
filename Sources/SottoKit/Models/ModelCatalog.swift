import Foundation

public struct ModelDescriptor: Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var family: String
    public var notes: String
    public var downloadSizeDescription: String
    public var availability: FeatureAvailability

    public init(
        id: String,
        name: String,
        family: String,
        notes: String,
        downloadSizeDescription: String,
        availability: FeatureAvailability
    ) {
        self.id = id
        self.name = name
        self.family = family
        self.notes = notes
        self.downloadSizeDescription = downloadSizeDescription
        self.availability = availability
    }
}

public struct ModelSection: Identifiable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var description: String
    public var models: [ModelDescriptor]

    public init(
        id: String,
        title: String,
        description: String,
        models: [ModelDescriptor]
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.models = models
    }
}

public struct ModelCatalog: Equatable, Sendable {
    public var sections: [ModelSection]

    public init(sections: [ModelSection]) {
        self.sections = sections
    }

    public static let defaultCatalog = ModelCatalog(
        sections: [
            ModelSection(
                id: "whisper",
                title: "Whisper Family",
                description: "Local-first transcription models intended to run on-device.",
                models: [
                    ModelDescriptor(
                        id: "whisper-tiny",
                        name: "Whisper Tiny",
                        family: "Whisper",
                        notes: "Fast, low-accuracy starter model for future local runs.",
                        downloadSizeDescription: "~75 MB",
                        availability: .planned(
                            blocker: "Local model runtime and download pipeline are not implemented in this initial scaffold."
                        )
                    ),
                    ModelDescriptor(
                        id: "whisper-small",
                        name: "Whisper Small",
                        family: "Whisper",
                        notes: "Balanced latency and quality target for future offline transcription.",
                        downloadSizeDescription: "~460 MB",
                        availability: .planned(
                            blocker: "Local model runtime and download pipeline are not implemented in this initial scaffold."
                        )
                    ),
                ]
            ),
            ModelSection(
                id: "parakeet",
                title: "NVIDIA Parakeet",
                description: "Reserved section for future Parakeet model exploration.",
                models: [
                    ModelDescriptor(
                        id: "parakeet-tdt",
                        name: "Parakeet TDT",
                        family: "Parakeet",
                        notes: "Evaluation placeholder only. No bundled runtime support yet.",
                        downloadSizeDescription: "TBD",
                        availability: .unavailable(
                            blocker: "No local Parakeet runtime integration has been implemented or validated for macOS yet."
                        )
                    ),
                ]
            ),
        ]
    )
}
