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

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func release() {
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
            durationSeconds: 3,
            fileSizeBytes: 4_096
        )
    }

    func cancelRecording() throws {
        cancelCallCount += 1
        isRecording = false
    }
}
