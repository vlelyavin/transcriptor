import SwiftUI

/// Interactive result card shown in the floating overlay after a capture when
/// transcription isn't configured (Flow B): the recording was saved to history,
/// with Save/Delete and a path into model setup.
struct ResultOverlayView: View {
    enum Content: Equatable {
        case unconfigured(OverlayUnconfiguredPayload)
    }

    let content: Content
    let actions: RecordingOverlayActions

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            switch content {
            case let .unconfigured(payload):
                unconfiguredBody(payload)
            }
        }
        .padding(18)
        .frame(width: 460)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.separator, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            SidebarIconView(systemImage: "mic.badge.plus", size: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("Recording Saved")
                    .font(.headline)
                Text("No transcription model set up")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                actions.dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
    }

    // MARK: - Unconfigured (Flow B)

    private func unconfiguredBody(_ payload: OverlayUnconfiguredPayload) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label(payload.fileName, systemImage: "waveform")
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("Duration \(durationLabel(payload.durationSeconds)) • Saved to history")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Label("Transcription isn't configured.", systemImage: "exclamationmark.circle")
                .font(.caption)
                .foregroundStyle(.orange)

            HStack(spacing: 8) {
                Button("Configure Transcription") {
                    actions.configureTranscription()
                }
                .buttonStyle(.borderedProminent)

                Spacer()

                Button(role: .destructive) {
                    actions.delete(payload.entryID)
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete this recording")

                Button("Save") { actions.save(payload.entryID) }
            }
            .controlSize(.regular)
        }
    }

    private func durationLabel(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
