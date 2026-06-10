import AVFoundation
import Foundation

public enum AudioImportError: Error, LocalizedError {
    case unsupportedFileType(String)
    case undecodableAudio
    case conversionFailed(String)
    case copyFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedFileType(fileExtension):
            "Transcriptor only accepts \(SupportedImportFormat.allCases.map(\.fileExtensionLabel).joined(separator: ", ")) files. '\(fileExtension)' is not supported."
        case .undecodableAudio:
            "Transcriptor could not decode this audio file with AVFoundation."
        case let .conversionFailed(message):
            "Transcriptor could not convert this audio file to WAV: \(message)"
        case let .copyFailed(message):
            "Transcriptor could not copy the imported file: \(message)"
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

        let workingFileURL: URL
        if format.requiresWAVConversion {
            do {
                workingFileURL = try convertToWAV(
                    sourceURL: originalFileURL,
                    directory: layout.importWorkingDirectory()
                )
            } catch {
                return ImportedAudioPreparationResult(
                    displayName: sourceURL.lastPathComponent,
                    originalFileURL: originalFileURL,
                    workingFileURL: nil,
                    durationSeconds: 0,
                    fileSizeBytes: fileSizeBytes,
                    status: .failed,
                    errorMessage: (error as? AudioImportError)?.localizedDescription
                        ?? AudioImportError.conversionFailed(error.localizedDescription).localizedDescription
                )
            }
        } else {
            workingFileURL = originalFileURL
        }

        let durationSeconds = try decodableDuration(for: workingFileURL)
        return ImportedAudioPreparationResult(
            displayName: sourceURL.lastPathComponent,
            originalFileURL: originalFileURL,
            workingFileURL: workingFileURL,
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

    /// Decodes any CoreAudio-readable file (including Ogg Opus/Vorbis voice
    /// messages) and writes a 16-bit PCM WAV next to the original so all
    /// transcription providers consume one well-supported format.
    private func convertToWAV(sourceURL: URL, directory: URL) throws -> URL {
        let inputFile: AVAudioFile
        do {
            inputFile = try AVAudioFile(forReading: sourceURL)
        } catch {
            throw AudioImportError.undecodableAudio
        }

        let processingFormat = inputFile.processingFormat
        let outputURL = directory.appendingPathComponent(
            sourceURL.deletingPathExtension().lastPathComponent + ".wav",
            isDirectory: false
        )

        if fileManager.fileExists(atPath: outputURL.path) {
            try? fileManager.removeItem(at: outputURL)
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: processingFormat.sampleRate,
            AVNumberOfChannelsKey: processingFormat.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        do {
            let outputFile = try AVAudioFile(forWriting: outputURL, settings: outputSettings)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: 65_536) else {
                throw AudioImportError.conversionFailed("Could not allocate a conversion buffer.")
            }

            // CoreAudio reports an estimated length for Ogg inputs and reading
            // at the actual end of stream throws instead of returning an empty
            // buffer, so bound the loop explicitly and treat a tail-read error
            // after successful reads as EOF.
            var framesWritten: AVAudioFramePosition = 0
            while inputFile.framePosition < inputFile.length {
                do {
                    try inputFile.read(into: buffer)
                } catch {
                    if framesWritten > 0 {
                        break
                    }
                    throw error
                }
                if buffer.frameLength == 0 {
                    break
                }
                try outputFile.write(from: buffer)
                framesWritten += AVAudioFramePosition(buffer.frameLength)
            }

            guard framesWritten > 0 else {
                throw AudioImportError.conversionFailed("The file contains no decodable audio.")
            }
        } catch let error as AudioImportError {
            try? fileManager.removeItem(at: outputURL)
            throw error
        } catch {
            try? fileManager.removeItem(at: outputURL)
            throw AudioImportError.conversionFailed(error.localizedDescription)
        }

        return outputURL
    }
}
