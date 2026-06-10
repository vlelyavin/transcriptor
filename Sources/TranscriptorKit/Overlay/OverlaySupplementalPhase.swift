import Foundation

public enum OverlaySupplementalPhase: Equatable, Sendable {
    case transcribing(String)
    case inserting(String)
    case saved(String)
    case error(String)
    case setupRequired(String)
}
