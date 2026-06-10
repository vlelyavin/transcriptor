import SwiftUI

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
        VStack(spacing: 12) {
            Image(systemName: statusSymbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 44, height: 44)
                .background(statusColor.opacity(0.12), in: Circle())

            VStack(spacing: 4) {
                Text(statusTitle)
                    .font(.headline)

                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsDuration {
                Text(durationLabel)
                    .font(.system(.body, design: .monospaced).weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if showsProgressIndicator {
                ProgressView()
                    .controlSize(.regular)
            } else if overlayState.showsLiveAudioIndicator {
                HStack(alignment: .center, spacing: 5) {
                    ForEach(Array(indicatorValues.enumerated()), id: \.offset) { _, value in
                        Capsule(style: .continuous)
                            .fill(indicatorColor)
                            .frame(width: 5, height: max(6, CGFloat(value) * 36))
                    }
                }
                .frame(height: 40)
                .animation(.easeInOut(duration: 0.16), value: indicatorValues)
            }

            if showsDoneControls {
                HStack(spacing: 10) {
                    Button("Cancel", role: .cancel) {
                        cancelAction()
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Done") {
                        stopAction()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
                .controlSize(.regular)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.separator, lineWidth: 1)
        )
    }

    private var statusTitle: String {
        if let supplementalPhase {
            switch supplementalPhase {
            case .transcribing:
                return "Transcribing"
            case .inserting:
                return "Inserting"
            case .saved:
                return "Saved"
            case .error:
                return "Voice Input Failed"
            case .setupRequired:
                return "Setup Required"
            }
        }

        switch voiceInputController.state {
        case .recording:
            return "Listening"
        case .stopping:
            return "Finishing"
        case .pendingTranscription:
            return "Saved"
        case .requestingPermission:
            return "Microphone Access"
        case .failed:
            return "Voice Input Failed"
        case .idle:
            return "Idle"
        }
    }

    private var statusColor: Color {
        if let supplementalPhase {
            switch supplementalPhase {
            case .transcribing, .inserting:
                return .blue
            case .saved:
                return .green
            case .error:
                return .red
            case .setupRequired:
                return .orange
            }
        }

        switch voiceInputController.state {
        case .recording:
            return .red
        case .requestingPermission:
            return .orange
        case .pendingTranscription:
            return .green
        case .failed:
            return .red
        default:
            return .secondary
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
            }
        }

        switch voiceInputController.state {
        case .recording:
            return recordingMode == .holdToTalk
                ? "Release the shortcut to finish dictation."
                : "Speak naturally, then click Done or press the shortcut again."
        case .stopping:
            return "Finishing the current capture and preparing it for transcription."
        case .pendingTranscription:
            return "Your recording was saved locally and will stay in history even if transcription finishes later."
        case .requestingPermission:
            return "macOS is requesting microphone access before Transcriptor can start listening."
        case .failed:
            return voiceInputController.failureMessage ?? "Recording stopped because of an error."
        case .idle:
            return "Ready"
        }
    }

    private var durationLabel: String {
        let elapsed = Int(voiceInputController.elapsedDuration)
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var showsDoneControls: Bool {
        supplementalPhase == nil && voiceInputController.state == .recording && recordingMode == .toggleToTalk
    }

    private var indicatorValues: [Double] {
        guard supplementalPhase == nil else {
            return Array(repeating: 0.18, count: max(voiceInputController.liveLevels.bars.count, 10))
        }

        if voiceInputController.state == .recording {
            return voiceInputController.liveLevels.bars.map(Double.init)
        }

        return Array(repeating: 0.18, count: max(voiceInputController.liveLevels.bars.count, 10))
    }

    private var statusSymbol: String {
        if let supplementalPhase {
            switch supplementalPhase {
            case .transcribing:
                return "waveform.badge.magnifyingglass"
            case .inserting:
                return "text.cursor"
            case .saved:
                return "checkmark.circle.fill"
            case .error:
                return "exclamationmark.triangle.fill"
            case .setupRequired:
                return "gearshape.fill"
            }
        }

        switch voiceInputController.state {
        case .recording:
            return "mic.fill"
        case .stopping:
            return "hourglass"
        case .pendingTranscription:
            return "checkmark.circle.fill"
        case .requestingPermission:
            return "lock.shield"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .idle:
            return "mic"
        }
    }

    private var indicatorColor: Color {
        guard supplementalPhase == nil, voiceInputController.state == .recording else {
            return .secondary.opacity(0.4)
        }

        return .accentColor
    }

    private var showsDuration: Bool {
        supplementalPhase == nil
    }

    private var showsProgressIndicator: Bool {
        guard let supplementalPhase else {
            return false
        }

        switch supplementalPhase {
        case .transcribing, .inserting:
            return true
        case .saved, .error, .setupRequired:
            return false
        }
    }
}
