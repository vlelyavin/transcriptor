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

            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(.headline)

                if showsLiveMeter {
                    LiveAudioMeter(levels: voiceInputController.liveLevels)
                        .frame(height: 14)
                } else if !statusSubtitle.isEmpty {
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
                // Deliberately NO `.keyboardShortcut` here. A keyboard shortcut
                // (Return/Esc) only fires when its window is the key window, which
                // would force this non-activating overlay to steal key-window
                // status from the app the user is dictating into — the cross-app
                // split that froze the meter, wedged the global shortcut, and
                // misrouted Cmd+V in toggle mode. Stop via the global shortcut or
                // a mouse click on Done (delivered via `acceptsFirstMouse` without
                // keying the panel). See `RecordingOverlayManager.FloatingOverlayPanel`.
                Button("Done") { stopAction() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                Button("Cancel", role: .cancel) { cancelAction() }
                    .controlSize(.small)
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

    /// While actively recording, the static "what to do next" subtitle is
    /// replaced by a live level meter so the user can see the app is hearing
    /// them — unless they've turned the indicator off in Overlay settings.
    private var showsLiveMeter: Bool {
        isListening && overlayState.showsLiveAudioIndicator
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

/// A compact, native-feeling live input meter: a row of capsule bars driven by
/// the recorder's per-band levels. It gives immediate visual confirmation that
/// the microphone is picking up the user's voice.
private struct LiveAudioMeter: View {
    let levels: AudioLevelSnapshot

    var body: some View {
        GeometryReader { proxy in
            let bars = levels.bars
            let count = max(bars.count, 1)
            let spacing: CGFloat = 3
            let barWidth = max(2, (proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))

            HStack(alignment: .center, spacing: spacing) {
                ForEach(bars.indices, id: \.self) { index in
                    let magnitude = CGFloat(min(max(bars[index], 0), 1))
                    Capsule(style: .continuous)
                        .fill(Color.accentColor.opacity(0.35 + 0.65 * magnitude))
                        .frame(
                            width: barWidth,
                            height: max(2, proxy.size.height * magnitude)
                        )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            // No per-frame `.animation` here. The levels are already smoothed in
            // the recorder (see `smoothedSnapshot`), so animating every ~20–30 Hz
            // update only spawned overlapping Core Animation transactions that
            // saturated the main run loop — starving the global-hotkey handlers
            // so a toggle-mode "stop" press wasn't processed until recording
            // ended (the "overlay won't close / equalizer sticks" bug, confirmed
            // in the logs). Driving the bars straight off the smoothed data stays
            // visually smooth without the continuous animation churn.
        }
        .accessibilityHidden(true)
    }
}
