import Foundation
import Observation
import os

@MainActor
@Observable
public final class VoiceInputController {
    private let log = Logger(subsystem: "com.vlelyavin.Transcriptor", category: "voice")
    public private(set) var state: VoiceInputControllerState = .idle
    public private(set) var elapsedDuration: TimeInterval = 0
    public private(set) var lastSavedRecording: RecordedAudioAsset?
    public private(set) var liveLevels: AudioLevelSnapshot = .zero
    public private(set) var failureMessage: String?
    public private(set) var permissionStatus: MicrophonePermissionStatus
    /// Name of the microphone currently in use — the bound device while
    /// recording, the system default while idle. `nil` when the system reports
    /// no usable input device.
    public private(set) var inputDeviceName: String?

    private let recorder: AudioRecorderServing
    private let pendingStateDuration: Duration
    private let sleep: @Sendable (Duration) async -> Void
    private var recordingModeProvider: @MainActor () -> RecordingMode
    private var elapsedTask: Task<Void, Never>?
    private var recordingStartedAt: Date?
    private var onRecordingStarted: @MainActor () -> Void
    private var onRecordingFinished: @MainActor (RecordedAudioAsset) -> Void
    private var onRecordingDiscarded: @MainActor () -> Void = {}
    /// Whether the hotkey is physically held right now. A release that lands
    /// while the microphone permission prompt is on screen can't stop a
    /// recording that hasn't started, so the flag is also consulted right after
    /// the prompt resolves — if the key is already up, hold-to-talk must not
    /// begin a recording the user has already let go of.
    private var hotkeyCurrentlyDown = false
    private var failureResetTask: Task<Void, Never>?

    /// Captures shorter than this are accidental taps of the shortcut: no
    /// engine can transcribe them (Parakeet rejects < 300 ms outright; Whisper
    /// returns nothing or hallucinates), and they used to pile up as failed
    /// history items.
    public static let minimumRecordingDuration: TimeInterval = 0.5

    public init(
        recorder: AudioRecorderServing,
        pendingStateDuration: Duration = .seconds(1),
        recordingModeProvider: @escaping @MainActor () -> RecordingMode = { .holdToTalk },
        onRecordingStarted: @escaping @MainActor () -> Void = {},
        onRecordingFinished: @escaping @MainActor (RecordedAudioAsset) -> Void = { _ in },
        sleep: @escaping @Sendable (Duration) async -> Void = { duration in
            try? await Task.sleep(for: duration)
        }
    ) {
        self.recorder = recorder
        self.pendingStateDuration = pendingStateDuration
        self.recordingModeProvider = recordingModeProvider
        self.onRecordingStarted = onRecordingStarted
        self.onRecordingFinished = onRecordingFinished
        self.sleep = sleep
        self.permissionStatus = recorder.authorizationStatus()
        self.inputDeviceName = recorder.currentInputDeviceName
        recorder.onLevelsDidChange = { [weak self] snapshot in
            guard let self else {
                return
            }
            self.liveLevels = snapshot
        }
        recorder.onRecordingError = { [weak self] error in
            guard let self, self.state == .recording else {
                return
            }
            // The recorder aborted an in-progress capture on its own (e.g. the
            // no-audio watchdog fired for a dead AirPods route). Surface it as a
            // normal failure so the overlay shows the message instead of hanging.
            self.transitionToFailure(message: error.localizedDescription)
        }
    }

    public var isRecording: Bool {
        state == .recording
    }

    /// Re-reads the current microphone authorization from the system. Used by the
    /// onboarding flow to reflect a permission the user just granted in System
    /// Settings without starting a recording.
    public func refreshPermissionStatus() {
        permissionStatus = recorder.authorizationStatus()
    }

    /// Prompts for microphone access if it has never been decided. When access
    /// was already granted or denied, this just refreshes the cached status (a
    /// denied user must change it in System Settings).
    @discardableResult
    public func requestMicrophonePermission() async -> Bool {
        permissionStatus = recorder.authorizationStatus()
        if permissionStatus == .undetermined {
            let granted = await recorder.requestPermission()
            permissionStatus = granted ? .granted : .denied
        }
        return permissionStatus == .granted
    }

    public func replaceOnRecordingFinished(_ handler: @escaping @MainActor (RecordedAudioAsset) -> Void) {
        onRecordingFinished = handler
    }

    public func replaceOnRecordingDiscarded(_ handler: @escaping @MainActor () -> Void) {
        onRecordingDiscarded = handler
    }

    public func replaceOnRecordingStarted(_ handler: @escaping @MainActor () -> Void) {
        onRecordingStarted = handler
    }

    public func replaceRecordingModeProvider(_ provider: @escaping @MainActor () -> RecordingMode) {
        recordingModeProvider = provider
    }

    public func startFromToolbar() {
        Task { await handleToolbarAction() }
    }

    public func stopFromToolbar() {
        Task { await stopRecordingIfNeeded() }
    }

    public func hotkeyPressed() {
        // `.userInitiated` so the global shortcut — the user's reliable way to
        // start and (in toggle mode) stop — preempts lower-priority main-actor
        // work such as live-meter rendering, instead of queueing behind it. A
        // starved stop press was the "won't stop / can't close the overlay" bug.
        Task(priority: .userInitiated) { await handleHotkeyPressed() }
    }

    public func hotkeyReleased() {
        Task(priority: .userInitiated) { await handleHotkeyReleased() }
    }

    public func handleToolbarAction() async {
        if isRecording {
            await stopRecordingIfNeeded()
        } else {
            await startRecordingIfNeeded()
        }
    }

    public func handleHotkeyPressed() async {
        hotkeyCurrentlyDown = true
        log.notice("hotkey pressed: mode=\(String(describing: self.recordingModeProvider()), privacy: .public) state=\(self.state.rawValue, privacy: .public)")
        switch recordingModeProvider() {
        case .holdToTalk:
            await startRecordingIfNeeded()
        case .toggleToTalk:
            if isRecording {
                await stopRecordingIfNeeded()
            } else {
                await startRecordingIfNeeded()
            }
        }
    }

    public func handleHotkeyReleased() async {
        hotkeyCurrentlyDown = false
        log.notice("hotkey released: mode=\(String(describing: self.recordingModeProvider()), privacy: .public) state=\(self.state.rawValue, privacy: .public)")
        guard recordingModeProvider() == .holdToTalk else {
            return
        }

        await stopRecordingIfNeeded()
    }

    public func cancelRecording() async {
        guard isRecording else {
            return
        }

        do {
            try recorder.cancelRecording()
            resetToIdle()
            // Same cleanup as the accidental-tap path: drop the captured
            // insertion target and any lingering overlay card.
            onRecordingDiscarded()
        } catch {
            transitionToFailure(message: error.localizedDescription)
        }
    }

    private func startRecordingIfNeeded() async {
        // `.pendingTranscription` is only a short "saved" flash after a stop;
        // the recorder is already free, so a quick follow-up dictation must
        // start instead of being dropped as "busy".
        guard state == .idle || state == .failed || state == .pendingTranscription else {
            log.notice("start ignored: busy (state=\(self.state.rawValue, privacy: .public))")
            return
        }

        permissionStatus = recorder.authorizationStatus()
        failureMessage = nil

        if permissionStatus == .undetermined {
            state = .requestingPermission
            let granted = await recorder.requestPermission()
            permissionStatus = granted ? .granted : .denied

            // While the system prompt was up, any hotkey release was dropped
            // (there was no recording to stop). In hold-to-talk the key is no
            // longer down, so the user already "let go" — don't start now.
            if recordingModeProvider() == .holdToTalk && !hotkeyCurrentlyDown {
                resetToIdle()
                return
            }
        }

        guard permissionStatus == .granted else {
            transitionToFailure(message: "Microphone access is required. Enable it in System Settings > Privacy & Security > Microphone.")
            return
        }

        do {
            log.notice("starting recording")
            _ = try recorder.startRecording()
            inputDeviceName = recorder.currentInputDeviceName
            // Set the state BEFORE the callback: `onRecordingStarted` triggers an
            // overlay refresh, and it must already see `.recording` — otherwise a
            // lingering card's hide animation can outlive the show that follows.
            state = .recording
            onRecordingStarted()
            recordingStartedAt = .now
            startElapsedTimer()
            log.notice("recording active")
        } catch {
            log.error("startRecording threw: \(error.localizedDescription, privacy: .public)")
            transitionToFailure(message: error.localizedDescription)
        }
    }

    private func stopRecordingIfNeeded() async {
        guard state == .recording else {
            log.notice("stop ignored: not recording (state=\(self.state.rawValue, privacy: .public))")
            return
        }

        log.notice("stopping recording")
        state = .stopping
        stopElapsedTimer()

        do {
            let savedRecording = try recorder.stopRecording()
            guard savedRecording.preciseDuration >= Self.minimumRecordingDuration else {
                log.notice("discarding \(savedRecording.preciseDuration, privacy: .public)s capture (accidental tap)")
                try? FileManager.default.removeItem(at: savedRecording.url)
                resetToIdle()
                onRecordingDiscarded()
                return
            }
            lastSavedRecording = savedRecording
            onRecordingFinished(savedRecording)
            state = .pendingTranscription
            liveLevels = .zero
            await sleep(pendingStateDuration)

            if state == .pendingTranscription {
                resetToIdle()
            }
        } catch {
            transitionToFailure(message: error.localizedDescription)
        }
    }

    private func startElapsedTimer() {
        stopElapsedTimer()
        elapsedDuration = 0
        elapsedTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else {
                    return
                }

                await MainActor.run {
                    guard let recordingStartedAt = self.recordingStartedAt else {
                        return
                    }
                    self.elapsedDuration = Date().timeIntervalSince(recordingStartedAt)
                }

                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func stopElapsedTimer() {
        elapsedTask?.cancel()
        elapsedTask = nil
    }

    private func resetToIdle() {
        stopElapsedTimer()
        recordingStartedAt = nil
        elapsedDuration = 0
        state = .idle
        liveLevels = .zero
        failureMessage = nil
        permissionStatus = recorder.authorizationStatus()
        // Back to the system default input (the take may have been bound to a
        // transient route like a Bluetooth HFP profile).
        inputDeviceName = recorder.currentInputDeviceName
    }

    private func transitionToFailure(message: String) {
        log.error("voice input failed: \(message, privacy: .public)")
        stopElapsedTimer()
        recordingStartedAt = nil
        elapsedDuration = 0
        liveLevels = .zero
        failureMessage = message
        state = .failed
        permissionStatus = recorder.authorizationStatus()

        // `.failed` is a transient display state: the overlay shows the message
        // briefly, then the controller must return to `.idle` so the menu-bar
        // icon and shortcuts recover. `failureMessage` stays set for logs and
        // the overlay until the next attempt clears it.
        failureResetTask?.cancel()
        failureResetTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            await self.sleep(.seconds(2))
            guard self.state == .failed else {
                return
            }
            self.state = .idle
        }
    }
}
