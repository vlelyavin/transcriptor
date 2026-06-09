import SwiftUI
import UniformTypeIdentifiers

public struct ImportAudioView: View {
    @State private var isDropTargeted = false
    @State private var isFileImporterPresented = false
    @Bindable private var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

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

                        Text("Imported files are copied into Transcriptor-managed local storage so history remains durable across app restarts.")
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16),
                        ], spacing: 16) {
                            importCategoryCard(
                                title: "Voice Memos",
                                detail: "MP3 or M4A from the Finder",
                                systemImage: "waveform.and.mic",
                                tint: .orange
                            )
                            importCategoryCard(
                                title: "Meeting Recordings",
                                detail: "WAV for the cleanest local playback",
                                systemImage: "video",
                                tint: .blue
                            )
                            importCategoryCard(
                                title: "Local Audio Archive",
                                detail: "Recent imports stay in Application Support",
                                systemImage: "internaldrive",
                                tint: .green
                            )
                            importCategoryCard(
                                title: "WebM Status",
                                detail: "Visible in the picker, but not transcodable yet",
                                systemImage: "exclamationmark.triangle",
                                tint: .yellow
                            )
                        }

                        HStack(spacing: 10) {
                            Button("Import Audio") {
                                isFileImporterPresented = true
                            }
                            .keyboardShortcut("I", modifiers: [.command, .shift])

                            shortcutBadge
                        }

                        if let importFeedbackMessage = appState.importFeedbackMessage {
                            UnavailableActionBanner(message: importFeedbackMessage)
                        } else {
                            Text("`.webm` files remain visible for parity, but they are imported into storage as failed items because this build does not yet ship a reliable WebM decoder/transcoder.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("Finder imports use standard user-selected file access. Once copied into Application Support, the app no longer depends on the original file staying in place.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                SectionCard(
                    title: "Recent Imports",
                    subtitle: "These rows come from the real persisted history store."
                ) {
                    if appState.recentImports.isEmpty {
                        Text("No audio imports yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(appState.recentImports) { item in
                                recentImportRow(item: item)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Import Audio")
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: supportedImportContentTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case let .success(urls):
                appState.importAudio(from: urls)
            case let .failure(error):
                appState.importFeedbackMessage = error.localizedDescription
            }
        }
    }

    private var dropZone: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(isDropTargeted ? .blue : .yellow)
                .frame(width: 88, height: 88)
                .background((isDropTargeted ? Color.blue : Color.yellow).opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            Text(isDropTargeted ? "Release to import audio" : "Drop audio files here")
                .font(.title2.weight(.semibold))

            Text(isDropTargeted ? "Files will be copied into Transcriptor-managed storage" : "or click to browse")
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(SupportedImportFormat.allCases) { format in
                    formatChip(for: format)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 380)
        .padding(28)
        .background((isDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [10, 10])
                )
                .foregroundStyle(isDropTargeted ? Color.blue : Color.secondary.opacity(0.35))
                .padding(12)
        }
        .onTapGesture {
            isFileImporterPresented = true
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            handleDroppedProviders(providers)
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

    private var supportedImportContentTypes: [UTType] {
        [
            UTType(filenameExtension: "mp3") ?? .audio,
            UTType(filenameExtension: "m4a") ?? .audio,
            UTType(filenameExtension: "wav") ?? .audio,
            UTType(filenameExtension: "webm") ?? .data
        ]
    }

    private func formatChip(for format: SupportedImportFormat) -> some View {
        let backgroundStyle = format == .webm ? Color.yellow.opacity(0.14) : Color.secondary.opacity(0.12)

        return Text(format.fileExtensionLabel)
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func importCategoryCard(title: String, detail: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 56, height: 56)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
            Image(systemName: item.status == .failed ? "exclamationmark.triangle" : "waveform")
                .foregroundStyle(item.status == .failed ? .yellow : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.fileName)
                    .font(.headline)

                Text("\(relativeDate(item.importedAt)) • \(durationLabel(item.durationSeconds)) • \(item.status.title)")
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

    private func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        guard providers.contains(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            appState.importFeedbackMessage = "Drop .mp3, .m4a, .wav, or .webm files from Finder."
            return false
        }

        let group = DispatchGroup()
        let collector = DroppedURLCollector()

        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }

                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    collector.append(url)
                } else if let url = item as? URL {
                    collector.append(url)
                }
            }
        }

        group.notify(queue: .main) {
            let droppedURLs = collector.urls
            if !droppedURLs.isEmpty {
                appState.importAudio(from: droppedURLs)
            }
        }

        return true
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

private final class DroppedURLCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL] = []

    var urls: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ url: URL) {
        lock.lock()
        storage.append(url)
        lock.unlock()
    }
}

#if DEBUG
struct ImportAudioView_Previews: PreviewProvider {
    static var previews: some View {
        ImportAudioView(appState: .preview)
            .frame(width: 1280, height: 860)
    }
}
#endif
