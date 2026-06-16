import SwiftUI

/// Interactive result card shown in the floating overlay after a capture:
/// either a transcript preview (Flow A, no focused field) or a recorder result
/// when transcription isn't configured (Flow B).
struct ResultOverlayView: View {
    enum Content: Equatable {
        case preview(OverlayPreviewPayload)
        case unconfigured(OverlayUnconfiguredPayload)
    }

    let content: Content
    let actions: RecordingOverlayActions

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            switch content {
            case let .preview(payload):
                previewBody(payload)
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
            SidebarIconView(systemImage: headerSymbol, size: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(headerTitle)
                    .font(.headline)
                Text(headerSubtitle)
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

    // MARK: - Preview (Flow A)

    private func previewBody(_ payload: OverlayPreviewPayload) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(payload.transcript.isEmpty ? "No transcript text." : payload.transcript)
                .font(.callout)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button("Show All") { actions.showAll(payload.entryID) }
                    .fixedSize()

                Button("Copy") { actions.copy(payload.entryID) }
                    .disabled(payload.transcript.isEmpty)
                    .fixedSize()

                retranscribeMenu(payload.entryID)

                Spacer()

                Button(role: .destructive) {
                    actions.delete(payload.entryID)
                } label: {
                    Image(systemName: "trash")
                }
                .help("Delete this recording")

                Button("Save") { actions.save(payload.entryID) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.regular)
        }
    }

    /// Always offered, even with a single model — then it just re-runs.
    private func retranscribeMenu(_ entryID: UUID) -> some View {
        let options = actions.retranscribeOptions()
        return Menu("Re-transcribe") {
            if options.isEmpty {
                Text("No models available")
            } else {
                let local = options.filter { !$0.isCloud }
                let cloud = options.filter(\.isCloud)

                if !local.isEmpty {
                    Section("Local Models") {
                        ForEach(local) { option in
                            Button(option.title) { actions.retranscribe(entryID, option) }
                        }
                    }
                }
                if !cloud.isEmpty {
                    Section("Cloud Providers") {
                        ForEach(cloud) { option in
                            Button(option.title) { actions.retranscribe(entryID, option) }
                        }
                    }
                }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Re-transcribe with a different model")
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

    // MARK: - Header styling

    private var headerSymbol: String {
        switch content {
        case .preview: "text.quote"
        case .unconfigured: "mic.badge.plus"
        }
    }

    private var headerTitle: String {
        switch content {
        case .preview: "Transcript Ready"
        case .unconfigured: "Recording Saved"
        }
    }

    private var headerSubtitle: String {
        switch content {
        case let .preview(payload):
            payload.modelName.map { "\($0) • \(durationLabel(payload.durationSeconds))" } ?? durationLabel(payload.durationSeconds)
        case .unconfigured:
            "No transcription model set up"
        }
    }

    private func durationLabel(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
