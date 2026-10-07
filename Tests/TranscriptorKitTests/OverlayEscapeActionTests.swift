import XCTest
@testable import TranscriptorKit

final class OverlayEscapeActionTests: XCTestCase {
    func testEscapeDismissesUnconfiguredCard() {
        XCTAssertEqual(
            OverlayEscapeAction.decide(
                state: .idle,
                mode: .holdToTalk,
                supplemental: .unconfigured(OverlayUnconfiguredPayload(entryID: UUID(), fileName: "take.wav", durationSeconds: 3))
            ),
            .dismiss
        )
    }

    func testEscapeNeverInterruptsTransientPhases() {
        for phase in [
            OverlaySupplementalPhase.transcribing("Transcribing…"),
            .inserting("Inserting…"),
            .saved("Saved"),
            .error("boom"),
            .setupRequired("Setup required"),
        ] {
            XCTAssertEqual(
                OverlayEscapeAction.decide(state: .idle, mode: .holdToTalk, supplemental: phase),
                .none,
                "\(phase.caseName) must not be Esc-dismissible"
            )
        }
    }

    func testEscapeCancelsOnlyToggleModeRecording() {
        XCTAssertEqual(
            OverlayEscapeAction.decide(state: .recording, mode: .toggleToTalk, supplemental: nil),
            .cancelRecording
        )
        // Hold-to-talk already maps key-up to stop; Esc must not double-stop.
        XCTAssertEqual(
            OverlayEscapeAction.decide(state: .recording, mode: .holdToTalk, supplemental: nil),
            .none
        )
    }

    func testEscapeDoesNothingWhenIdle() {
        XCTAssertEqual(
            OverlayEscapeAction.decide(state: .idle, mode: .holdToTalk, supplemental: nil),
            .none
        )
        XCTAssertEqual(
            OverlayEscapeAction.decide(state: .pendingTranscription, mode: .toggleToTalk, supplemental: nil),
            .none
        )
    }
}
