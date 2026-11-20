import AVFoundation
import Foundation

public enum AudioTranscodeError: Error, LocalizedError, Equatable {
    case undecodableAudio(String)
    case emptyAudio
    case conversionFailed(String)
    case unexpectedOutputFormat(String)
    case durationMismatch(expected: Double, actual: Double)

    public var errorDescription: String? {
        switch self {
        case let .undecodableAudio(message):
            "Transcriptor could not read this audio file: \(message)"
        case .emptyAudio:
            "The audio file contains no decodable audio."
        case let .conversionFailed(message):
            "Transcriptor could not convert this audio file: \(message)"
        case let .unexpectedOutputFormat(message):
            "The converted audio has an unexpected format: \(message)"
        case let .durationMismatch(expected, actual):
            "The converted audio is \(String(format: "%.2f", actual))s long but the source is \(String(format: "%.2f", expected))s. The original was kept."
        }
    }

    public var isRecoverable: Bool {
        if case .durationMismatch = self {
            return true
        }
        return false
    }
}

/// The one audio format Transcriptor stores and uploads: 16 kHz mono.
///
/// Speech models (Whisper, Parakeet, every cloud transcription API) resample to
/// 16 kHz mono internally, so keeping a 44.1/48 kHz stereo capture on disk only
/// multiplies the footprint by ~5x for zero recognition benefit. Recordings are
/// captured at the device format for reliability (the AirPods/HFP route
/// negotiates its own rate) and converted afterwards.
public enum SpeechAudioFormat {
    public static let sampleRate: Double = 16_000
    public static let channelCount: AVAudioChannelCount = 1
    public static let archiveBitRate = 32_000
    public static let uploadFileExtension = "wav"
    public static let archiveFileExtension = "m4a"
}

/// Converts arbitrary Core Audio-readable files into the two shapes Transcriptor
/// needs:
///
/// * an **upload copy** — a throwaway 16 kHz mono 16-bit WAV that cloud
///   providers receive instead of a multi-megabyte device-format capture, and
/// * an **archive copy** — a 16 kHz mono AAC `.m4a` that replaces the original
///   WAV once the transcript exists.
///
/// Conversion is streaming (64 KiB chunks), so a long dictation never has to fit
/// in memory, and the source file is never modified.
public struct SpeechUploadTranscoder {
    public let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Whether `url` already is 16 kHz mono — in which case there is nothing to
    /// gain from re-encoding it for upload.
    public func isCanonicalSpeechFile(_ url: URL) -> Bool {
        guard let file = try? AVAudioFile(forReading: url) else {
            return false
        }
        let format = file.processingFormat
        return format.sampleRate == SpeechAudioFormat.sampleRate
            && format.channelCount == SpeechAudioFormat.channelCount
    }

    /// Writes a 16 kHz mono WAV copy of `sourceURL` into a scratch directory and
    /// returns it, or `nil` when the source is already canonical (the caller may
    /// upload it unchanged). The caller owns the returned file and must delete it.
    public func makeUploadCopy(of sourceURL: URL) throws -> URL? {
        if isCanonicalSpeechFile(sourceURL) {
            return nil
        }

        let directory = try uploadScratchDirectory()
        let destinationURL = directory.appendingPathComponent(
            "upload-\(UUID().uuidString.prefix(8)).\(SpeechAudioFormat.uploadFileExtension)",
            isDirectory: false
        )

        do {
            try transcode(
                from: sourceURL,
                to: destinationURL,
                settings: wavSettings()
            )
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            throw error
        }

        return destinationURL
    }

    /// Writes a 16 kHz mono AAC `.m4a` version of `sourceURL` to `destinationURL`.
    /// Any partially written destination is removed when conversion fails.
    public func writeArchiveCopy(of sourceURL: URL, to destinationURL: URL) throws {
        do {
            try transcode(
                from: sourceURL,
                to: destinationURL,
                settings: aacSettings()
            )
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            throw error
        }
    }

    // MARK: - Conversion

    private func transcode(
        from sourceURL: URL,
        to destinationURL: URL,
        settings: [String: Any]
    ) throws {
        let inputFile: AVAudioFile
        do {
            inputFile = try AVAudioFile(forReading: sourceURL)
        } catch {
            throw AudioTranscodeError.undecodableAudio(error.localizedDescription)
        }

        let inputFormat = inputFile.processingFormat
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw AudioTranscodeError.undecodableAudio("the file reports an invalid sample rate or channel count")
        }
        guard inputFile.length > 0 else {
            throw AudioTranscodeError.emptyAudio
        }

        let inputDuration = Double(inputFile.length) / inputFormat.sampleRate

        try? fileManager.removeItem(at: destinationURL)
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // Writing happens in its own function: `AVAudioFile` finalizes a WAV
        // header / m4a moov atom only when the writer is released, so the
        // verification below must run after the file is closed, not while it is
        // still in scope.
        let framesWritten = try writeOutput(
            inputFile: inputFile,
            inputFormat: inputFormat,
            destinationURL: destinationURL,
            settings: settings
        )

        guard framesWritten > 0 else {
            try? fileManager.removeItem(at: destinationURL)
            throw AudioTranscodeError.emptyAudio
        }

        // Validate the result before anyone deletes the source: the encoder must
        // have produced a real 16 kHz mono file of roughly the same length.
        let writtenFile: AVAudioFile
        do {
            writtenFile = try AVAudioFile(forReading: destinationURL)
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            throw AudioTranscodeError.conversionFailed("the converted file could not be reopened: \(error.localizedDescription)")
        }

        let writtenFormat = writtenFile.processingFormat
        guard writtenFormat.sampleRate == SpeechAudioFormat.sampleRate,
              writtenFormat.channelCount == SpeechAudioFormat.channelCount else {
            try? fileManager.removeItem(at: destinationURL)
            throw AudioTranscodeError.unexpectedOutputFormat(
                "\(writtenFormat.sampleRate) Hz / \(writtenFormat.channelCount) ch"
            )
        }

        let outputDuration = Double(writtenFile.length) / writtenFormat.sampleRate
        let tolerance = max(0.35, inputDuration * 0.02)
        guard abs(outputDuration - inputDuration) <= tolerance else {
            try? fileManager.removeItem(at: destinationURL)
            throw AudioTranscodeError.durationMismatch(expected: inputDuration, actual: outputDuration)
        }
    }

    /// Creates the destination file, streams the conversion into it, and releases
    /// it (finalizing the container) before returning.
    private func writeOutput(
        inputFile: AVAudioFile,
        inputFormat: AVAudioFormat,
        destinationURL: URL,
        settings: [String: Any]
    ) throws -> AVAudioFramePosition {
        let outputFile: AVAudioFile
        do {
            outputFile = try AVAudioFile(forWriting: destinationURL, settings: settings)
        } catch {
            throw AudioTranscodeError.conversionFailed(error.localizedDescription)
        }

        let outputFormat = outputFile.processingFormat
        let needsConversion = outputFormat.sampleRate != inputFormat.sampleRate
            || outputFormat.channelCount != inputFormat.channelCount

        if needsConversion {
            return try convert(
                inputFile: inputFile,
                inputFormat: inputFormat,
                outputFile: outputFile,
                outputFormat: outputFormat
            )
        }

        return try copy(
            inputFile: inputFile,
            inputFormat: inputFormat,
            outputFile: outputFile
        )
    }

    /// Straight chunked copy when no format change is required.
    private func copy(
        inputFile: AVAudioFile,
        inputFormat: AVAudioFormat,
        outputFile: AVAudioFile
    ) throws -> AVAudioFramePosition {
        let chunkFrames: AVAudioFrameCount = 65_536
        guard let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: chunkFrames) else {
            throw AudioTranscodeError.conversionFailed("could not allocate a conversion buffer")
        }

        var framesWritten: AVAudioFramePosition = 0
        while true {
            do {
                try inputFile.read(into: buffer, frameCount: chunkFrames)
            } catch {
                if framesWritten > 0 {
                    break
                }
                throw AudioTranscodeError.conversionFailed(error.localizedDescription)
            }

            if buffer.frameLength == 0 {
                break
            }

            try outputFile.write(from: buffer)
            framesWritten += AVAudioFramePosition(buffer.frameLength)
        }

        return framesWritten
    }

    /// Sample-rate and channel-count conversion through `AVAudioConverter`.
    private func convert(
        inputFile: AVAudioFile,
        inputFormat: AVAudioFormat,
        outputFile: AVAudioFile,
        outputFormat: AVAudioFormat
    ) throws -> AVAudioFramePosition {
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioTranscodeError.conversionFailed("no converter for \(inputFormat.sampleRate) Hz/\(inputFormat.channelCount) ch → \(outputFormat.sampleRate) Hz/\(outputFormat.channelCount) ch")
        }

        let chunkFrames: AVAudioFrameCount = 65_536
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: chunkFrames) else {
            throw AudioTranscodeError.conversionFailed("could not allocate an input buffer")
        }

        // The output buffer is sized for the worst case: the full chunk after
        // upsampling plus converter latency.
        let outputCapacity = AVAudioFrameCount(
            (Double(chunkFrames) * (outputFormat.sampleRate / inputFormat.sampleRate)).rounded(.up)
        ) + 4_096
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
            throw AudioTranscodeError.conversionFailed("could not allocate an output buffer")
        }

        var inputExhausted = false
        var framesWritten: AVAudioFramePosition = 0
        var conversionError: NSError?

        while true {
            outputBuffer.frameLength = 0
            conversionError = nil

            let status = converter.convert(to: outputBuffer, error: &conversionError) { _, inputStatus in
                guard !inputExhausted else {
                    inputStatus.pointee = .endOfStream
                    return nil
                }

                do {
                    try inputFile.read(into: inputBuffer, frameCount: chunkFrames)
                } catch {
                    // A tail-read failure after successful reads is EOF, matching
                    // the import converter's handling of estimated lengths.
                    inputExhausted = true
                    inputStatus.pointee = .endOfStream
                    return nil
                }

                if inputBuffer.frameLength == 0 {
                    inputExhausted = true
                    inputStatus.pointee = .endOfStream
                    return nil
                }

                inputStatus.pointee = .haveData
                return inputBuffer
            }

            if let conversionError {
                throw AudioTranscodeError.conversionFailed(conversionError.localizedDescription)
            }

            if outputBuffer.frameLength > 0 {
                try outputFile.write(from: outputBuffer)
                framesWritten += AVAudioFramePosition(outputBuffer.frameLength)
            }

            switch status {
            case .error:
                throw AudioTranscodeError.conversionFailed("the audio converter reported an error")
            case .endOfStream:
                return framesWritten
            case .inputRanDry:
                if inputExhausted {
                    return framesWritten
                }
            case .haveData:
                break
            @unknown default:
                return framesWritten
            }
        }
    }

    // MARK: - Settings and paths

    private func wavSettings() -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: SpeechAudioFormat.sampleRate,
            AVNumberOfChannelsKey: Int(SpeechAudioFormat.channelCount),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
    }

    private func aacSettings() -> [String: Any] {
        // `AVEncoderBitRateKey` only — adding `AVEncoderAudioQualityKey` makes
        // the encoder override the requested rate (a "medium" quality 16 kHz mono
        // file came out at ~60 kbps instead of 32 kbps).
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: SpeechAudioFormat.sampleRate,
            AVNumberOfChannelsKey: Int(SpeechAudioFormat.channelCount),
            AVEncoderBitRateKey: SpeechAudioFormat.archiveBitRate,
        ]
    }

    private func uploadScratchDirectory() throws -> URL {
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("TranscriptorUploads", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        pruneStaleUploadCopies(in: directory)
        return directory
    }

    /// Upload copies are deleted as soon as the request finishes; this sweeps up
    /// the ones left behind by a crash or a force-quit so the temp directory does
    /// not accumulate audio the user thinks is gone.
    private func pruneStaleUploadCopies(in directory: URL) {
        let cutoff = Date().addingTimeInterval(-86_400)
        let contents = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for url in contents where url.pathExtension.lowercased() == SpeechAudioFormat.uploadFileExtension {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                ?? Date.distantPast
            if modified < cutoff {
                try? fileManager.removeItem(at: url)
            }
        }
    }
}
