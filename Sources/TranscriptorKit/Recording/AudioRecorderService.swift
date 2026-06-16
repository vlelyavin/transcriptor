import Accelerate
import AVFoundation
import Foundation
import os

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

public protocol AudioRecorderServing: AnyObject, Sendable {
    var onLevelsDidChange: (@MainActor (AudioLevelSnapshot) -> Void)? { get set }
    /// Called when an in-progress recording fails on its own — most importantly
    /// when the engine starts but no audio buffers ever arrive from the selected
    /// input (a common AirPods / Bluetooth route failure). Lets the controller
    /// surface a clear, actionable error instead of leaving a frozen overlay.
    var onRecordingError: (@MainActor (Error) -> Void)? { get set }
    var isRecording: Bool { get }

    func authorizationStatus() -> MicrophonePermissionStatus
    func requestPermission() async -> Bool
    func startRecording() throws -> URL
    func stopRecording() throws -> RecordedAudioAsset
    func cancelRecording() throws
}

public final class AudioRecorderService: AudioRecorderServing, @unchecked Sendable {
    public var onLevelsDidChange: (@MainActor (AudioLevelSnapshot) -> Void)?
    public var onRecordingError: (@MainActor (Error) -> Void)?
    public private(set) var isRecording = false

    private let storage: RecordingStorage
    private var engine: AVAudioEngine?
    private var outputFile: AVAudioFile?
    private var outputURL: URL?
    private var recordingStartedAt: Date?
    private var sampleRate: Double = 16_000
    private var totalFramesRecorded: AVAudioFramePosition = 0
    // Touched only on the real-time audio thread; carries smoothing continuity
    // between buffers.
    private var lastLevels = AudioLevelSnapshot.zero

    // The audio tap fires on a real-time background thread at the hardware's
    // buffer cadence (anywhere from ~10 to ~90 Hz, and irregular). Driving the
    // SwiftUI meter directly off that — one main-actor `Task` per buffer — ties
    // render cadence to buffer cadence and is what made the meter lag, show
    // stale data, and visibly "stick".
    //
    // Instead the tap does the minimum: store the freshest snapshot under a
    // lock. A single long-lived main-actor "pump" (`levelPump`) then publishes
    // that snapshot at a steady 30 Hz. The pump always fires and always reads
    // the latest value, so the meter can never fall behind or freeze, and the
    // real-time thread never spawns tasks or floods the main actor.
    private let levelLock = NSLock()
    private var latestLevels = AudioLevelSnapshot.zero
    private var levelPump: Task<Void, Never>?

    private let log = Logger(subsystem: "com.vlelyavin.Transcriptor", category: "audio")
    // `didReceiveBuffer` / `bufferCount` are guarded by `levelLock`. They let the
    // start-up watchdog detect the "engine started but no audio ever arrives"
    // failure that AirPods / Bluetooth routes hit, and feed the diagnostic logs.
    private var didReceiveBuffer = false
    private var bufferCount = 0
    private var bufferWatchdog: Task<Void, Never>?
    private var configChangeObserver: NSObjectProtocol?

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
        // Use the input node's OUTPUT format for both the file and the tap — NOT
        // its `inputFormat`. For the built-in mic the two are identical, which is
        // why the old code worked there. But for Bluetooth devices (AirPods run
        // the mic in low-rate HFP mode) the hardware input format and the format
        // the node actually delivers to the graph DIFFER, so installing a tap
        // with `inputFormat` throws a format-mismatch and `engine.start()` fails —
        // the "system was unable to record your voice" error with AirPods. The
        // output format is, by definition, what the tap delivers, so it always
        // matches.
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        let inputDeviceName = AVCaptureDevice.default(for: .audio)?.localizedName ?? "unknown"
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        log.notice("startRecording: input=\(inputDeviceName, privacy: .public) tap=\(recordingFormat.sampleRate, privacy: .public)Hz/\(recordingFormat.channelCount, privacy: .public)ch hw=\(hardwareFormat.sampleRate, privacy: .public)Hz/\(hardwareFormat.channelCount, privacy: .public)ch")

        // A just-connected or mid-route-change device can momentarily report a
        // zero sample rate / channel count. Recording with that yields an invalid
        // file and a failed start, so surface a clear, actionable message instead
        // of the opaque engine error.
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            throw AudioRecorderError.failedToStartEngine(
                "The audio input isn’t ready yet. If you just connected AirPods or another device, wait a second and try again."
            )
        }

        sampleRate = recordingFormat.sampleRate

        let outputURL = try storage.nextRecordingURL()
        guard let file = try? AVAudioFile(forWriting: outputURL, settings: recordingFormat.settings) else {
            throw AudioRecorderError.unableToCreateOutputFile
        }

        recordingStartedAt = .now
        totalFramesRecorded = 0
        lastLevels = .zero
        self.outputURL = outputURL
        self.outputFile = file
        self.engine = engine
        resetBufferTracking()
        installConfigChangeObserver(for: engine)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self, let outputFile = self.outputFile else {
                return
            }

            self.markBufferReceived()

            do {
                try outputFile.write(from: buffer)
                self.totalFramesRecorded += AVAudioFramePosition(buffer.frameLength)
            } catch {
                self.storeLatestLevels(self.lastLevels)
                return
            }

            let analyzedLevels = Self.analyzeLevels(from: buffer, previous: self.lastLevels)
            self.lastLevels = analyzedLevels
            self.storeLatestLevels(analyzedLevels)
        }

        // Pre-allocate engine resources before starting. This both surfaces
        // configuration problems early and smooths the first start on Bluetooth
        // routes, which otherwise occasionally fail cold.
        engine.prepare()

        do {
            try engine.start()
        } catch {
            log.error("engine.start() failed: \(error.localizedDescription, privacy: .public)")
            inputNode.removeTap(onBus: 0)
            resetSession(deleteOutput: true)
            throw AudioRecorderError.failedToStartEngine(error.localizedDescription)
        }

        isRecording = true
        startLevelPump()
        startBufferWatchdog()
        log.notice("engine started; recording to \(outputURL.lastPathComponent, privacy: .public)")
        return outputURL
    }

    public func stopRecording() throws -> RecordedAudioAsset {
        guard isRecording, let outputURL, let recordingStartedAt else {
            throw AudioRecorderError.noActiveRecording
        }

        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        log.notice("stopRecording: frames=\(self.totalFramesRecorded, privacy: .public) buffers=\(self.bufferCount, privacy: .public)")

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
        stopLevelPump()
        bufferWatchdog?.cancel()
        bufferWatchdog = nil
        if let configChangeObserver {
            NotificationCenter.default.removeObserver(configChangeObserver)
            self.configChangeObserver = nil
        }

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

        levelLock.lock()
        latestLevels = .zero
        didReceiveBuffer = false
        bufferCount = 0
        levelLock.unlock()
    }

    /// Records that the tap delivered a buffer (called on the real-time audio
    /// thread). The first one cancels the start-up watchdog's failure path.
    private func markBufferReceived() {
        levelLock.lock()
        let isFirst = !didReceiveBuffer
        didReceiveBuffer = true
        bufferCount += 1
        levelLock.unlock()
        if isFirst {
            log.notice("first audio buffer received")
        }
    }

    private func hasReceivedBuffer() -> Bool {
        levelLock.lock()
        defer { levelLock.unlock() }
        return didReceiveBuffer
    }

    private func resetBufferTracking() {
        levelLock.lock()
        didReceiveBuffer = false
        bufferCount = 0
        levelLock.unlock()
    }

    private func installConfigChangeObserver(for engine: AVAudioEngine) {
        if let configChangeObserver {
            NotificationCenter.default.removeObserver(configChangeObserver)
        }
        // A Bluetooth route flip (e.g. AirPods switching to the HFP mic profile)
        // posts this and can silently stop the input. Logging it makes such a
        // stall visible in the diagnostics instead of looking like a freeze.
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.log.notice("audio route/configuration changed mid-session (AVAudioEngineConfigurationChange)")
        }
    }

    /// Guards against the "engine started but no audio ever arrives" failure —
    /// the typical AirPods / Bluetooth symptom where the overlay sits on
    /// "Listening…" forever. If no tap buffer lands shortly after start, stop and
    /// surface an actionable error rather than leaving a frozen overlay.
    private func startBufferWatchdog() {
        bufferWatchdog?.cancel()
        bufferWatchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1_500))
            guard let self, !Task.isCancelled, self.isRecording, !self.hasReceivedBuffer() else {
                return
            }

            let deviceName = AVCaptureDevice.default(for: .audio)?.localizedName ?? "the selected input device"
            self.log.error("watchdog: no audio buffers 1.5s after start from \(deviceName, privacy: .public)")
            self.engine?.inputNode.removeTap(onBus: 0)
            self.engine?.stop()
            let onError = self.onRecordingError
            self.resetSession(deleteOutput: true)
            onError?(AudioRecorderError.failedToStartEngine(
                "No audio is reaching Transcriptor from \(deviceName). If you’re using AirPods or another Bluetooth mic, select it under System Settings ▸ Sound ▸ Input (or switch to the built-in microphone), then try again."
            ))
        }
    }

    /// Stores the freshest level snapshot for the pump to publish. Safe to call
    /// from the real-time audio thread: it only takes a brief lock and never
    /// allocates or hops actors.
    private func storeLatestLevels(_ snapshot: AudioLevelSnapshot) {
        levelLock.lock()
        latestLevels = snapshot
        levelLock.unlock()
    }

    /// Publishes the latest captured levels to the UI at a steady 30 Hz. A
    /// single long-lived task — never one per buffer — so the meter tracks the
    /// input smoothly and can never stall behind a backlog of per-buffer hops.
    private func startLevelPump() {
        levelPump?.cancel()
        levelPump = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.onLevelsDidChange?(self.readLatestLevels())
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    /// Synchronous, lock-guarded read of the freshest snapshot. Kept separate
    /// from the async pump because `NSLock` may not be taken across an `await`.
    private func readLatestLevels() -> AudioLevelSnapshot {
        levelLock.lock()
        defer { levelLock.unlock() }
        return latestLevels
    }

    private func stopLevelPump() {
        levelPump?.cancel()
        levelPump = nil
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
        // Light smoothing only: enough to avoid jitter, but low enough that the
        // meter tracks the voice in near real time. Heavier values made the
        // bars visibly trail the audio ("stale"/laggy).
        let smoothing: Float = 0.35
        let rms = previous.rms * smoothing + raw.rms * (1 - smoothing)
        let peak = previous.peak * smoothing + raw.peak * (1 - smoothing)
        let bars = zip(previous.bars, raw.bars).map { oldValue, newValue in
            oldValue * smoothing + newValue * (1 - smoothing)
        }
        return AudioLevelSnapshot(rms: rms, peak: peak, bars: bars)
    }
}
