import Foundation

/// Retry policy for model downloads: transient network failures are
/// retried with short backoff instead of hard-failing the user's
/// download. Model state updates flow through on every attempt.
public enum ModelDownloadRetry {

    /// Runs `body` up to `maxAttempts` times with 1.5 s / 4 s backoff
    /// between attempts. `CancellationError` aborts immediately.
    public static func run(maxAttempts: Int = 3, _ body: @escaping () async throws -> Void) async throws {
        var attempt = 0
        while true {
            attempt += 1
            do {
                try await body()
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if attempt >= maxAttempts {
                    throw error
                }
                let delay: UInt64 = attempt == 1 ? 1_500_000_000 : 4_000_000_000
                try? await Task.sleep(nanoseconds: delay)
            }
        }
    }
}
