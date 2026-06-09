import ApplicationServices
import XCTest
@testable import TranscriptorKit

@MainActor
final class TranscriptInsertionServiceTests: XCTestCase {
    func testMissingAccessibilityFallsBackToClipboardWhenEnabled() async {
        let platform = MockTranscriptInsertionPlatform(isAccessibilityTrusted: false)
        platform.frontmostApplicationNameValue = "TextEdit"
        let service = TranscriptInsertionService(platform: platform)

        let outcome = await service.insertCapturedTranscript(
            "Hello world",
            settings: GeneralSettings(
                insertTranscriptIntoActiveApp: true,
                alsoCopyTranscriptToClipboard: true
            )
        )

        XCTAssertEqual(
            outcome,
            .copiedToClipboard("Accessibility access is off. Transcript copied to the clipboard so you can paste it manually.")
        )
        XCTAssertEqual(platform.copiedTexts, ["Hello world"])
        XCTAssertEqual(service.debugSnapshot.capturedAppName, nil)
    }

    func testSecureTargetAvoidsInsertionAndCopiesInstead() async {
        let platform = MockTranscriptInsertionPlatform(isAccessibilityTrusted: true)
        platform.capturedTarget = makeTarget(isSecureField: true)
        let service = TranscriptInsertionService(platform: platform)
        service.captureCurrentTargetIfNeeded()

        let outcome = await service.insertCapturedTranscript(
            "Secret",
            settings: GeneralSettings(
                insertTranscriptIntoActiveApp: true,
                alsoCopyTranscriptToClipboard: true
            )
        )

        XCTAssertEqual(
            outcome,
            .copiedToClipboard("Secure text field detected. Transcript copied to the clipboard instead of being inserted.")
        )
        XCTAssertEqual(platform.insertCallCount, 0)
        XCTAssertEqual(platform.copiedTexts, ["Secret"])
    }

    func testSuccessfulAccessibilityInsertionAvoidsPasteFallback() async {
        let platform = MockTranscriptInsertionPlatform(isAccessibilityTrusted: true)
        platform.capturedTarget = makeTarget()
        platform.insertReturnValue = true
        let service = TranscriptInsertionService(platform: platform)
        service.captureCurrentTargetIfNeeded()

        let outcome = await service.insertCapturedTranscript(
            "Inserted",
            settings: GeneralSettings(insertTranscriptIntoActiveApp: true)
        )

        XCTAssertEqual(outcome, .inserted("Transcript inserted into the active app."))
        XCTAssertEqual(platform.insertCallCount, 1)
        XCTAssertEqual(platform.pasteCallCount, 0)
        XCTAssertEqual(platform.activateCallCount, 1)
    }

    func testPasteFallbackRunsWhenAccessibilityMutationReturnsFalse() async {
        let platform = MockTranscriptInsertionPlatform(isAccessibilityTrusted: true)
        platform.capturedTarget = makeTarget()
        platform.insertReturnValue = false
        let service = TranscriptInsertionService(platform: platform)
        service.captureCurrentTargetIfNeeded()

        let outcome = await service.insertCapturedTranscript(
            "Fallback",
            settings: GeneralSettings(insertTranscriptIntoActiveApp: true)
        )

        XCTAssertEqual(outcome, .inserted("Transcript inserted into the active app."))
        XCTAssertEqual(platform.insertCallCount, 1)
        XCTAssertEqual(platform.pasteCallCount, 1)
    }

    func testMissingTargetSavesOnlyWhenClipboardFallbackIsDisabled() async {
        let platform = MockTranscriptInsertionPlatform(isAccessibilityTrusted: true)
        let service = TranscriptInsertionService(platform: platform)

        let outcome = await service.insertCapturedTranscript(
            "Saved only",
            settings: GeneralSettings(insertTranscriptIntoActiveApp: true)
        )

        XCTAssertEqual(
            outcome,
            .savedOnly("The original text field is no longer available. Transcript saved to history.")
        )
    }

    func testTargetFocusChangeFallsBackToClipboardInsteadOfWrongAppInsertion() async {
        let platform = MockTranscriptInsertionPlatform(isAccessibilityTrusted: true)
        platform.capturedTarget = makeTarget()
        platform.isTargetStillFocusedValue = false
        let service = TranscriptInsertionService(platform: platform)
        service.captureCurrentTargetIfNeeded()

        let outcome = await service.insertCapturedTranscript(
            "Focus moved",
            settings: GeneralSettings(
                insertTranscriptIntoActiveApp: true,
                alsoCopyTranscriptToClipboard: true
            )
        )

        XCTAssertEqual(
            outcome,
            .copiedToClipboard("The original text field changed before insertion finished. Transcript copied to the clipboard.")
        )
        XCTAssertEqual(platform.insertCallCount, 0)
        XCTAssertEqual(platform.pasteCallCount, 0)
        XCTAssertEqual(platform.copiedTexts, ["Focus moved"])
    }

    private func makeTarget(isSecureField: Bool = false) -> CapturedTextTarget {
        let appElement = AXUIElementCreateApplication(42)
        let focusedElement = AXUIElementCreateApplication(42)
        return CapturedTextTarget(
            appName: "Notes",
            bundleIdentifier: "com.example.notes",
            processIdentifier: 42,
            isSecureField: isSecureField,
            appElement: appElement,
            focusedElement: focusedElement
        )
    }
}

@MainActor
private final class MockTranscriptInsertionPlatform: TranscriptInsertionPlatform {
    let isAccessibilityTrusted: Bool
    var frontmostApplicationNameValue: String?
    var capturedTarget: CapturedTextTarget?
    var isTargetStillFocusedValue = true
    var insertReturnValue = false
    var insertError: TranscriptInsertionPlatformError?
    var pasteError: TranscriptInsertionPlatformError?
    var copiedTexts: [String] = []
    var activateCallCount = 0
    var insertCallCount = 0
    var pasteCallCount = 0

    init(isAccessibilityTrusted: Bool) {
        self.isAccessibilityTrusted = isAccessibilityTrusted
    }

    func requestAccessibilityPermissionPrompt() -> Bool {
        isAccessibilityTrusted
    }

    func frontmostApplicationName() -> String? {
        frontmostApplicationNameValue
    }

    func openAccessibilitySettings() {}

    func captureFocusedTarget() -> CapturedTextTarget? {
        capturedTarget
    }

    func activateApplication(for target: CapturedTextTarget) async throws {
        activateCallCount += 1
    }

    func isTargetStillFocused(_ target: CapturedTextTarget) -> Bool {
        isTargetStillFocusedValue
    }

    func insertViaAccessibility(_ text: String, into target: CapturedTextTarget) throws -> Bool {
        insertCallCount += 1
        if let insertError {
            throw insertError
        }
        return insertReturnValue
    }

    func pasteViaClipboard(_ text: String, into target: CapturedTextTarget, restorePreviousClipboard: Bool) async throws {
        pasteCallCount += 1
        if let pasteError {
            throw pasteError
        }
    }

    func copyTextToPasteboard(_ text: String) {
        copiedTexts.append(text)
    }
}
