import SwiftUI

public struct ImportAudioView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionCard(
                    title: "Import Audio",
                    subtitle: "Bring existing recordings into Sotto for future transcription."
                ) {
                    Text("Supported formats")
                        .font(.headline)

                    HStack(spacing: 10) {
                        ForEach(SupportedImportFormat.allCases) { format in
                            Text(format.fileExtensionLabel)
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.quaternary, in: Capsule())
                        }
                    }

                    Text("Import is not wired yet. This screen is a native placeholder for the future picker, queue, and metadata flow.")
                        .foregroundStyle(.secondary)
                }

                SectionCard(
                    title: "Planned Workflow",
                    subtitle: "The import pipeline will stay local-first."
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Choose one or more local audio files", systemImage: "folder")
                        Label("Preview waveform and metadata before import", systemImage: "waveform")
                        Label("Transcribe locally or re-run later with another model", systemImage: "arrow.trianglehead.2.clockwise")
                        Label("Export final transcript as plain text", systemImage: "doc.plaintext")
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .navigationTitle("Import Audio")
    }
}
