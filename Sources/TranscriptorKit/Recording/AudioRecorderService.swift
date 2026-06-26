import Accelerate
import AudioToolbox
import AVFoundation
import CoreAudio
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
    // Guards the route-change handler against re-entrancy while it tears down and
    // re-establishes the tap.
    private var isReconfiguringRoute = false
    // The human-readable name of the input device this recording is bound to,
    // used in diagnostics and the no-audio watchdog message. Set at start.
    private var activeInputDeviceName = "the selected input device"

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

        // Explicitly bind the engine's input to the CURRENT system default input
        // device via Core Audio, instead of letting AVAudioEngine pick a device
        // implicitly and lazily. This is the key to recording from AirPods (and
        // other Bluetooth mics): opening the chosen device here forces macOS to
        // activate its HFP microphone route NOW, at a deterministic moment, so the
        // Bluetooth profile negotiation starts immediately rather than racing the
        // first buffer. It also guarantees we capture the device the user actually
        // selected, not a stale one the engine cached. Falls back to the engine
        // default if the device can't be resolved or bound, so the built-in-mic
        // path is never made worse.
        let boundDeviceName = bindCurrentDefaultInputDevice(to: inputNode)

        // The input node's OUTPUT format is, by definition, what the tap delivers,
        // so it always matches (unlike `inputFormat`, which for AirPods runs the
        // mic in a different low-rate HFP format and made `installTap` throw). We
        // tap with `format: nil` and build the output file from the delivered
        // buffer instead, so this value is used only for validation + the log line.
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        activeInputDeviceName = boundDeviceName
            ?? AVCaptureDevice.default(for: .audio)?.localizedName
            ?? "the selected input device"
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        log.notice("startRecording: input=\(self.activeInputDeviceName, privacy: .public) tap=\(recordingFormat.sampleRate, privacy: .public)Hz/\(recordingFormat.channelCount, privacy: .public)ch hw=\(hardwareFormat.sampleRate, privacy: .public)Hz/\(hardwareFormat.channelCount, privacy: .public)ch")

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

        recordingStartedAt = .now
        totalFramesRecorded = 0
        lastLevels = .zero
        self.outputURL = outputURL
        // Created lazily from the first delivered buffer's real format (see
        // `outputFileMatching`) so the file always matches what the tap delivers.
        self.outputFile = nil
        self.engine = engine
        resetBufferTracking()
        installConfigChangeObserver(for: engine)

        // `format: nil` → deliver buffers in the input node's real output format
        // (whatever the current device negotiated), instead of forcing a format
        // that may not match the live AirPods / HFP route. Extracted so the
        // route-change handler can re-establish delivery identically.
        installRecordingTap(on: inputNode)

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
        isReconfiguringRoute = false
        lastLevels = .zero

        levelLock.lock()
        latestLevels = .zero
        didReceiveBuffer = false
        bufferCount = 0
        levelLock.unlock()
    }

    /// Returns the output file, creating it lazily from the FIRST delivered
    /// buffer's format. Because the file is built from the exact format the tap
    /// delivers, `write(from:)` can never fail on a format mismatch — the AirPods
    /// / HFP failure where the device runs at a different rate (e.g. 24 kHz) than
    /// the format queried before the engine started.
    private func outputFileMatching(_ format: AVAudioFormat) throws -> AVAudioFile {
        if let outputFile {
            return outputFile
        }
        guard let outputURL else {
            throw AudioRecorderError.unableToCreateOutputFile
        }
        let file = try AVAudioFile(forWriting: outputURL, settings: format.settings)
        outputFile = file
        sampleRate = format.sampleRate
        log.notice("output file → \(format.sampleRate, privacy: .public)Hz/\(format.channelCount, privacy: .public)ch")
        return file
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

    // MARK: - Input device selection (Core Audio)

    /// Binds the engine's input node to the current system default input device
    /// and returns that device's name. Setting the AUHAL's current device opens
    /// exactly that device for input, which is what forces a Bluetooth mic
    /// (AirPods) to switch into its HFP capture profile — the step the implicit
    /// AVAudioEngine default left to chance, and the reason AirPods recordings
    /// arrived empty. Returns `nil` (leaving the engine on its default device) if
    /// the device can't be resolved or the property can't be set, so the
    /// built-in-mic path is never made worse.
    @discardableResult
    private func bindCurrentDefaultInputDevice(to inputNode: AVAudioInputNode) -> String? {
        guard let deviceID = Self.currentDefaultInputDeviceID() else {
            log.notice("input device: no system default input; using engine default")
            return nil
        }
        guard let audioUnit = inputNode.audioUnit else {
            log.notice("input device: input node has no audio unit; using engine default")
            return nil
        }

        var device = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &device,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )

        let name = Self.deviceName(for: deviceID)
        guard status == noErr else {
            log.error("input device: failed to bind \(name, privacy: .public) (status \(status, privacy: .public)); using engine default")
            return nil
        }

        log.notice("input device: bound \(name, privacy: .public) (id \(deviceID, privacy: .public))")
        return name
    }

    /// The current system default input device ID, or `nil` if none is set.
    private static func currentDefaultInputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else {
            return nil
        }
        return deviceID
    }

    /// A human-readable name for a Core Audio device, for diagnostics.
    private static func deviceName(for deviceID: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        // `kAudioObjectPropertyName` returns a +1-retained CFString; capture it as
        // `Unmanaged` and consume that reference so it is neither leaked nor
        // over-released.
        var unmanagedName: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &unmanagedName)
        guard status == noErr, let name = unmanagedName?.takeRetainedValue() else {
            return "input device \(deviceID)"
        }
        return name as String
    }

    private func installConfigChangeObserver(for engine: AVAudioEngine) {
        if let configChangeObserver {
            NotificationCenter.default.removeObserver(configChangeObserver)
        }
        // A Bluetooth route flip (e.g. AirPods switching from A2DP to the HFP mic
        // profile the instant the mic is requested) posts this and STOPS the tap
        // from delivering any further buffers — the recording captures ~0.1s and
        // then nothing. We react by re-establishing capture for the new route.
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.handleConfigurationChange()
        }
    }

    /// Installs the capture tap on the given input node. Shared by
    /// `startRecording` and `handleConfigurationChange` so a mid-session route
    /// switch can re-establish buffer delivery with identical handling.
    private func installRecordingTap(on inputNode: AVAudioInputNode) {
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: nil) { [weak self] buffer, _ in
            guard let self else {
                return
            }

            self.markBufferReceived()

            // Analyze levels BEFORE any file I/O so the live meter keeps moving
            // even when a write hiccups — it must never freeze on a write error.
            // (The old stale-levels-and-return path is what stuck the equalizer.)
            let analyzedLevels = Self.analyzeLevels(from: buffer, previous: self.lastLevels)
            self.lastLevels = analyzedLevels
            self.storeLatestLevels(analyzedLevels)

            // Write to a file whose format matches the delivered buffer. AirPods /
            // Bluetooth deliver a different rate than the format queried before the
            // engine started, so a file created from that earlier format made every
            // write throw → an empty recording. Building it from the buffer's own
            // format (once, before any frames) keeps every write valid.
            do {
                let file = try self.outputFileMatching(buffer.format)
                try file.write(from: buffer)
                self.totalFramesRecorded += AVAudioFramePosition(buffer.frameLength)
            } catch {
                self.log.error("buffer write failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Re-establishes capture after the audio route changes mid-recording. This
    /// is THE fix for AirPods (and other Bluetooth mics): they start in A2DP at a
    /// high sample rate, deliver one buffer, then flip to the lower-rate HFP mic
    /// profile — which silently kills the existing tap. We re-attach the tap (so
    /// buffers resume) and recreate the output file from the new format (so writes
    /// don't fail on the rate change). The fraction of a second of pre-flip audio
    /// is discarded, which is inaudible compared to losing the whole recording.
    private func handleConfigurationChange() {
        guard isRecording, let engine, !isReconfiguringRoute else {
            return
        }
        isReconfiguringRoute = true
        defer { isReconfiguringRoute = false }

        let inputNode = engine.inputNode
        let newFormat = inputNode.outputFormat(forBus: 0)
        log.notice("route changed mid-session → \(newFormat.sampleRate, privacy: .public)Hz/\(newFormat.channelCount, privacy: .public)ch; re-establishing capture")

        // Safe to reset the file here: the old tap is removed before the new one
        // is installed, so no audio-thread callback touches `outputFile` in
        // between. The next buffer recreates it at the route's new format.
        inputNode.removeTap(onBus: 0)
        outputFile = nil
        totalFramesRecorded = 0

        guard newFormat.sampleRate > 0, newFormat.channelCount > 0 else {
            log.error("route change reported an invalid format; capture cannot resume")
            return
        }

        installRecordingTap(on: inputNode)

        if !engine.isRunning {
            engine.prepare()
            do {
                try engine.start()
                log.notice("engine restarted after route change")
            } catch {
                log.error("engine restart after route change failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        // The route just changed and we re-established capture. If no audio has
        // arrived yet — the AirPods A2DP→HFP flip is exactly this case — give the
        // new route a fresh watchdog window instead of letting the original timer
        // abort a recording that is only now about to start delivering buffers.
        if !hasReceivedBuffer() {
            startBufferWatchdog()
        }
    }

    /// Guards against the "engine started but no audio ever arrives" failure —
    /// the typical AirPods / Bluetooth symptom where the overlay sits on
    /// "Listening…" forever. If no tap buffer lands within the window, stop and
    /// surface an actionable error rather than leaving a frozen overlay.
    ///
    /// The window is deliberately generous (4s): a Bluetooth mic switching from
    /// the A2DP playback profile to the HFP mic profile routinely delivers no
    /// buffers for 1.5–3s while the link negotiates, and a shorter window aborted
    /// valid AirPods recordings before the first buffer ever arrived (the root of
    /// "I tried multiple times — no results"). The built-in mic delivers within
    /// ~100ms, so it never waits. A route change mid-handshake restarts this
    /// window (see `handleConfigurationChange`).
    private func startBufferWatchdog() {
        bufferWatchdog?.cancel()
        bufferWatchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(4_000))
            guard let self, !Task.isCancelled, self.isRecording, !self.hasReceivedBuffer() else {
                return
            }

            let deviceName = self.activeInputDeviceName
            self.log.error("watchdog: no audio buffers 4s after start from \(deviceName, privacy: .public)")
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

    /// Publishes the latest captured levels to the UI at a steady ~20 Hz. A
    /// single long-lived task — never one per buffer — so the meter tracks the
    /// input smoothly and can never stall behind a backlog of per-buffer hops.
    /// 20 Hz (not 30) keeps the overlay's main-thread render load low enough that
    /// it never starves global-hotkey handling during a recording.
    private func startLevelPump() {
        levelPump?.cancel()
        levelPump = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.onLevelsDidChange?(self.readLatestLevels())
                try? await Task.sleep(for: .milliseconds(50))
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
