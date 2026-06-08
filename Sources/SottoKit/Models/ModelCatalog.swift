import Foundation

public struct ModelDescriptor: Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var family: String
    public var engineLabel: String
    public var notes: String
    public var downloadSizeDescription: String
    public var speedDescription: String
    public var accuracyDescription: String
    public var accentBadgeLabel: String?
    public var availability: FeatureAvailability

    public init(
        id: String,
        name: String,
        family: String,
        engineLabel: String,
        notes: String,
        downloadSizeDescription: String,
        speedDescription: String,
        accuracyDescription: String,
        accentBadgeLabel: String? = nil,
        availability: FeatureAvailability
    ) {
        self.id = id
        self.name = name
        self.family = family
        self.engineLabel = engineLabel
        self.notes = notes
        self.downloadSizeDescription = downloadSizeDescription
        self.speedDescription = speedDescription
        self.accuracyDescription = accuracyDescription
        self.accentBadgeLabel = accentBadgeLabel
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

    public var allModels: [ModelDescriptor] {
        sections.flatMap(\.models)
    }

    public static let defaultCatalog = ModelCatalog(
        sections: [
            ModelSection(
                id: "whisper",
                title: "WhisperKit Models",
                description: "Private and offline catalog mockups powered by the Apple Neural Engine in the planned product.",
                models: [
                    ModelDescriptor(
                        id: "whisper-tiny",
                        name: "Tiny",
                        family: "Whisper",
                        engineLabel: "WhisperKit",
                        notes: "Quick notes, drafts",
                        downloadSizeDescription: "~66 MB",
                        speedDescription: "Fastest",
                        accuracyDescription: "Good",
                        availability: .available(
                            note: "Mock inventory state only. Model downloads and inference are not implemented yet."
                        )
                    ),
                    ModelDescriptor(
                        id: "whisper-base-en",
                        name: "Base (English)",
                        family: "Whisper",
                        engineLabel: "WhisperKit",
                        notes: "Everyday use",
                        downloadSizeDescription: "~105 MB",
                        speedDescription: "Fast",
                        accuracyDescription: "Better",
                        availability: .available(
                            note: "Mock inventory state only. Model downloads and inference are not implemented yet."
                        )
                    ),
                    ModelDescriptor(
                        id: "whisper-small-en",
                        name: "Small (English)",
                        family: "Whisper",
                        engineLabel: "WhisperKit",
                        notes: "Important documents",
                        downloadSizeDescription: "~330 MB",
                        speedDescription: "Fast",
                        accuracyDescription: "Great",
                        availability: .available(
                            note: "Mock inventory state only. Model downloads and inference are not implemented yet."
                        )
                    ),
                    ModelDescriptor(
                        id: "whisper-large-v3-turbo",
                        name: "Large V3 Turbo",
                        family: "Whisper",
                        engineLabel: "WhisperKit",
                        notes: "Best overall quality",
                        downloadSizeDescription: "~954 MB",
                        speedDescription: "Fast",
                        accuracyDescription: "Excellent",
                        accentBadgeLabel: "Recommended",
                        availability: .downloaded(
                            note: "Mock downloaded state only. No local runtime is available in this build."
                        )
                    ),
                    ModelDescriptor(
                        id: "whisper-distil-large-v3",
                        name: "Distil Large V3",
                        family: "Whisper",
                        engineLabel: "WhisperKit",
                        notes: "Great speed and accuracy balance",
                        downloadSizeDescription: "~800 MB",
                        speedDescription: "Fast",
                        accuracyDescription: "Excellent",
                        availability: .available(
                            note: "Mock inventory state only. Model downloads and inference are not implemented yet."
                        )
                    ),
                ]
            ),
            ModelSection(
                id: "parakeet",
                title: "NVIDIA Parakeet Models",
                description: "Parakeet cards are visible for planning, but macOS runtime support is still unavailable.",
                models: [
                    ModelDescriptor(
                        id: "parakeet-v2-en",
                        name: "Parakeet v2 (English)",
                        family: "Parakeet",
                        engineLabel: "NVIDIA Parakeet",
                        notes: "Highest recall, English only",
                        downloadSizeDescription: "2.6 GB",
                        speedDescription: "Very Fast",
                        accuracyDescription: "Best",
                        availability: .unavailable(
                            blocker: "No local Parakeet runtime integration has been implemented or validated for macOS yet."
                        )
                    ),
                    ModelDescriptor(
                        id: "parakeet-v3-multilingual",
                        name: "Parakeet v3 (Multilingual)",
                        family: "Parakeet",
                        engineLabel: "NVIDIA Parakeet",
                        notes: "Multiple languages supported",
                        downloadSizeDescription: "2.7 GB",
                        speedDescription: "Very Fast",
                        accuracyDescription: "Best",
                        availability: .unavailable(
                            blocker: "No local Parakeet runtime integration has been implemented or validated for macOS yet."
                        )
                    ),
                ]
            ),
        ]
    )
}
