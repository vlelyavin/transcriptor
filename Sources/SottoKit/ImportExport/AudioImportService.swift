import AVFoundation
import Foundation

public enum AudioImportError: Error, LocalizedError {
    case unsupportedFileType(String)
    case webMNotSupported
    case undecodableAudio
    case copyFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedFileType(fileExtension):
            "Sotto only accepts \(SupportedImportFormat.allCases.map(\.fileExtensionLabel).joined(separator: ", ")) files. '\(fileExtension)' is not supported."
        case .webMNotSupported:
            "WebM import is blocked because this build does not yet include a reliable decoder or transcoder for WebM audio."
        case .undecodableAudio:
            "Sotto could not decode this audio file with AVFoundation."
        case let .copyFailed(message):
            "Sotto could not copy the imported file: \(message)"
        }
    }
}

public struct ImportedAudioPreparationResult: Equatable, Sendable {
    public var displayName: String
    public var originalFileURL: URL
    public var workingFileURL: URL?
    public var durationSeconds: Int
    public var fileSizeBytes: Int64
    public var status: HistoryTranscriptionStatus
    public var errorMessage: String?
}

public struct AudioImportService {
    private let layout: AppStorageLayout
    private let fileManager: FileManager

    public init(
        layout: AppStorageLayout = AppStorageLayout(),
        fileManager: FileManager = .default
    ) {
        self.layout = layout
        self.fileManager = fileManager
    }

    public func prepareImport(from sourceURL: URL, date: Date = .now, identifier: UUID = UUID()) throws -> ImportedAudioPreparationResult {
        let fileExtension = sourceURL.pathExtension.lowercased()
        guard let format = SupportedImportFormat(rawValue: fileExtension) else {
            throw AudioImportError.unsupportedFileType(fileExtension.isEmpty ? sourceURL.lastPathComponent : fileExtension)
        }

        let originalFileURL = try managedImportURL(
            directory: layout.importOriginalsDirectory(),
            sourceURL: sourceURL,
            date: date,
            identifier: identifier
        )

        do {
            try copyReplacingIfNeeded(from: sourceURL, to: originalFileURL)
        } catch {
            throw AudioImportError.copyFailed(error.localizedDescription)
        }

        let fileSizeBytes = (try? fileSize(for: originalFileURL)) ?? 0

        if format == .webm {
            return ImportedAudioPreparationResult(
                displayName: sourceURL.lastPathComponent,
                originalFileURL: originalFileURL,
                workingFileURL: nil,
                durationSeconds: 0,
                fileSizeBytes: fileSizeBytes,
                status: .failed,
                errorMessage: AudioImportError.webMNotSupported.localizedDescription
            )
        }

        let durationSeconds = try decodableDuration(for: originalFileURL)
        return ImportedAudioPreparationResult(
            displayName: sourceURL.lastPathComponent,
            originalFileURL: originalFileURL,
            workingFileURL: originalFileURL,
            durationSeconds: durationSeconds,
            fileSizeBytes: fileSizeBytes,
            status: .pending,
            errorMessage: nil
        )
    }

    private func managedImportURL(
        directory: URL,
        sourceURL: URL,
        date: Date,
        identifier: UUID
    ) throws -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let timestamp = formatter.string(from: date).replacingOccurrences(of: ":", with: "-")
        let sanitizedBaseName = sourceURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let filename = "import-\(timestamp)-\(identifier.uuidString.prefix(8))-\(sanitizedBaseName).\(sourceURL.pathExtension.lowercased())"
        return directory.appendingPathComponent(filename, isDirectory: false)
    }

    private func copyReplacingIfNeeded(from sourceURL: URL, to destinationURL: URL) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    private func fileSize(for url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func decodableDuration(for url: URL) throws -> Int {
        do {
            let file = try AVAudioFile(forReading: url)
            let duration = Double(file.length) / file.processingFormat.sampleRate
            return Int(duration.rounded())
        } catch {
            throw AudioImportError.undecodableAudio
        }
    }
}
