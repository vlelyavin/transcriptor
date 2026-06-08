import Foundation

public enum RecordingStorageError: Error, LocalizedError {
    case invalidApplicationSupportDirectory

    public var errorDescription: String? {
        switch self {
        case .invalidApplicationSupportDirectory:
            "The Application Support directory could not be created."
        }
    }
}

public struct RecordingStorage {
    public let fileManager: FileManager
    private let layout: AppStorageLayout

    public init(
        fileManager: FileManager = .default,
        layout: AppStorageLayout = AppStorageLayout()
    ) {
        self.fileManager = fileManager
        self.layout = layout
    }

    public func applicationSupportDirectory() throws -> URL {
        do {
            return try layout.recordingsDirectory()
        } catch {
            throw RecordingStorageError.invalidApplicationSupportDirectory
        }
    }

    public func nextRecordingURL(
        date: Date = .now,
        identifier: UUID = UUID()
    ) throws -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let timestamp = formatter.string(from: date)
            .replacingOccurrences(of: ":", with: "-")
        let filename = "recording-\(timestamp)-\(identifier.uuidString.prefix(8)).wav"
        return try applicationSupportDirectory().appendingPathComponent(filename, isDirectory: false)
    }

    public func fileSize(for url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    public func removeIfPresent(at url: URL) {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try? fileManager.removeItem(at: url)
    }
}
