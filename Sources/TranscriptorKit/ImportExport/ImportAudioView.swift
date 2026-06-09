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
        GeometryReader { proxy in
            let compact = proxy.size.width < 930

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Import Audio")
                            .font(.largeTitle.weight(.semibold))

                        Text("Add audio files from Finder. Imported copies are stored inside Transcriptor so history stays durable after the original file moves.")
                            .foregroundStyle(.secondary)
                    }

                    if compact {
                        VStack(alignment: .leading, spacing: 18) {
                            dropZone
                            importFactsPanel
                        }
                    } else {
                        HStack(alignment: .top, spacing: 20) {
                            dropZone
                                .frame(maxWidth: .infinity)

                            importFactsPanel
                                .frame(maxWidth: 340)
                        }
                    }

                    SectionCard(
                        title: "Recent Imports",
                        subtitle: "These rows come from the real persisted history store."
                    ) {
                        if appState.recentImports.isEmpty {
                            ContentUnavailableView(
                                "No Imports Yet",
                                systemImage: "square.and.arrow.down",
                                description: Text("Choose files or drag audio here to add the first import.")
                            )
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(appState.recentImports.enumerated()), id: \.element.id) { index, item in
                                    recentImportRow(item: item)

                                    if index < appState.recentImports.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
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
        VStack(spacing: 14) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(isDropTargeted ? Color.accentColor : .secondary)
                .frame(width: 64, height: 64)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(isDropTargeted ? "Release to import audio" : "Drop audio files here")
                .font(.title3.weight(.semibold))

            Text(isDropTargeted ? "Files will be copied into Transcriptor-managed storage" : "or choose files from Finder")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                ForEach([SupportedImportFormat.mp3, .m4a, .wav, .webm]) { format in
                    formatChip(for: format)
                }
            }

            HStack(spacing: 10) {
                Button("Choose Files…") {
                    isFileImporterPresented = true
                }
                .keyboardShortcut("I", modifiers: [.command, .shift])

                shortcutBadge
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .padding(24)
        .background((isDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [8, 8]))
                .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35))
        }
        .onTapGesture {
            isFileImporterPresented = true
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            handleDroppedProviders(providers)
        }
    }

    private var importFactsPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionCard(
                title: "Supported Formats",
                subtitle: "Use the native file picker or drag files directly from Finder."
            ) {
                factRow(title: "Ready", detail: "mp3, m4a, wav")
                Divider()
                factRow(title: "Blocked", detail: "webm remains visible but cannot be decoded in this build yet")
            }

            SectionCard(
                title: "Storage",
                subtitle: "Imported files are copied into app-managed storage."
            ) {
                factRow(title: "Location", detail: "Application Support/Transcriptor/Imports")
                Divider()
                factRow(title: "Behavior", detail: "History stays available even if the original Finder file moves")
            }

            SectionCard(
                title: "Automation",
                subtitle: "Import behavior follows your current transcription preferences."
            ) {
                factRow(title: "Shortcut", detail: "Cmd + Shift + I")
                Divider()
                factRow(title: "Auto-transcribe", detail: appState.transcriptionPreferences.autoTranscribeAfterCapture ? "Enabled" : "Disabled")
            }

            if let importFeedbackMessage = appState.importFeedbackMessage {
                UnavailableActionBanner(message: importFeedbackMessage)
            }
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
        let backgroundStyle = format == .webm ? Color.secondary.opacity(0.16) : Color.secondary.opacity(0.12)

        return Text(format.fileExtensionLabel)
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func recentImportRow(item: RecentImportItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.status == .failed ? "exclamationmark.triangle" : "waveform")
                .foregroundStyle(item.status == .failed ? .yellow : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.fileName)
                    .font(.headline)
                    .lineLimit(1)

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
                .background(.quaternary.opacity(0.6), in: Capsule())
        }
        .padding(.vertical, 12)
    }

    private func factRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)

            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
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
