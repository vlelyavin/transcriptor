import Foundation
import UserNotifications

/// Thin, mockable seam over `UNUserNotificationCenter`. Production posts
/// through the real center; tests inject a fake so no signed bundle is
/// required.
public protocol NotificationPosting: Sendable {
    /// Posts a banner for a transcription that could not be typed into the
    /// focused field — the transcript is on the clipboard for manual ⌘V.
    func postClipboardFallbackNotification(transcriptPreview: String) async
    /// Posts a banner for a transcription that failed outright.
    func postTranscriptionFailureNotification(message: String) async
}

/// Posts notifications through the system's notification center. Alert
/// authorization is requested lazily on the first post — never at launch —
/// and both the request and delivery fail quietly when the user has declined,
/// which is the correct degradation.
public final class UserNotificationPoster: NotificationPosting, @unchecked Sendable {
    /// `lazy` so merely constructing the poster (e.g. in tests or the preview
    /// app state) never touches the real notification center.
    private lazy var center = UNUserNotificationCenter.current()
    private var didRequestAuthorization = false
    private let lock = NSLock()

    public init() {}

    public func postClipboardFallbackNotification(transcriptPreview: String) async {
        await post(
            title: "Transcript ready",
            subtitle: "Copied to clipboard — press ⌘V",
            body: transcriptPreview
        )
    }

    public func postTranscriptionFailureNotification(message: String) async {
        await post(
            title: "Transcription failed",
            subtitle: nil,
            body: message
        )
    }

    private func post(title: String, subtitle: String?, body: String) async {
        await requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = title
        if let subtitle {
            content.subtitle = subtitle
        }
        content.body = body

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await center.add(request)
    }

    private func requestAuthorizationIfNeeded() async {
        // NSLock methods are marked unavailable in async contexts; a plain
        // MainActor-isolated flag is enough here — posts happen on the main
        // actor via the app state, and a duplicate authorization request is
        // harmless anyway.
        await MainActor.run {
            if didRequestAuthorization {
                return
            }
            didRequestAuthorization = true
            Task { @MainActor in
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
            }
        }
    }
}
