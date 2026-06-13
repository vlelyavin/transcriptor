import SwiftUI

/// The compact status overlay shown while recording and during the
/// transcription that follows. It is deliberately minimal: a single status
/// glyph, a title, a one-line detail, and — only while it matters — a timer,
/// a native progress spinner, or Done/Cancel. Everything is built from native
/// macOS components (SF Symbols with symbol effects, `ProgressView`, system
/// materials) so it reads as part of the OS rather than a custom widget.
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
        HStack(spacing: 14) {
            statusGlyph

            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.headline)

                if !statusSubtitle.isEmpty {
                    Text(statusSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailingAccessory
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(width: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.separator, lineWidth: 0.5)
        )
    }

    // MARK: - Leading glyph

    private var statusGlyph: some View {
        // The same beveled dark tile used by the app's settings sidebar — one
        // consistent treatment for every state (no per-state colors).
        SidebarIconView(systemImage: statusSymbol, size: 40, animated: isListening)
    }

    // MARK: - Trailing accessory (timer / spinner / actions)

    @ViewBuilder
    private var trailingAccessory: some View {
        if showsProgressIndicator {
            ProgressView()
                .controlSize(.small)
        } else if showsDoneControls {
            VStack(spacing: 6) {
                Button("Done") { stopAction() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .keyboardShortcut(.defaultAction)

                Button("Cancel", role: .cancel) { cancelAction() }
                    .controlSize(.small)
                    .keyboardShortcut(.cancelAction)
            }
        } else if showsTimer {
            Text(durationLabel)
                .font(.system(.callout, design: .monospaced).weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - State derivations

    private var isListening: Bool {
        supplementalPhase == nil && voiceInputController.state == .recording
    }

    private var statusTitle: String {
        if let supplementalPhase {
            switch supplementalPhase {
            case .transcribing: return "Transcribing"
            case .inserting: return "Inserting"
            case .saved: return "Done"
            case .error: return "Couldn’t Transcribe"
            case .setupRequired: return "Setup Needed"
            case .preview: return "Transcript Ready"
            case .unconfigured: return "Recording Saved"
            }
        }

        switch voiceInputController.state {
        case .recording: return "Listening…"
        case .stopping: return "Finishing…"
        case .pendingTranscription: return "Recorded"
        case .requestingPermission: return "Microphone Access"
        case .failed: return "Recording Failed"
        case .idle: return "Idle"
        }
    }

    private var statusSubtitle: String {
        if let supplementalPhase {
            switch supplementalPhase {
            case let .transcribing(message),
                 let .inserting(message),
                 let .saved(message),
                 let .error(message),
                 let .setupRequired(message):
                return message
            case .preview, .unconfigured:
                return ""
            }
        }

        switch voiceInputController.state {
        case .recording:
            return recordingMode == .holdToTalk
                ? "Release the shortcut to finish."
                : "Click Done or press the shortcut again."
        case .stopping:
            return "Preparing your recording."
        case .pendingTranscription:
            return "Saved to history."
        case .requestingPermission:
            return "Allow microphone access to start."
        case .failed:
            return voiceInputController.failureMessage ?? "Something went wrong."
        case .idle:
            return ""
        }
    }

    private var statusSymbol: String {
        if let supplementalPhase {
            switch supplementalPhase {
            case .transcribing: return "waveform"
            case .inserting: return "text.cursor"
            case .saved: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            case .setupRequired: return "gearshape.fill"
            case .preview: return "text.quote"
            case .unconfigured: return "mic.badge.plus"
            }
        }

        switch voiceInputController.state {
        case .recording: return "waveform"
        case .stopping: return "hourglass"
        case .pendingTranscription: return "checkmark.circle.fill"
        case .requestingPermission: return "lock.shield"
        case .failed: return "exclamationmark.triangle.fill"
        case .idle: return "mic"
        }
    }

    private var durationLabel: String {
        let elapsed = Int(voiceInputController.elapsedDuration)
        return String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }

    private var showsTimer: Bool {
        supplementalPhase == nil
            && (voiceInputController.state == .recording || voiceInputController.state == .stopping)
    }

    private var showsDoneControls: Bool {
        supplementalPhase == nil
            && voiceInputController.state == .recording
            && recordingMode == .toggleToTalk
    }

    private var showsProgressIndicator: Bool {
        guard let supplementalPhase else { return false }
        switch supplementalPhase {
        case .transcribing, .inserting: return true
        case .saved, .error, .setupRequired, .preview, .unconfigured: return false
        }
    }
}
