import Foundation

public enum OverlaySupplementalPhase: Equatable, Sendable {
    case transcribing(String)
    case inserting(String)
    case saved(String)
    case error(String)
    case setupRequired(String)
    /// Audio was captured but transcription is not configured — show recorder
    /// metadata with Save/Delete and a "Configure Transcription" path.
    case unconfigured(OverlayUnconfiguredPayload)

    /// A short identifier for logging — never carries message payloads, so
    /// transcripts and error text stay out of the unified log.
    public var caseName: String {
        switch self {
        case .transcribing:
            "transcribing"
        case .inserting:
            "inserting"
        case .saved:
            "saved"
        case .error:
            "error"
        case .setupRequired:
            "setupRequired"
        case .unconfigured:
            "unconfigured"
        }
    }
}

/// Data shown when transcription isn't configured.
public struct OverlayUnconfiguredPayload: Equatable, Sendable, Identifiable {
    public let entryID: UUID
    public let fileName: String
    public let durationSeconds: Int

    public var id: UUID { entryID }

    public init(entryID: UUID, fileName: String, durationSeconds: Int) {
        self.entryID = entryID
        self.fileName = fileName
        self.durationSeconds = durationSeconds
    }
}

/// Action callbacks the overlay result card invokes. Wired from AppState.
public struct RecordingOverlayActions: Sendable {
    public var save: @MainActor (UUID) -> Void
    public var delete: @MainActor (UUID) -> Void
    public var configureTranscription: @MainActor () -> Void
    public var dismiss: @MainActor () -> Void

    public init(
        save: @escaping @MainActor (UUID) -> Void = { _ in },
        delete: @escaping @MainActor (UUID) -> Void = { _ in },
        configureTranscription: @escaping @MainActor () -> Void = {},
        dismiss: @escaping @MainActor () -> Void = {}
    ) {
        self.save = save
        self.delete = delete
        self.configureTranscription = configureTranscription
        self.dismiss = dismiss
    }
}
