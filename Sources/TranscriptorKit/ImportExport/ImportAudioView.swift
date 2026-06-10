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
        Form {
            Section {
                dropZone
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            if let importFeedbackMessage = appState.importFeedbackMessage {
                Section {
                    Label(importFeedbackMessage, systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Import Details") {
                LabeledContent("Supported formats") {
                    Text(".mp3, .m4a, .wav")
                }

                LabeledContent("Not supported") {
                    Text(".webm — no decoder in this build")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Storage") {
                    Text("Copied into Transcriptor-managed storage")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Auto-transcribe") {
                    Text(appState.transcriptionPreferences.autoTranscribeAfterCapture ? "On" : "Off")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Recent Imports") {
                if appState.recentImports.isEmpty {
                    Text("No imports yet. Choose files or drag audio here to add the first import.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.recentImports) { item in
                        recentImportRow(item: item)
                    }
                }
            }
        }
        .formStyle(.grouped)
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
        VStack(spacing: 10) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(isDropTargeted ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))

            Text(isDropTargeted ? "Release to import audio" : "Drop audio files here")
                .font(.headline)

            Text("or")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Choose Files…") {
                isFileImporterPresented = true
            }
            .keyboardShortcut("I", modifiers: [.command, .shift])
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(16)
        .background(isDropTargeted ? AnyShapeStyle(Color.accentColor.opacity(0.08)) : AnyShapeStyle(.quaternary.opacity(0.4)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .foregroundStyle(isDropTargeted ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
            handleDroppedProviders(providers)
        }
    }

    private var supportedImportContentTypes: [UTType] {
        [
            UTType(filenameExtension: "mp3") ?? .audio,
            UTType(filenameExtension: "m4a") ?? .audio,
            UTType(filenameExtension: "wav") ?? .audio,
            UTType(filenameExtension: "webm") ?? .data
        ]
    }

    private func recentImportRow(item: RecentImportItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.status == .failed ? "exclamationmark.triangle" : "waveform")
                .foregroundStyle(item.status == .failed ? AnyShapeStyle(.yellow) : AnyShapeStyle(.secondary))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text("\(relativeDate(item.importedAt)) • \(durationLabel(item.durationSeconds)) • \(item.status.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(item.format.fileExtensionLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
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
