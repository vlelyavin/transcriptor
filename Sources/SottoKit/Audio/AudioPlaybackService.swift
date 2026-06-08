import AVFoundation
import Foundation
import Observation

public enum AudioPlaybackError: Error, LocalizedError, Equatable {
    case missingFile
    case unsupportedPath
    case failedToStart(String)

    public var errorDescription: String? {
        switch self {
        case .missingFile:
            "The audio file is missing from disk."
        case .unsupportedPath:
            "This history item does not have a playable audio file."
        case let .failedToStart(message):
            "Sotto could not start playback: \(message)"
        }
    }
}

@MainActor
@Observable
public final class AudioPlaybackService: NSObject {
    public private(set) var currentlyPlayingEntryID: UUID?
    public private(set) var isPlaying = false

    @ObservationIgnored private var player: AVAudioPlayer?

    public func togglePlayback(for entry: HistoryEntry) throws {
        guard let path = entry.preferredPlaybackPath else {
            throw AudioPlaybackError.unsupportedPath
        }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioPlaybackError.missingFile
        }

        if currentlyPlayingEntryID == entry.id, isPlaying {
            pause()
            return
        }

        stop()

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            player.play()
            self.player = player
            currentlyPlayingEntryID = entry.id
            isPlaying = true
        } catch {
            throw AudioPlaybackError.failedToStart(error.localizedDescription)
        }
    }

    public func pause() {
        player?.pause()
        isPlaying = false
    }

    public func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentlyPlayingEntryID = nil
    }
}

extension AudioPlaybackService: AVAudioPlayerDelegate {
    public nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.stop()
        }
    }
}
