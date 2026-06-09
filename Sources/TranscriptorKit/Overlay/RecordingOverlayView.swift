import SwiftUI

public struct RecordingOverlayView: View {
    @Bindable private var voiceInputController: VoiceInputController
    private let overlayState: OverlayState

    public init(
        voiceInputController: VoiceInputController,
        overlayState: OverlayState
    ) {
        self.voiceInputController = voiceInputController
        self.overlayState = overlayState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 10) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)

                    Text(statusTitle)
                        .font(.headline)
                }

                Spacer()

                Text(durationLabel)
                    .font(.system(.headline, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if overlayState.showsLiveAudioIndicator {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(voiceInputController.liveLevels.bars.enumerated()), id: \.offset) { _, value in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(indicatorGradient)
                            .frame(width: 16, height: max(10, CGFloat(value) * 56))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeOut(duration: 0.12), value: voiceInputController.liveLevels.bars)
            }

            Text(statusSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                metricPill(title: "RMS", value: String(format: "%.2f", voiceInputController.liveLevels.rms))
                metricPill(title: "Peak", value: String(format: "%.2f", voiceInputController.liveLevels.peak))
            }
        }
        .padding(18)
        .frame(width: 340)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var statusTitle: String {
        switch voiceInputController.state {
        case .recording:
            "Recording"
        case .stopping:
            "Stopping"
        case .pendingTranscription:
            "Queued Locally"
        case .requestingPermission:
            "Requesting permission"
        case .failed:
            "Recording failed"
        case .idle:
            "Idle"
        }
    }

    private var statusColor: Color {
        switch voiceInputController.state {
        case .recording:
            .red
        case .requestingPermission:
            .yellow
        case .pendingTranscription:
            .green
        case .failed:
            .orange
        default:
            .secondary
        }
    }

    private var statusSubtitle: String {
        switch voiceInputController.state {
        case .recording:
            "Voice input is live. The overlay stays above other windows without stealing focus."
        case .stopping:
            "Finishing the current capture and saving it locally."
        case .pendingTranscription:
            "The recording is saved locally and ready for transcription."
        case .requestingPermission:
            "macOS is asking for microphone access before recording can start."
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

    private func metricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var indicatorGradient: LinearGradient {
        switch voiceInputController.state {
        case .recording:
            LinearGradient(colors: [.red, .orange], startPoint: .bottom, endPoint: .top)
        case .pendingTranscription:
            LinearGradient(colors: [.green, .mint], startPoint: .bottom, endPoint: .top)
        case .failed:
            LinearGradient(colors: [.orange, .yellow], startPoint: .bottom, endPoint: .top)
        default:
            LinearGradient(colors: [.gray, .secondary], startPoint: .bottom, endPoint: .top)
        }
    }
}
