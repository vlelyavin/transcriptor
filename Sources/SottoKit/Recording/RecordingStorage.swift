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

public struct RecordingStorage: Sendable {
    public let fileManager: FileManager
    private let applicationSupportURLProvider: @Sendable () -> URL?

    public init(
        fileManager: FileManager = .default,
        applicationSupportURLProvider: @escaping @Sendable () -> URL? = {
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        }
    ) {
        self.fileManager = fileManager
        self.applicationSupportURLProvider = applicationSupportURLProvider
    }

    public func applicationSupportDirectory() throws -> URL {
        guard let baseDirectory = applicationSupportURLProvider() else {
            throw RecordingStorageError.invalidApplicationSupportDirectory
        }

        let directory = baseDirectory
            .appendingPathComponent("Sotto", isDirectory: true)
            .appendingPathComponent("Recordings", isDirectory: true)

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        return directory
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
