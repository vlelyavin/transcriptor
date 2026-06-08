import Foundation

public struct TranscriptVersion: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var createdAt: Date
    public var transcriptText: String
    public var transcriptPreview: String
    public var characterCount: Int
    public var modelID: String?
    public var modelName: String?
    public var providerID: String?
    public var providerName: String?
    public var language: String?

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        transcriptText: String,
        transcriptPreview: String,
        characterCount: Int,
        modelID: String?,
        modelName: String?,
        providerID: String?,
        providerName: String?,
        language: String?
    ) {
        self.id = id
        self.createdAt = createdAt
        self.transcriptText = transcriptText
        self.transcriptPreview = transcriptPreview
        self.characterCount = characterCount
        self.modelID = modelID
        self.modelName = modelName
        self.providerID = providerID
        self.providerName = providerName
        self.language = language
    }
}
