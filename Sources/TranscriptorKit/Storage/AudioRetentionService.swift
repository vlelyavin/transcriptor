import Foundation

/// Applies the recording-retention policy to history entries.
///
/// Two operations, both of which leave the transcript untouched:
///
/// * **archive** — replace a device-format dictation WAV with a 16 kHz mono AAC
///   `.m4a` once its transcript exists, and
/// * **remove** — delete the audio files of an entry entirely.
///
/// The service is pure with respect to history storage: it changes files on disk
/// and returns the entry it would become. Persisting that entry is the caller's
/// job, so a failed write never leaves SwiftData pointing at a missing file.
public struct AudioRetentionService {
    public let layout: AppStorageLayout
    public let fileManager: FileManager
    private let transcoder: SpeechUploadTranscoder
    private let diagnostics: RecordingDiagnosticsLog

    public init(
        layout: AppStorageLayout = AppStorageLayout(),
        fileManager: FileManager = .default,
        transcoder: SpeechUploadTranscoder? = nil,
        diagnostics: RecordingDiagnosticsLog = .shared
    ) {
        self.layout = layout
        self.fileManager = fileManager
        self.transcoder = transcoder ?? SpeechUploadTranscoder(fileManager: fileManager)
        self.diagnostics = diagnostics
    }

    /// Every distinct recording file an entry still references.
    public func audioFileURLs(for entry: HistoryEntry) -> [URL] {
        let paths = Set([entry.originalFilePath, entry.workingFilePath].compactMap { $0 })
        return paths.map { URL(fileURLWithPath: $0) }
    }

    public func hasAudioOnDisk(for entry: HistoryEntry) -> Bool {
        audioFileURLs(for: entry).contains { fileManager.fileExists(atPath: $0.path) }
    }

    /// Converts the entry's captured WAV into a 16 kHz mono `.m4a` next to it and
    /// deletes the WAV. Returns the updated entry, or `nil` when there is nothing
    /// to do (already archived, not a dictation, audio missing) or the conversion
    /// would not be safe (the original is then kept).
    public func archiveRecording(for entry: HistoryEntry) -> HistoryEntry? {
        guard entry.sourceType == .dictation else {
            return nil
        }
        guard let originalPath = entry.originalFilePath else {
            return nil
        }

        let sourceURL = URL(fileURLWithPath: originalPath)
        guard sourceURL.pathExtension.lowercased() == SpeechAudioFormat.uploadFileExtension,
              fileManager.fileExists(atPath: sourceURL.path) else {
            return nil
        }

        let destinationURL = sourceURL
            .deletingPathExtension()
            .appendingPathExtension(SpeechAudioFormat.archiveFileExtension)
        guard destinationURL.path != sourceURL.path else {
            return nil
        }

        do {
            try transcoder.writeArchiveCopy(of: sourceURL, to: destinationURL)
        } catch {
            try? fileManager.removeItem(at: destinationURL)
            let reason = (error as? AudioTranscodeError)?.errorDescription ?? error.localizedDescription
            diagnostics.record(
                "retention",
                "archive failed for \(sourceURL.lastPathComponent): \(reason)"
            )
            return nil
        }

        let archivedBytes = (try? fileSize(for: destinationURL)) ?? 0
        guard archivedBytes > 0 else {
            try? fileManager.removeItem(at: destinationURL)
            return nil
        }

        // Only delete the original after the archive is verified on disk with a
        // real size. Both paths are repointed so playback and re-transcription
        // keep working without a second copy.
        _ = layout.removeManagedFileIfPresent(atPath: sourceURL.path)

        var updated = entry
        if updated.originalFilePath == sourceURL.path {
            updated.originalFilePath = destinationURL.path
        }
        if updated.workingFilePath == sourceURL.path {
            updated.workingFilePath = destinationURL.path
        }
        if updated.displayName == sourceURL.lastPathComponent {
            updated.displayName = destinationURL.lastPathComponent
        }
        updated.fileSizeBytes = archivedBytes

        diagnostics.record(
            "retention",
            "archived \(sourceURL.lastPathComponent) → \(destinationURL.lastPathComponent) (\(archivedBytes) bytes)"
        )
        return updated
    }

    /// Deletes the entry's audio files. Returns the updated entry, or `nil` when
    /// it references no audio at all.
    public func removeRecordings(for entry: HistoryEntry) -> HistoryEntry? {
        let urls = audioFileURLs(for: entry)
        guard !urls.isEmpty else {
            return nil
        }

        var removedAnyFile = false
        for url in urls where layout.isManagedFile(url) {
            if fileManager.fileExists(atPath: url.path) {
                if layout.removeManagedFileIfPresent(atPath: url.path) {
                    removedAnyFile = true
                }
            }
        }

        var updated = entry
        updated.originalFilePath = nil
        updated.workingFilePath = nil
        updated.fileSizeBytes = 0

        guard removedAnyFile || updated != entry else {
            return nil
        }

        diagnostics.record(
            "retention",
            "removed audio for \(entry.displayName) (\(urls.count) file(s))"
        )
        return updated
    }

    /// Entry IDs whose audio has outlived the retention window. A capture that is
    /// being transcribed right now is skipped — deleting its input mid-job would
    /// fail the transcription for no reason. Everything else, including
    /// never-transcribed dictation, follows the window the user chose.
    public func expiredEntryIDs(
        in entries: [HistoryEntry],
        settings: AudioRetentionSettings,
        now: Date = .now
    ) -> [UUID] {
        guard settings.keepsRecordings, let cutoff = settings.window.cutoffDate(from: now) else {
            return []
        }

        return entries.compactMap { entry in
            guard entry.sourceType == .dictation else {
                return nil
            }
            guard entry.createdAt < cutoff, entry.transcriptionStatus != .transcribing else {
                return nil
            }
            return hasAudioOnDisk(for: entry) ? entry.id : nil
        }
    }

    private func fileSize(for url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }
}
