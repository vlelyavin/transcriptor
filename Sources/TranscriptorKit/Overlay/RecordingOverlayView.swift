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
        VStack(spacing: 18) {
            Image(systemName: statusSymbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 64, height: 64)
                .background(statusColor.opacity(0.14), in: Circle())

            VStack(spacing: 6) {
                Text(statusTitle)
                    .font(.title3.weight(.semibold))

                Text(statusSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsDuration {
                Text(durationLabel)
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            if showsProgressIndicator {
                ProgressView()
                    .controlSize(.large)
            } else if overlayState.showsLiveAudioIndicator {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(indicatorValues.enumerated()), id: \.offset) { _, value in
                        Capsule(style: .continuous)
                            .fill(indicatorGradient)
                            .frame(width: 12, height: max(14, CGFloat(value) * 72))
                    }
                }
                .frame(height: 80)
                .animation(.easeInOut(duration: 0.16), value: indicatorValues)
            }

            if let hintText {
                Text(hintText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
            }

            if showsDoneControls {
                HStack(spacing: 12) {
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
            }
        }
        .padding(28)
        .frame(width: 430)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
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
                 let .error(message):
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

    private var hintText: String? {
        guard supplementalPhase == nil else {
            return nil
        }

        switch voiceInputController.state {
        case .recording:
            return recordingMode == .holdToTalk ? "Hold to Talk" : "Toggle to Talk"
        case .pendingTranscription:
            return "Saved to local history"
        default:
            return nil
        }
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

    private var indicatorGradient: LinearGradient {
        if let supplementalPhase {
            switch supplementalPhase {
            case .transcribing, .inserting:
                return LinearGradient(colors: [.blue, .mint], startPoint: .bottom, endPoint: .top)
            case .saved:
                return LinearGradient(colors: [.green, .mint], startPoint: .bottom, endPoint: .top)
            case .error:
                return LinearGradient(colors: [.red, .orange], startPoint: .bottom, endPoint: .top)
            }
        }

        switch voiceInputController.state {
        case .recording:
            return LinearGradient(colors: [.red, .pink], startPoint: .bottom, endPoint: .top)
        case .pendingTranscription:
            return LinearGradient(colors: [.green, .mint], startPoint: .bottom, endPoint: .top)
        case .failed:
            return LinearGradient(colors: [.red, .orange], startPoint: .bottom, endPoint: .top)
        case .requestingPermission:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .bottom, endPoint: .top)
        default:
            return LinearGradient(colors: [.gray.opacity(0.6), .secondary], startPoint: .bottom, endPoint: .top)
        }
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
        case .saved, .error:
            return false
        }
    }
}
