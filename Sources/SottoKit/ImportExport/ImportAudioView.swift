import SwiftUI
import UniformTypeIdentifiers

public struct ImportAudioView: View {
    @State private var isDropTargeted = false
    @State private var showNotImplementedMessage = false

    private let recentImports = RecentImportItem.mockItems

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 24) {
                    dropZone

                    VStack(alignment: .leading, spacing: 22) {
                        Label("Import Audio", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.blue.opacity(0.14), in: Capsule())

                        Text("Transcribe any audio file.")
                            .font(.system(size: 42, weight: .bold))

                        Text("Bring voice memos, meeting recordings, podcast clips, or any supported local file into Sotto. The import UI is ready even though real ingestion is still mocked.")
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16),
                        ], spacing: 16) {
                            importCategoryCard(
                                title: "Voice Memos",
                                systemImage: "waveform.and.mic",
                                tint: .orange
                            )
                            importCategoryCard(
                                title: "Meeting Recordings",
                                systemImage: "video",
                                tint: .blue
                            )
                            importCategoryCard(
                                title: "Podcast Episodes",
                                systemImage: "headphones",
                                tint: .purple
                            )
                            importCategoryCard(
                                title: "Any Audio File",
                                systemImage: "music.note",
                                tint: .green
                            )
                        }

                        HStack(spacing: 10) {
                            Button("Import Audio") {
                                showNotImplementedMessage = true
                            }
                            .keyboardShortcut("I", modifiers: [.command, .shift])

                            shortcutBadge
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                SectionCard(
                    title: "Recent Imports",
                    subtitle: "Mock rows that preview the future local import queue."
                ) {
                    VStack(spacing: 10) {
                        ForEach(recentImports) { item in
                            recentImportRow(item: item)
                        }
                    }
                }

                UnavailableActionBanner(
                    message: "Real file ingestion, waveform parsing, and transcription handoff are not implemented yet."
                )
            }
            .padding(24)
        }
        .navigationTitle("Import Audio")
        .alert("Import Audio", isPresented: $showNotImplementedMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The import UI is wired, but real file ingestion is not implemented yet.")
        }
    }

    private var dropZone: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.yellow)
                .frame(width: 88, height: 88)
                .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            Text("Drop audio files here")
                .font(.title2.weight(.semibold))

            Text("or click to browse")
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(SupportedImportFormat.allCases) { format in
                    Text(format.fileExtensionLabel)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 380)
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [10, 10])
                )
                .foregroundStyle(isDropTargeted ? .blue : .quaternary)
                .padding(12)
        }
        .onTapGesture {
            showNotImplementedMessage = true
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { _ in
            showNotImplementedMessage = true
            return false
        }
    }

    private var shortcutBadge: some View {
        HStack(spacing: 8) {
            Text("Shortcut")
                .foregroundStyle(.secondary)

            Text("Cmd")
            Text("+")
            Text("Shift")
            Text("+")
            Text("I")
        }
        .font(.system(.callout, design: .monospaced))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func importCategoryCard(title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 56, height: 56)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(title)
                .font(.headline)

            Spacer()
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
    }

    private func recentImportRow(item: RecentImportItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "waveform")
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.fileName)
                    .font(.headline)

                Text("\(relativeDate(item.importedAt)) • \(durationLabel(item.durationSeconds))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(item.format.fileExtensionLabel)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary, in: Capsule())
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func durationLabel(_ duration: Int) -> String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

#if DEBUG
struct ImportAudioView_Previews: PreviewProvider {
    static var previews: some View {
        ImportAudioView()
            .frame(width: 1280, height: 860)
    }
}
#endif
