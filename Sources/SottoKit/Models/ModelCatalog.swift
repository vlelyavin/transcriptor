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
    public var intendedUseLabel: String
    public var languageScopeLabel: String
    public var remoteVariantName: String?
    public var approximateDownloadBytes: Int64?
    public var supportsLocalTranscription: Bool
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
        intendedUseLabel: String,
        languageScopeLabel: String,
        remoteVariantName: String? = nil,
        approximateDownloadBytes: Int64? = nil,
        supportsLocalTranscription: Bool = false,
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
        self.intendedUseLabel = intendedUseLabel
        self.languageScopeLabel = languageScopeLabel
        self.remoteVariantName = remoteVariantName
        self.approximateDownloadBytes = approximateDownloadBytes
        self.supportsLocalTranscription = supportsLocalTranscription
        self.accentBadgeLabel = accentBadgeLabel
        self.availability = availability
    }

    public var isWhisperKitLocalModel: Bool {
        supportsLocalTranscription && remoteVariantName != nil
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

    public var whisperModels: [ModelDescriptor] {
        sections.first(where: { $0.id == "whisper" })?.models ?? []
    }

    public func model(id: String) -> ModelDescriptor? {
        allModels.first(where: { $0.id == id })
    }

    public static let defaultCatalog = ModelCatalog(
        sections: [
            ModelSection(
                id: "whisper",
                title: "WhisperKit Models",
                description: "Local Whisper-family models are backed by Argmax OSS WhisperKit and stored in Sotto-managed model storage.",
                models: [
                    ModelDescriptor(
                        id: "whisper-tiny",
                        name: "Tiny",
                        family: "Whisper",
                        engineLabel: "WhisperKit",
                        notes: "Fastest local model for quick capture and debugging.",
                        downloadSizeDescription: "~66 MB",
                        speedDescription: "Fastest",
                        accuracyDescription: "Good",
                        intendedUseLabel: "Draft dictation",
                        languageScopeLabel: "Multilingual",
                        remoteVariantName: "openai_whisper-tiny",
                        approximateDownloadBytes: 66 * 1_048_576,
                        supportsLocalTranscription: true,
                        availability: .available(
                            note: "Downloadable and runnable locally with WhisperKit."
                        )
                    ),
                    ModelDescriptor(
                        id: "whisper-base-en",
                        name: "Base (English)",
                        family: "Whisper",
                        engineLabel: "WhisperKit",
                        notes: "Smaller English-first local model for everyday notes.",
                        downloadSizeDescription: "~105 MB",
                        speedDescription: "Fast",
                        accuracyDescription: "Better",
                        intendedUseLabel: "Everyday English dictation",
                        languageScopeLabel: "English",
                        remoteVariantName: "openai_whisper-base.en",
                        approximateDownloadBytes: 105 * 1_048_576,
                        supportsLocalTranscription: true,
                        availability: .available(
                            note: "Downloadable and runnable locally with WhisperKit."
                        )
                    ),
                    ModelDescriptor(
                        id: "whisper-small-en",
                        name: "Small (English)",
                        family: "Whisper",
                        engineLabel: "WhisperKit",
                        notes: "Better English accuracy while staying practical for laptops.",
                        downloadSizeDescription: "~217 MB",
                        speedDescription: "Balanced",
                        accuracyDescription: "Great",
                        intendedUseLabel: "Longer English notes",
                        languageScopeLabel: "English",
                        remoteVariantName: "openai_whisper-small.en_217MB",
                        approximateDownloadBytes: 217 * 1_048_576,
                        supportsLocalTranscription: true,
                        availability: .available(
                            note: "Downloadable and runnable locally with WhisperKit."
                        )
                    ),
                    ModelDescriptor(
                        id: "whisper-large-v3-turbo",
                        name: "Large V3 Turbo",
                        family: "Whisper",
                        engineLabel: "WhisperKit",
                        notes: "Best general-purpose local quality in the current catalog.",
                        downloadSizeDescription: "~632 MB",
                        speedDescription: "Balanced",
                        accuracyDescription: "Excellent",
                        intendedUseLabel: "High-accuracy local transcription",
                        languageScopeLabel: "Multilingual",
                        remoteVariantName: "openai_whisper-large-v3-v20240930_turbo_632MB",
                        approximateDownloadBytes: 632 * 1_048_576,
                        supportsLocalTranscription: true,
                        accentBadgeLabel: "Recommended",
                        availability: .available(
                            note: "Downloadable and runnable locally with WhisperKit."
                        )
                    ),
                    ModelDescriptor(
                        id: "whisper-distil-large-v3",
                        name: "Distil Large V3",
                        family: "Whisper",
                        engineLabel: "WhisperKit",
                        notes: "Faster distilled large model with strong English performance.",
                        downloadSizeDescription: "~594 MB",
                        speedDescription: "Fast",
                        accuracyDescription: "Excellent",
                        intendedUseLabel: "Fast re-transcription",
                        languageScopeLabel: "English",
                        remoteVariantName: "distil-whisper_distil-large-v3_594MB",
                        approximateDownloadBytes: 594 * 1_048_576,
                        supportsLocalTranscription: true,
                        availability: .available(
                            note: "Downloadable and runnable locally with WhisperKit."
                        )
                    ),
                ]
            ),
            ModelSection(
                id: "parakeet",
                title: "NVIDIA Parakeet Models",
                description: "Parakeet cards remain visible for roadmap clarity, but no validated local macOS runtime is wired into Sotto yet.",
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
                        intendedUseLabel: "Roadmap only",
                        languageScopeLabel: "English",
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
                        intendedUseLabel: "Roadmap only",
                        languageScopeLabel: "Multilingual",
                        availability: .unavailable(
                            blocker: "No local Parakeet runtime integration has been implemented or validated for macOS yet."
                        )
                    ),
                ]
            ),
        ]
    )
}
