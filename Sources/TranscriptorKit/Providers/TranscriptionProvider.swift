import Foundation

public enum TranscriptionProviderKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case local
    case cloud

    public var id: String { rawValue }
}

public struct TranscriptorTranscriptionJob: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let historyEntryID: UUID
    public let audioFileURL: URL
    public let requestedProviderID: String
    public let requestedProviderName: String
    public let requestedModelID: String
    public let requestedModelName: String
    public let sourceType: HistorySourceType
    public let requestedAt: Date

    public init(
        id: UUID = UUID(),
        historyEntryID: UUID,
        audioFileURL: URL,
        requestedProviderID: String,
        requestedProviderName: String,
        requestedModelID: String,
        requestedModelName: String,
        sourceType: HistorySourceType,
        requestedAt: Date = .now
    ) {
        self.id = id
        self.historyEntryID = historyEntryID
        self.audioFileURL = audioFileURL
        self.requestedProviderID = requestedProviderID
        self.requestedProviderName = requestedProviderName
        self.requestedModelID = requestedModelID
        self.requestedModelName = requestedModelName
        self.sourceType = sourceType
        self.requestedAt = requestedAt
    }
}

public typealias TranscriptionJob = TranscriptorTranscriptionJob

public enum TranscriptorTranscriptionStage: String, Codable, Equatable, Sendable {
    case preparingAudio
    case loadingModel
    case transcribing
    case finalizing
}

public struct TranscriptorTranscriptionProgress: Equatable, Sendable {
    public var stage: TranscriptorTranscriptionStage
    public var fractionCompleted: Double?
    public var partialText: String
    public var statusMessage: String

    public init(
        stage: TranscriptorTranscriptionStage,
        fractionCompleted: Double? = nil,
        partialText: String = "",
        statusMessage: String
    ) {
        self.stage = stage
        self.fractionCompleted = fractionCompleted
        self.partialText = partialText
        self.statusMessage = statusMessage
    }
}

public typealias TranscriptionProgress = TranscriptorTranscriptionProgress

public struct TranscriptorTranscriptionResult: Equatable, Sendable {
    public var text: String
    public var preview: String
    public var characterCount: Int
    public var language: String?
    public var modelID: String
    public var modelName: String
    public var providerID: String
    public var providerName: String
    public var completedAt: Date

    public init(
        text: String,
        preview: String,
        characterCount: Int,
        language: String?,
        modelID: String,
        modelName: String,
        providerID: String,
        providerName: String,
        completedAt: Date = .now
    ) {
        self.text = text
        self.preview = preview
        self.characterCount = characterCount
        self.language = language
        self.modelID = modelID
        self.modelName = modelName
        self.providerID = providerID
        self.providerName = providerName
        self.completedAt = completedAt
    }
}

public typealias TranscriptionResult = TranscriptorTranscriptionResult

public enum TranscriptorTranscriptionError: Error, LocalizedError, Equatable, Sendable {
    case missingAudioFile(String)
    case missingCredentials(String)
    case privacyConsentRequired(String)
    case providerUnavailable(String)
    case unsupportedModel(String)
    case modelNotDownloaded(String)
    case modelLoadFailed(String)
    case fileTooLarge(String)
    case rateLimited(String)
    case transcriptionFailed(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case let .missingAudioFile(message),
             let .missingCredentials(message),
             let .privacyConsentRequired(message),
             let .providerUnavailable(message),
             let .unsupportedModel(message),
             let .modelNotDownloaded(message),
             let .modelLoadFailed(message),
             let .fileTooLarge(message),
             let .rateLimited(message),
             let .transcriptionFailed(message):
            message
        case .cancelled:
            "Transcription was cancelled."
        }
    }
}

public typealias TranscriptionError = TranscriptorTranscriptionError

public protocol TranscriptionProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var kind: TranscriptionProviderKind { get }

    func transcribe(
        job: TranscriptionJob,
        progressHandler: @escaping @Sendable (TranscriptionProgress) -> Void
    ) async throws -> TranscriptionResult
}

public protocol LocalTranscriptionProvider: TranscriptionProvider {
    var supportedModelIDs: Set<String> { get }
}

public protocol CloudTranscriptionProvider: TranscriptionProvider {
    func validateCredentials(modelID: String) async throws
}
