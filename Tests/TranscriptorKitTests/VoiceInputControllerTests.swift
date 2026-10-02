import XCTest
@testable import TranscriptorKit

@MainActor
final class VoiceInputControllerTests: XCTestCase {
    func testStateTransitionsFromRecordingToPendingToIdle() async {
        let recorder = MockAudioRecorderService()
        let sleepGate = SleepGate()
        let controller = VoiceInputController(
            recorder: recorder,
            recordingModeProvider: { .holdToTalk },
            sleep: { _ in await sleepGate.wait() }
        )

        await controller.handleHotkeyPressed()
        XCTAssertEqual(controller.state, .recording)

        let stopTask = Task {
            await controller.handleHotkeyReleased()
        }
        await Task.yield()

        XCTAssertEqual(controller.state, .pendingTranscription)
        await sleepGate.release()
        await stopTask.value
        XCTAssertEqual(controller.state, .idle)
    }

    func testHoldToTalkStartsOnPressAndStopsOnRelease() async {
        let recorder = MockAudioRecorderService()
        let controller = VoiceInputController(
            recorder: recorder,
            recordingModeProvider: { .holdToTalk },
            sleep: { _ in }
        )

        await controller.handleHotkeyPressed()
        XCTAssertEqual(recorder.startCallCount, 1)
        XCTAssertEqual(controller.state, .recording)

        await controller.handleHotkeyReleased()
        XCTAssertEqual(recorder.stopCallCount, 1)
    }

    func testToggleToTalkStartsAndStopsOnSubsequentPresses() async {
        let recorder = MockAudioRecorderService()
        let controller = VoiceInputController(
            recorder: recorder,
            recordingModeProvider: { .toggleToTalk },
            sleep: { _ in }
        )

        await controller.handleHotkeyPressed()
        XCTAssertEqual(recorder.startCallCount, 1)
        XCTAssertEqual(controller.state, .recording)

        await controller.handleHotkeyPressed()
        XCTAssertEqual(recorder.stopCallCount, 1)
    }

    func testAccidentalTapIsDiscardedInsteadOfSaved() async {
        let recorder = MockAudioRecorderService()
        recorder.nextDuration = 0.2
        var finishedCount = 0
        var discardedCount = 0
        let controller = VoiceInputController(
            recorder: recorder,
            recordingModeProvider: { .holdToTalk },
            onRecordingFinished: { _ in finishedCount += 1 },
            sleep: { _ in }
        )
        controller.replaceOnRecordingDiscarded { discardedCount += 1 }

        await controller.handleHotkeyPressed()
        await controller.handleHotkeyReleased()

        XCTAssertEqual(finishedCount, 0)
        XCTAssertEqual(discardedCount, 1)
        XCTAssertEqual(controller.state, .idle)
    }

    func testNewRecordingCanStartDuringPendingFlash() async {
        let recorder = MockAudioRecorderService()
        let sleepGate = SleepGate()
        let controller = VoiceInputController(
            recorder: recorder,
            recordingModeProvider: { .holdToTalk },
            sleep: { _ in await sleepGate.wait() }
        )

        await controller.handleHotkeyPressed()
        let stopTask = Task { await controller.handleHotkeyReleased() }
        await Task.yield()
        XCTAssertEqual(controller.state, .pendingTranscription)

        await controller.handleHotkeyPressed()
        XCTAssertEqual(controller.state, .recording)
        XCTAssertEqual(recorder.startCallCount, 2)

        await sleepGate.release()
        await stopTask.value
        // The finished flash must not knock the new recording back to idle.
        XCTAssertEqual(controller.state, .recording)
    }

    func testPermissionFailureTransitionsToFailedState() async {
        let recorder = MockAudioRecorderService(permissionStatus: .denied)
        let controller = VoiceInputController(
            recorder: recorder,
            recordingModeProvider: { .holdToTalk },
            sleep: { _ in }
        )

        await controller.handleHotkeyPressed()

        XCTAssertEqual(controller.state, .failed)
        XCTAssertNotNil(controller.failureMessage)
    }

    func testUndeterminedPermissionRequestsAccessBeforeRecording() async {
        let recorder = MockAudioRecorderService(permissionStatus: .undetermined, permissionResponse: true)
        let controller = VoiceInputController(
            recorder: recorder,
            recordingModeProvider: { .holdToTalk },
            sleep: { _ in }
        )

        await controller.handleHotkeyPressed()

        XCTAssertEqual(recorder.requestPermissionCallCount, 1)
        XCTAssertEqual(controller.permissionStatus, .granted)
        XCTAssertEqual(controller.state, .recording)
    }
}

private actor SleepGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false

    func wait() async {
        guard !released else {
            return
        }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    /// Safe to call before `wait()`: a waiter that arrives later passes
    /// straight through instead of hanging the test.
    func release() {
        released = true
        continuation?.resume()
        continuation = nil
    }
}

private final class MockAudioRecorderService: AudioRecorderServing, @unchecked Sendable {
    var onLevelsDidChange: (@MainActor @Sendable (AudioLevelSnapshot) -> Void)?
    var onRecordingError: (@MainActor @Sendable (Error) -> Void)?
    var isRecording = false

    var permissionStatus: MicrophonePermissionStatus
    var permissionResponse: Bool
    var startCallCount = 0
    var stopCallCount = 0
    var cancelCallCount = 0
    var requestPermissionCallCount = 0
    var nextDuration: TimeInterval = 3

    init(
        permissionStatus: MicrophonePermissionStatus = .granted,
        permissionResponse: Bool? = nil
    ) {
        self.permissionStatus = permissionStatus
        self.permissionResponse = permissionResponse ?? (permissionStatus == .granted)
    }

    func authorizationStatus() -> MicrophonePermissionStatus {
        permissionStatus
    }

    func requestPermission() async -> Bool {
        requestPermissionCallCount += 1
        permissionStatus = permissionResponse ? .granted : .denied
        return permissionResponse
    }

    func startRecording() throws -> URL {
        startCallCount += 1
        isRecording = true
        let levelHandler = onLevelsDidChange
        Task { @MainActor in
            levelHandler?(.zero)
        }
        return URL(fileURLWithPath: "/tmp/mock.wav")
    }

    func stopRecording() throws -> RecordedAudioAsset {
        stopCallCount += 1
        isRecording = false
        return RecordedAudioAsset(
            url: URL(fileURLWithPath: "/tmp/mock.wav"),
            createdAt: .now,
            durationSeconds: Int(nextDuration.rounded()),
            fileSizeBytes: 4_096,
            preciseDuration: nextDuration
        )
    }

    func cancelRecording() throws {
        cancelCallCount += 1
        isRecording = false
    }
}
