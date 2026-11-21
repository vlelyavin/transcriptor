import SwiftUI

/// The compact status overlay shown while recording and during the
/// transcription that follows.
///
/// The view is a thin adapter: it maps the recorder's state and the
/// supplemental phase onto `RecordingOverlayCard`, which owns the layout,
/// the live wave and the motion. The public initializer stays stable so
/// `RecordingOverlayManager` does not need to know about the card.
public struct RecordingOverlayView: View {
    @Bindable private var voiceInputController: VoiceInputController
    private let overlayState: OverlayState
    private let recordingMode: RecordingMode
    private let supplementalPhase: OverlaySupplementalPhase?
    private let stopAction: () -> Void
    private let cancelAction: () -> Void

    public init(
        voiceInputController: VoiceInputController,
        overlayState: OverlayState,
        recordingMode: RecordingMode,
        supplementalPhase: OverlaySupplementalPhase?,
        stopAction: @escaping () -> Void,
        cancelAction: @escaping () -> Void
    ) {
        self.voiceInputController = voiceInputController
        self.overlayState = overlayState
        self.recordingMode = recordingMode
        self.supplementalPhase = supplementalPhase
        self.stopAction = stopAction
        self.cancelAction = cancelAction
    }

    public var body: some View {
        RecordingOverlayCard(
            phase: phase,
            // Reading the controller here is what makes the wave follow the
            // 20 Hz level snapshots: `@Bindable` subscribes this view, and
            // the card's TimelineView turns those samples into 60 Hz motion.
            levels: voiceInputController.liveLevels.bars,
            elapsed: voiceInputController.elapsedDuration,
            mode: overlayState.displayMode,
            recordingMode: recordingMode == .holdToTalk ? .hold : .toggle,
            showsWaveform: overlayState.showsLiveAudioIndicator,
            onStop: stopAction,
            onCancel: cancelAction
        )
    }

    private var phase: OverlayPhase {
        if let supplementalPhase {
            switch supplementalPhase {
            case .transcribing:
                return .working("Transcribing")
            case .inserting:
                return .working("Inserting")
            case .saved:
                return .inserted(nil)
            case let .error(message):
                return .failed(message)
            case let .setupRequired(message):
                return .failed(message)
            case .preview, .unconfigured:
                // The manager swaps in `ResultOverlayView` for these phases;
                // this case only keeps the mapping total.
                return .inserted(nil)
            }
        }

        switch voiceInputController.state {
        case .recording:
            return .listening
        case .stopping:
            return .finishing
        case .pendingTranscription:
            return .inserted(nil)
        case .requestingPermission:
            return .permission
        case .failed:
            return .failed(voiceInputController.failureMessage ?? "Something went wrong.")
        case .idle:
            return .finishing
        }
    }
}
