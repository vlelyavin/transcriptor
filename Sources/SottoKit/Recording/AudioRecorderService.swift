import Accelerate
import AVFoundation
import Foundation

public enum AudioRecorderError: Error, LocalizedError {
    case recordingAlreadyInProgress
    case noActiveRecording
    case microphonePermissionDenied
    case unableToCreateOutputFile
    case failedToStartEngine(String)
    case failedToStopRecording(String)

    public var errorDescription: String? {
        switch self {
        case .recordingAlreadyInProgress:
            "Recording is already in progress."
        case .noActiveRecording:
            "There is no active recording to stop."
        case .microphonePermissionDenied:
            "Microphone access is required to record audio."
        case .unableToCreateOutputFile:
            "The recorder could not create an output file."
        case let .failedToStartEngine(message):
            "The recorder failed to start: \(message)"
        case let .failedToStopRecording(message):
            "The recorder failed to stop: \(message)"
        }
    }
}

public protocol AudioRecorderServing: AnyObject {
    var onLevelsDidChange: ((AudioLevelSnapshot) -> Void)? { get set }
    var isRecording: Bool { get }

    func authorizationStatus() -> MicrophonePermissionStatus
    func requestPermission() async -> Bool
    func startRecording() throws -> URL
    func stopRecording() throws -> RecordedAudioAsset
    func cancelRecording() throws
}

public final class AudioRecorderService: AudioRecorderServing {
    public var onLevelsDidChange: ((AudioLevelSnapshot) -> Void)?
    public private(set) var isRecording = false

    private let storage: RecordingStorage
    private var engine: AVAudioEngine?
    private var outputFile: AVAudioFile?
    private var outputURL: URL?
    private var recordingStartedAt: Date?
    private var sampleRate: Double = 16_000
    private var totalFramesRecorded: AVAudioFramePosition = 0
    private var lastLevels = AudioLevelSnapshot.zero

    public init(storage: RecordingStorage = RecordingStorage()) {
        self.storage = storage
    }

    public func authorizationStatus() -> MicrophonePermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            .granted
        case .denied:
            .denied
        case .restricted:
            .restricted
        case .notDetermined:
            .undetermined
        @unknown default:
            .undetermined
        }
    }

    public func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    public func startRecording() throws -> URL {
        guard !isRecording else {
            throw AudioRecorderError.recordingAlreadyInProgress
        }

        guard authorizationStatus() == .granted else {
            throw AudioRecorderError.microphonePermissionDenied
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        sampleRate = inputFormat.sampleRate

        let outputURL = try storage.nextRecordingURL()
        guard let file = try? AVAudioFile(forWriting: outputURL, settings: inputFormat.settings) else {
            throw AudioRecorderError.unableToCreateOutputFile
        }

        recordingStartedAt = .now
        totalFramesRecorded = 0
        lastLevels = .zero
        self.outputURL = outputURL
        self.outputFile = file
        self.engine = engine

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2_048, format: inputFormat) { [weak self] buffer, _ in
            guard let self, let outputFile = self.outputFile else {
                return
            }

            do {
                try outputFile.write(from: buffer)
                self.totalFramesRecorded += AVAudioFramePosition(buffer.frameLength)
            } catch {
                DispatchQueue.main.async {
                    self.onLevelsDidChange?(self.lastLevels)
                }
                return
            }

            let analyzedLevels = Self.analyzeLevels(from: buffer, previous: self.lastLevels)
            self.lastLevels = analyzedLevels

            DispatchQueue.main.async {
                self.onLevelsDidChange?(analyzedLevels)
            }
        }

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            resetSession(deleteOutput: true)
            throw AudioRecorderError.failedToStartEngine(error.localizedDescription)
        }

        isRecording = true
        return outputURL
    }

    public func stopRecording() throws -> RecordedAudioAsset {
        guard isRecording, let outputURL, let recordingStartedAt else {
            throw AudioRecorderError.noActiveRecording
        }

        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()

        let durationSeconds = Int((Double(totalFramesRecorded) / sampleRate).rounded())
        let fileSizeBytes: Int64

        do {
            fileSizeBytes = try storage.fileSize(for: outputURL)
        } catch {
            resetSession(deleteOutput: false)
            throw AudioRecorderError.failedToStopRecording(error.localizedDescription)
        }

        resetSession(deleteOutput: false)

        return RecordedAudioAsset(
            url: outputURL,
            createdAt: recordingStartedAt,
            durationSeconds: durationSeconds,
            fileSizeBytes: fileSizeBytes
        )
    }

    public func cancelRecording() throws {
        guard isRecording else {
            throw AudioRecorderError.noActiveRecording
        }

        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        resetSession(deleteOutput: true)
    }

    private func resetSession(deleteOutput: Bool) {
        if deleteOutput, let outputURL {
            storage.removeIfPresent(at: outputURL)
        }

        engine = nil
        outputFile = nil
        outputURL = nil
        recordingStartedAt = nil
        totalFramesRecorded = 0
        isRecording = false
        lastLevels = .zero
        onLevelsDidChange?(.zero)
    }

    private static func analyzeLevels(
        from buffer: AVAudioPCMBuffer,
        previous: AudioLevelSnapshot
    ) -> AudioLevelSnapshot {
        guard
            let channelData = buffer.floatChannelData?.pointee,
            buffer.frameLength > 0
        else {
            return .zero
        }

        let sampleCount = Int(buffer.frameLength)
        let samples = UnsafeBufferPointer(start: channelData, count: sampleCount)

        var rms: Float = 0
        vDSP_rmsqv(samples.baseAddress!, 1, &rms, vDSP_Length(sampleCount))

        var peak: Float = 0
        vDSP_maxmgv(samples.baseAddress!, 1, &peak, vDSP_Length(sampleCount))

        let bars = energyBars(from: Array(samples), count: previous.bars.count)
        return smoothedSnapshot(
            raw: AudioLevelSnapshot(rms: min(rms * 4, 1), peak: min(peak * 2, 1), bars: bars),
            previous: previous
        )
    }

    private static func energyBars(from samples: [Float], count: Int) -> [Float] {
        guard count > 0, !samples.isEmpty else {
            return []
        }

        let chunkSize = max(samples.count / count, 1)
        return stride(from: 0, to: samples.count, by: chunkSize).prefix(count).map { start in
            let end = min(start + chunkSize, samples.count)
            let slice = Array(samples[start..<end])
            var rms: Float = 0
            slice.withUnsafeBufferPointer { pointer in
                vDSP_rmsqv(pointer.baseAddress!, 1, &rms, vDSP_Length(pointer.count))
            }
            return min(rms * 5, 1)
        }
    }

    private static func smoothedSnapshot(
        raw: AudioLevelSnapshot,
        previous: AudioLevelSnapshot
    ) -> AudioLevelSnapshot {
        let smoothing: Float = 0.72
        let rms = previous.rms * smoothing + raw.rms * (1 - smoothing)
        let peak = previous.peak * smoothing + raw.peak * (1 - smoothing)
        let bars = zip(previous.bars, raw.bars).map { oldValue, newValue in
            oldValue * smoothing + newValue * (1 - smoothing)
        }
        return AudioLevelSnapshot(rms: rms, peak: peak, bars: bars)
    }
}
