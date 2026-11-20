import Foundation

/// How long transcripts keep their audio on disk.
///
/// Transcripts themselves are never removed by retention — only audio files are.
/// `forever` is the default so an upgrade never silently deletes recordings the
/// user already had.
public enum AudioRetentionWindow: Int, CaseIterable, Identifiable, Hashable, Sendable {
    case week = 7
    case month = 30
    case quarter = 90
    case year = 365
    case forever = 0

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .week:
            "1 week"
        case .month:
            "30 days"
        case .quarter:
            "90 days"
        case .year:
            "1 year"
        case .forever:
            "Forever"
        }
    }

    /// The instant before which audio is considered expired, or `nil` when audio
    /// is kept indefinitely.
    public func cutoffDate(from now: Date = .now) -> Date? {
        guard self != .forever else {
            return nil
        }
        return Calendar.current.date(byAdding: .day, value: -rawValue, to: now)
    }
}

/// The recording-retention policy.
///
/// * `keepsRecordings` is the "Keep recordings" checkbox. Off means audio is
///   deleted as soon as a transcript exists (transcripts and history rows stay).
/// * `window` bounds how long kept audio lives; `forever` keeps it until the
///   storage cap or the user removes it.
public struct AudioRetentionSettings: Equatable, Sendable {
    public var keepsRecordings: Bool
    public var window: AudioRetentionWindow

    public init(
        keepsRecordings: Bool = true,
        window: AudioRetentionWindow = .forever
    ) {
        self.keepsRecordings = keepsRecordings
        self.window = window
    }
}
