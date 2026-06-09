import Foundation

public enum LocalModelState: Equatable, Sendable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case loading
    case loaded
    case deleting
    case failed(message: String)
    case unavailable(message: String)

    public var title: String {
        switch self {
        case .notDownloaded:
            "Not Downloaded"
        case .downloading:
            "Downloading"
        case .downloaded:
            "Downloaded"
        case .loading:
            "Loading"
        case .loaded:
            "Loaded"
        case .deleting:
            "Deleting"
        case .failed:
            "Error"
        case .unavailable:
            "Unavailable"
        }
    }

    public var progressValue: Double? {
        switch self {
        case let .downloading(progress):
            progress
        default:
            nil
        }
    }

    public var detailMessage: String? {
        switch self {
        case .failed(let message), .unavailable(let message):
            message
        default:
            nil
        }
    }
}

public struct LocalModelInventoryItem: Equatable, Sendable {
    public var modelID: String
    public var state: LocalModelState
    public var localFolderPath: String?

    public init(
        modelID: String,
        state: LocalModelState,
        localFolderPath: String? = nil
    ) {
        self.modelID = modelID
        self.state = state
        self.localFolderPath = localFolderPath
    }
}
