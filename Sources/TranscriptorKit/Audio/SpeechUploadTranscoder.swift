import Foundation
import AVFoundation

/// Converts a recorded WAV to a 16 kHz mono PCM WAV suitable for cloud
/// speech-to-text upload. Whisper-class engines all operate on 16 kHz
/// input, so this is lossless for transcription quality while shrinking
/// typical 48 kHz stereo captures ~6×, keeping direct uploads far below
/// the providers' 25 MB limit.
public enum SpeechUploadTranscoder {

    /// Returns a 16 kHz mono WAV URL for upload. The output file is
    /// created next to the input; the original recording is untouched.
    /// If the source is already ≤ 16 kHz mono, returns the input URL.
    public static func speechBandMonoWav(from sourceURL: URL) throws -> URL {
        let sourceFile = try AVAudioFile(forReading: sourceURL)
        let srcFormat = sourceFile.processingFormat

        // Already speech-band mono? Use as-is.
        if srcFormat.sampleRate <= 16_500 && srcFormat.channelCount == 1 {
            return sourceURL
        }

        let outFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!

        let outURL = sourceURL.deletingLastPathComponent().appendingPathComponent(
            "upload-\(UUID().uuidString.prefix(8)).wav"
        )

        guard let converter = AVAudioConverter(from: srcFormat, to: outFormat) else {
            throw TranscriptionError.providerUnavailable("Audio conversion is not supported for this input format.")
        }

        let outFile = try AVAudioFile(
            forWriting: outURL,
            settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
            ]
        )

        let chunkFrames: AVAudioFrameCount = 32768
        guard let srcBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: chunkFrames) else {
            throw TranscriptionError.providerUnavailable("Audio conversion buffer allocation failed.")
        }

        var wroteFinalChunk = false
        while !wroteFinalChunk {
            let outBuffer = makeBuffer(for: outFormat, capacity: chunkFrames * 2)
            var conversionError: NSError?
            let status = converter.convert(to: outBuffer, error: &conversionError) { _, outStatus in
                do {
                    try sourceFile.read(into: srcBuffer)
                } catch {
                    outStatus.pointee = .endOfStream
                    wroteFinalChunk = true
                    return nil
                }
                if srcBuffer.frameLength > 0 {
                    outStatus.pointee = .haveData
                    return srcBuffer
                }
                outStatus.pointee = .endOfStream
                wroteFinalChunk = true
                return nil
            }
            if let conversionError {
                throw conversionError
            }
            if status == .haveData, outBuffer.frameLength > 0 {
                try outFile.write(from: outBuffer)
            }
        }

        return outURL
    }

    private static func makeBuffer(for format: AVAudioFormat, capacity: AVAudioFrameCount) -> AVAudioPCMBuffer {
        AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity)!
    }
}
