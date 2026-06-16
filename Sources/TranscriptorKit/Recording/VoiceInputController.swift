import Foundation
import Observation

@MainActor
@Observable
public final class VoiceInputController {
    public private(set) var state: VoiceInputControllerState = .idle
    public private(set) var elapsedDuration: TimeInterval = 0
    public private(set) var lastSavedRecording: RecordedAudioAsset?
    public private(set) var liveLevels: AudioLevelSnapshot = .zero
    public private(set) var failureMessage: String?
    public private(set) var permissionStatus: MicrophonePermissionStatus

    private let recorder: AudioRecorderServing
    private let pendingStateDuration: Duration
    private let sleep: @Sendable (Duration) async -> Void
    private var recordingModeProvider: @MainActor () -> RecordingMode
    private var elapsedTask: Task<Void, Never>?
    private var recordingStartedAt: Date?
    private var onRecordingStarted: @MainActor () -> Void
    private var onRecordingFinished: @MainActor (RecordedAudioAsset) -> Void

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
        Task { await handleHotkeyPressed() }
    }

    public func hotkeyReleased() {
        Task { await handleHotkeyReleased() }
    }

    public func handleToolbarAction() async {
        if isRecording {
            await stopRecordingIfNeeded()
        } else {
            await startRecordingIfNeeded()
        }
    }

    public func handleHotkeyPressed() async {
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
        } catch {
            transitionToFailure(message: error.localizedDescription)
        }
    }

    private func startRecordingIfNeeded() async {
        guard state == .idle || state == .failed else {
            return
        }

        permissionStatus = recorder.authorizationStatus()
        failureMessage = nil

        if permissionStatus == .undetermined {
            state = .requestingPermission
            let granted = await recorder.requestPermission()
            permissionStatus = granted ? .granted : .denied
        }

        guard permissionStatus == .granted else {
            transitionToFailure(message: "Microphone access is required. Enable it in System Settings > Privacy & Security > Microphone.")
            return
        }

        do {
            _ = try recorder.startRecording()
            onRecordingStarted()
            state = .recording
            recordingStartedAt = .now
            startElapsedTimer()
        } catch {
            transitionToFailure(message: error.localizedDescription)
        }
    }

    private func stopRecordingIfNeeded() async {
        guard state == .recording else {
            return
        }

        state = .stopping
        stopElapsedTimer()

        do {
            let savedRecording = try recorder.stopRecording()
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
    }

    private func transitionToFailure(message: String) {
        stopElapsedTimer()
        recordingStartedAt = nil
        elapsedDuration = 0
        liveLevels = .zero
        failureMessage = message
        state = .failed
        permissionStatus = recorder.authorizationStatus()
    }
}
