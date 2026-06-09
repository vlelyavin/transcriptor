import Foundation

public enum TranscriptionTargetSelection: Equatable, Sendable {
    case preferred
    case localModel(String)
    case provider(String)
}

public struct TranscriptionExecutionPlan: Identifiable, Equatable, Sendable {
    public let providerID: String
    public let providerName: String
    public let kind: TranscriptionProviderKind
    public let modelID: String
    public let modelName: String

    public init(
        providerID: String,
        providerName: String,
        kind: TranscriptionProviderKind,
        modelID: String,
        modelName: String
    ) {
        self.providerID = providerID
        self.providerName = providerName
        self.kind = kind
        self.modelID = modelID
        self.modelName = modelName
    }

    public var id: String {
        "\(providerID)::\(modelID)"
    }
}

public struct TranscriptionTargetResolver: Sendable {
    private let modelCatalog: ModelCatalog
    private let providerCatalog: ProviderCatalog

    public init(
        modelCatalog: ModelCatalog,
        providerCatalog: ProviderCatalog
    ) {
        self.modelCatalog = modelCatalog
        self.providerCatalog = providerCatalog
    }

    public func resolve(
        selection: TranscriptionTargetSelection = .preferred,
        preferences: TranscriptionPreferences,
        providerSettings: ProviderSettings,
        readyLocalModelIDs: Set<String>,
        providerStatesByID: [String: ProviderRuntimeState]
    ) throws -> TranscriptionExecutionPlan {
        switch selection {
        case .preferred:
            if localProviderIDs.contains(preferences.preferredProviderID) {
                return try resolveLocalModel(
                    modelID: preferences.selectedModelID,
                    readyLocalModelIDs: readyLocalModelIDs
                )
            }

            return try resolveProvider(
                providerID: preferences.preferredProviderID,
                providerSettings: providerSettings,
                providerStatesByID: providerStatesByID
            )
        case let .localModel(modelID):
            return try resolveLocalModel(modelID: modelID, readyLocalModelIDs: readyLocalModelIDs)
        case let .provider(providerID):
            return try resolveProvider(
                providerID: providerID,
                providerSettings: providerSettings,
                providerStatesByID: providerStatesByID
            )
        }
    }

    public func availableRetranscriptionPlans(
        providerSettings: ProviderSettings,
        readyLocalModelIDs: Set<String>,
        providerStatesByID: [String: ProviderRuntimeState]
    ) -> [TranscriptionExecutionPlan] {
        let localPlans = modelCatalog.localModels
            .filter { readyLocalModelIDs.contains($0.id) }
            .map {
                TranscriptionExecutionPlan(
                    providerID: $0.localProviderID ?? "whisperkit-local",
                    providerName: providerDisplayName(for: $0.localProviderID ?? "whisperkit-local"),
                    kind: .local,
                    modelID: $0.id,
                    modelName: $0.name
                )
            }

        let cloudPlans = providerCatalog.providers.compactMap { provider -> TranscriptionExecutionPlan? in
            guard providerStatesByID[provider.id]?.isSelectable == true else {
                return nil
            }

            return TranscriptionExecutionPlan(
                providerID: provider.id,
                providerName: provider.name,
                kind: .cloud,
                modelID: providerSettings.modelID(for: provider.id, fallback: provider.modelLabel),
                modelName: providerSettings.modelID(for: provider.id, fallback: provider.modelLabel)
            )
        }

        return localPlans + cloudPlans
    }

    private func resolveLocalModel(
        modelID: String,
        readyLocalModelIDs: Set<String>
    ) throws -> TranscriptionExecutionPlan {
        guard let model = modelCatalog.model(id: modelID), model.supportsLocalTranscription, let localProviderID = model.localProviderID else {
            throw TranscriptionError.unsupportedModel("Choose a supported local model before transcribing.")
        }

        guard readyLocalModelIDs.contains(modelID) else {
            throw TranscriptionError.modelNotDownloaded("Download and load \(model.name) from Models before transcribing.")
        }

        return TranscriptionExecutionPlan(
            providerID: localProviderID,
            providerName: providerDisplayName(for: localProviderID),
            kind: .local,
            modelID: model.id,
            modelName: model.name
        )
    }

    private var localProviderIDs: Set<String> {
        ["whisperkit-local", "parakeet-local"]
    }

    private func providerDisplayName(for providerID: String) -> String {
        switch providerID {
        case "parakeet-local":
            "Parakeet Local"
        default:
            "WhisperKit Local"
        }
    }

    private func resolveProvider(
        providerID: String,
        providerSettings: ProviderSettings,
        providerStatesByID: [String: ProviderRuntimeState]
    ) throws -> TranscriptionExecutionPlan {
        guard let provider = providerCatalog.provider(id: providerID) else {
            throw TranscriptionError.providerUnavailable("The requested provider is not available in this build.")
        }

        let providerState = providerStatesByID[providerID] ?? .unavailable(message: provider.availability.message)
        switch providerState {
        case .ready:
            return TranscriptionExecutionPlan(
                providerID: provider.id,
                providerName: provider.name,
                kind: .cloud,
                modelID: providerSettings.modelID(for: provider.id, fallback: provider.modelLabel),
                modelName: providerSettings.modelID(for: provider.id, fallback: provider.modelLabel)
            )
        case let .disabled(message):
            throw TranscriptionError.providerUnavailable(message)
        case let .missingAPIKey(message):
            throw TranscriptionError.missingCredentials(message)
        case let .privacyConsentRequired(message):
            throw TranscriptionError.privacyConsentRequired(message)
        case let .unavailable(message):
            throw TranscriptionError.providerUnavailable(message)
        }
    }
}
