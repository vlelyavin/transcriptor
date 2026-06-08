import Foundation

public enum AppStorageLayoutError: Error, LocalizedError {
    case invalidApplicationSupportDirectory

    public var errorDescription: String? {
        switch self {
        case .invalidApplicationSupportDirectory:
            "The Application Support directory for Sotto could not be created."
        }
    }
}

public struct ManagedStorageUsage: Equatable, Sendable {
    public var historyBytes: Int64
    public var audioBytes: Int64
    public var metadataBytes: Int64
    public var modelBytes: Int64

    public init(
        historyBytes: Int64 = 0,
        audioBytes: Int64 = 0,
        metadataBytes: Int64 = 0,
        modelBytes: Int64 = 0
    ) {
        self.historyBytes = historyBytes
        self.audioBytes = audioBytes
        self.metadataBytes = metadataBytes
        self.modelBytes = modelBytes
    }

    public var totalManagedBytes: Int64 {
        historyBytes + audioBytes + metadataBytes
    }

    public var totalIncludingModelsBytes: Int64 {
        totalManagedBytes + modelBytes
    }
}

public struct AppStorageLayout {
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

    public func rootDirectory() throws -> URL {
        guard let applicationSupportURL = applicationSupportURLProvider() else {
            throw AppStorageLayoutError.invalidApplicationSupportDirectory
        }

        let rootURL = applicationSupportURL.appendingPathComponent("Sotto", isDirectory: true)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
        return rootURL
    }

    public func recordingsDirectory() throws -> URL {
        try directory(named: "Recordings")
    }

    public func importsDirectory() throws -> URL {
        try directory(named: "Imports")
    }

    public func importOriginalsDirectory() throws -> URL {
        try directory(at: try importsDirectory().appendingPathComponent("Originals", isDirectory: true))
    }

    public func importWorkingDirectory() throws -> URL {
        try directory(at: try importsDirectory().appendingPathComponent("Working", isDirectory: true))
    }

    public func exportsDirectory() throws -> URL {
        try directory(named: "Exports")
    }

    public func metadataDirectory() throws -> URL {
        try directory(named: "Metadata")
    }

    public func modelsDirectory() throws -> URL {
        try directory(named: "Models")
    }

    public func historyStoreURL() throws -> URL {
        try metadataDirectory().appendingPathComponent("History.store", isDirectory: false)
    }

    public func managedStorageUsage() throws -> ManagedStorageUsage {
        let recordingsBytes = try directorySizeIfPresent(recordingsDirectory)
        let importsBytes = try directorySizeIfPresent(importsDirectory)
        let exportsBytes = try directorySizeIfPresent(exportsDirectory)
        let metadataBytes = try directorySizeIfPresent(metadataDirectory)
        let modelBytes = try directorySizeIfPresent(modelsDirectory)

        return ManagedStorageUsage(
            historyBytes: exportsBytes,
            audioBytes: recordingsBytes + importsBytes,
            metadataBytes: metadataBytes,
            modelBytes: modelBytes
        )
    }

    public func isManagedFile(_ url: URL) -> Bool {
        guard let rootURL = try? rootDirectory() else {
            return false
        }

        let managedPath = rootURL.standardizedFileURL.path
        let candidatePath = url.standardizedFileURL.path
        return candidatePath.hasPrefix(managedPath)
    }

    @discardableResult
    public func removeManagedFileIfPresent(atPath path: String?) -> Bool {
        guard let path else {
            return false
        }

        let url = URL(fileURLWithPath: path)
        guard isManagedFile(url) else {
            return false
        }

        guard fileManager.fileExists(atPath: url.path) else {
            return false
        }

        try? fileManager.removeItem(at: url)
        return true
    }

    private func directory(named name: String) throws -> URL {
        try directory(at: try rootDirectory().appendingPathComponent(name, isDirectory: true))
    }

    private func directory(at url: URL) throws -> URL {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        return url
    }

    private func directorySizeIfPresent(_ directoryProvider: () throws -> URL) throws -> Int64 {
        let directoryURL = try directoryProvider()
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return 0
        }

        let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        var total: Int64 = 0
        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true else {
                continue
            }
            total += Int64(values.fileSize ?? 0)
        }

        return total
    }
}
