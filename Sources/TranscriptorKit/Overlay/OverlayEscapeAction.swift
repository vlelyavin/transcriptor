import Foundation

/// What an Escape keypress should do while the recording overlay is up.
/// Pure decision function — the AppKit monitor calls this and executes the
/// result, so the logic stays unit-testable without an `NSEvent`.
public enum OverlayEscapeAction: Equatable, Sendable {
    /// Nothing to do — let the event through normally.
    case none
    /// Hide the overlay result card (same as clicking its dismiss button).
    /// A pending transcription is never aborted.
    case dismiss
    /// Cancel an in-progress toggle-mode recording (same as its Cancel button).
    case cancelRecording

    public static func decide(
        state: VoiceInputControllerState,
        mode: RecordingMode,
        supplemental: OverlaySupplementalPhase?
    ) -> OverlayEscapeAction {
        if let supplemental {
            switch supplemental {
            case .unconfigured:
                // The interactive result card is the only Esc-dismissible card.
                return .dismiss
            case .transcribing, .inserting, .saved, .error, .setupRequired:
                // Transient/auto-hide phases: Escape shouldn't interrupt work.
                return .none
            }
        }

        // Hold-to-talk already maps key-up to stop, so Esc cancels only in
        // toggle mode — matching its on-screen Cancel button.
        if state == .recording, mode == .toggleToTalk {
            return .cancelRecording
        }

        return .none
    }
}
