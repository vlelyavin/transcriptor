import Foundation

/// A small, rotating, human-readable log for audio-capture failures.
///
/// The unified system log is the right place for routine diagnostics, but the
/// AirPods failures users actually report are intermittent and happen on a
/// machine the developer does not own: by the time the user agrees to look, the
/// window has long scrolled away. This file is the durable copy — it records the
/// route, formats, watchdog and engine events of every recording attempt so a
/// single "it failed again" can be diagnosed after the fact, from Settings ▸
/// Advanced.
public final class RecordingDiagnosticsLog: @unchecked Sendable {
    public static let shared = RecordingDiagnosticsLog()

    /// Rotate at this size; one previous file is kept.
    public static let maximumBytes = 256 * 1_024
    public static let fileName = "recording-diagnostics.log"

    private let layout: AppStorageLayout
    private let fileManager: FileManager
    private let lock = NSLock()

    public init(
        layout: AppStorageLayout = AppStorageLayout(),
        fileManager: FileManager = .default
    ) {
        self.layout = layout
        self.fileManager = fileManager
    }

    public var fileURL: URL? {
        try? layout.logsDirectory().appendingPathComponent(Self.fileName, isDirectory: false)
    }

    /// Appends one timestamped line. Safe from any thread; never throws.
    public func record(_ category: String, _ message: String) {
        append("[\(category)] \(Self.singleLine(message))")
    }

    /// Appends an already-formatted line (used by the recorder for multi-part
    /// start summaries).
    public func recordLine(_ line: String) {
        append(Self.singleLine(line))
    }

    /// The last `limit` lines, oldest first. Returns `[]` when nothing has been
    /// logged yet.
    public func recentLines(limit: Int = 40) -> [String] {
        guard limit > 0, let fileURL else {
            return []
        }

        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8) else {
            return []
        }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        return Array(lines.suffix(limit))
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        guard let fileURL else {
            return
        }
        try? fileManager.removeItem(at: fileURL)
        try? fileManager.removeItem(at: previousFileURL(for: fileURL))
    }

    // MARK: - Writing

    private func append(_ body: String) {
        guard let fileURL else {
            return
        }

        let line = "\(Self.timestamp()) \(body)\n"
        guard let data = line.data(using: .utf8) else {
            return
        }

        lock.lock()
        defer { lock.unlock() }

        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try rotateIfNeeded(at: fileURL, appendingBytes: data.count)

            if !fileManager.fileExists(atPath: fileURL.path) {
                fileManager.createFile(atPath: fileURL.path, contents: nil)
            }

            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            // Diagnostics must never take the recorder down with them.
        }
    }

    private func rotateIfNeeded(at fileURL: URL, appendingBytes: Int) throws {
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let size = (attributes[.size] as? NSNumber)?.intValue,
              size + appendingBytes > Self.maximumBytes else {
            return
        }

        let previousURL = previousFileURL(for: fileURL)
        try? fileManager.removeItem(at: previousURL)
        try fileManager.moveItem(at: fileURL, to: previousURL)
    }

    private func previousFileURL(for fileURL: URL) -> URL {
        fileURL.deletingPathExtension()
            .appendingPathExtension("1")
            .appendingPathExtension(fileURL.pathExtension)
    }

    private static func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }

    private static func singleLine(_ message: String) -> String {
        message
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
