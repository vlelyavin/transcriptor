import Foundation

public enum OverlaySupplementalPhase: Equatable, Sendable {
    case transcribing(String)
    case inserting(String)
    case saved(String)
    case error(String)
    case setupRequired(String)
    /// Transcription finished but there was no focused field to paste into —
    /// show an interactive preview with Copy/Save/Delete/Re-transcribe.
    case preview(OverlayPreviewPayload)
    /// Audio was captured but transcription is not configured — show recorder
    /// metadata with Save/Delete and a "Configure Transcription" path.
    case unconfigured(OverlayUnconfiguredPayload)
}

/// Data shown in the transcript preview card.
public struct OverlayPreviewPayload: Equatable, Sendable, Identifiable {
    public let entryID: UUID
    public let transcript: String
    public let modelName: String?
    public let durationSeconds: Int

    public var id: UUID { entryID }

    public init(entryID: UUID, transcript: String, modelName: String?, durationSeconds: Int) {
        self.entryID = entryID
        self.transcript = transcript
        self.modelName = modelName
        self.durationSeconds = durationSeconds
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

/// A re-transcription choice offered in the preview card's menu.
public struct OverlayRetranscribeOption: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        case localModel(String)
        case cloudProvider(String)
    }

    public let id: String
    public let title: String
    public let isCloud: Bool
    public let kind: Kind

    public init(id: String, title: String, isCloud: Bool, kind: Kind) {
        self.id = id
        self.title = title
        self.isCloud = isCloud
        self.kind = kind
    }
}

/// Action callbacks the overlay result cards invoke. Wired from AppState.
public struct RecordingOverlayActions: Sendable {
    public var copy: @MainActor (UUID) -> Void
    public var save: @MainActor (UUID) -> Void
    public var delete: @MainActor (UUID) -> Void
    public var showAll: @MainActor (UUID) -> Void
    public var retranscribe: @MainActor (UUID, OverlayRetranscribeOption) -> Void
    public var retranscribeOptions: @MainActor () -> [OverlayRetranscribeOption]
    public var configureTranscription: @MainActor () -> Void
    public var dismiss: @MainActor () -> Void

    public init(
        copy: @escaping @MainActor (UUID) -> Void = { _ in },
        save: @escaping @MainActor (UUID) -> Void = { _ in },
        delete: @escaping @MainActor (UUID) -> Void = { _ in },
        showAll: @escaping @MainActor (UUID) -> Void = { _ in },
        retranscribe: @escaping @MainActor (UUID, OverlayRetranscribeOption) -> Void = { _, _ in },
        retranscribeOptions: @escaping @MainActor () -> [OverlayRetranscribeOption] = { [] },
        configureTranscription: @escaping @MainActor () -> Void = {},
        dismiss: @escaping @MainActor () -> Void = {}
    ) {
        self.copy = copy
        self.save = save
        self.delete = delete
        self.showAll = showAll
        self.retranscribe = retranscribe
        self.retranscribeOptions = retranscribeOptions
        self.configureTranscription = configureTranscription
        self.dismiss = dismiss
    }
}
