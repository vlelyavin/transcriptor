import SwiftUI

public struct RecordingOverlayView: View {
    @Bindable private var voiceInputController: VoiceInputController
    private let overlayState: OverlayState
    private let recordingMode: RecordingMode
    private let stopAction: () -> Void
    private let cancelAction: () -> Void

    public init(
        voiceInputController: VoiceInputController,
        overlayState: OverlayState,
        recordingMode: RecordingMode,
        stopAction: @escaping () -> Void,
        cancelAction: @escaping () -> Void
    ) {
        self.voiceInputController = voiceInputController
        self.overlayState = overlayState
        self.recordingMode = recordingMode
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

            Text(durationLabel)
                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)

            if overlayState.showsLiveAudioIndicator {
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
        switch voiceInputController.state {
        case .recording:
            "Listening"
        case .stopping:
            "Finishing"
        case .pendingTranscription:
            "Saved"
        case .requestingPermission:
            "Microphone Access"
        case .failed:
            "Voice Input Failed"
        case .idle:
            "Idle"
        }
    }

    private var statusColor: Color {
        switch voiceInputController.state {
        case .recording:
            .red
        case .requestingPermission:
            .orange
        case .pendingTranscription:
            .green
        case .failed:
            .red
        default:
            .secondary
        }
    }

    private var statusSubtitle: String {
        switch voiceInputController.state {
        case .recording:
            recordingMode == .holdToTalk ? "Release the shortcut to finish dictation." : "Speak naturally, then click Done or press the shortcut again."
        case .stopping:
            "Finishing the current capture and preparing it for transcription."
        case .pendingTranscription:
            "Your recording was saved locally and will stay in history even if transcription finishes later."
        case .requestingPermission:
            "macOS is requesting microphone access before Transcriptor can start listening."
        case .failed:
            voiceInputController.failureMessage ?? "Recording stopped because of an error."
        case .idle:
            "Ready"
        }
    }

    private var durationLabel: String {
        let elapsed = Int(voiceInputController.elapsedDuration)
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var showsDoneControls: Bool {
        voiceInputController.state == .recording && recordingMode == .toggleToTalk
    }

    private var hintText: String? {
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
        if voiceInputController.state == .recording {
            return voiceInputController.liveLevels.bars.map(Double.init)
        }

        return Array(repeating: 0.18, count: max(voiceInputController.liveLevels.bars.count, 10))
    }

    private var statusSymbol: String {
        switch voiceInputController.state {
        case .recording:
            "mic.fill"
        case .stopping:
            "hourglass"
        case .pendingTranscription:
            "checkmark.circle.fill"
        case .requestingPermission:
            "lock.shield"
        case .failed:
            "exclamationmark.triangle.fill"
        case .idle:
            "mic"
        }
    }

    private var indicatorGradient: LinearGradient {
        switch voiceInputController.state {
        case .recording:
            LinearGradient(colors: [.red, .pink], startPoint: .bottom, endPoint: .top)
        case .pendingTranscription:
            LinearGradient(colors: [.green, .mint], startPoint: .bottom, endPoint: .top)
        case .failed:
            LinearGradient(colors: [.red, .orange], startPoint: .bottom, endPoint: .top)
        case .requestingPermission:
            LinearGradient(colors: [.orange, .yellow], startPoint: .bottom, endPoint: .top)
        default:
            LinearGradient(colors: [.gray.opacity(0.6), .secondary], startPoint: .bottom, endPoint: .top)
        }
    }
}
