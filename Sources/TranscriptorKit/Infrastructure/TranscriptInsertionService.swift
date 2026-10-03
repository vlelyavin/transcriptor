import AppKit
import ApplicationServices
import Carbon
import Foundation

public enum AccessibilityPermissionStatus: String, Equatable, Sendable {
    case granted = "Granted"
    case denied = "Not Granted"
}

public enum TranscriptInsertionOutcome: Equatable, Sendable {
    case inserted(String)
    case copiedToClipboard(String)
    case savedOnly(String)
    case failed(String)

    public var message: String {
        switch self {
        case let .inserted(message),
             let .copiedToClipboard(message),
             let .savedOnly(message),
             let .failed(message):
            message
        }
    }
}

public struct TranscriptInsertionDebugSnapshot: Equatable, Sendable {
    public var capturedAppName: String?
    public var targetSummary: String
    public var lastOutcome: TranscriptInsertionOutcome?
    public var lastUpdatedAt: Date?

    public init(
        capturedAppName: String? = nil,
        targetSummary: String = "No insertion target captured yet.",
        lastOutcome: TranscriptInsertionOutcome? = nil,
        lastUpdatedAt: Date? = nil
    ) {
        self.capturedAppName = capturedAppName
        self.targetSummary = targetSummary
        self.lastOutcome = lastOutcome
        self.lastUpdatedAt = lastUpdatedAt
    }
}

@MainActor
public protocol TranscriptInsertionServing: AnyObject {
    var accessibilityPermissionStatus: AccessibilityPermissionStatus { get }
    var hasCapturedTarget: Bool { get }
    var debugSnapshot: TranscriptInsertionDebugSnapshot { get }

    func refreshPermissionStatus()
    func requestAccessibilityPermissionPrompt()
    func openAccessibilitySettings()
    func captureCurrentTargetIfNeeded()
    func clearCapturedTarget()
    func insertCapturedTranscript(_ text: String, settings: GeneralSettings) async -> TranscriptInsertionOutcome
}

@MainActor
public final class TranscriptInsertionService: TranscriptInsertionServing {
    public var accessibilityPermissionStatus: AccessibilityPermissionStatus {
        platform.isAccessibilityTrusted ? .granted : .denied
    }

    public var hasCapturedTarget: Bool {
        capturedTarget != nil
    }

    public private(set) var debugSnapshot = TranscriptInsertionDebugSnapshot()

    private let platform: any TranscriptInsertionPlatform
    private var capturedTarget: CapturedTextTarget?

    public init() {
        self.platform = LiveTranscriptInsertionPlatform()
    }

    init(platform: any TranscriptInsertionPlatform) {
        self.platform = platform
    }

    public func refreshPermissionStatus() {}

    public func requestAccessibilityPermissionPrompt() {
        _ = platform.requestAccessibilityPermissionPrompt()
    }

    public func openAccessibilitySettings() {
        platform.openAccessibilitySettings()
    }

    public func captureCurrentTargetIfNeeded() {
        let appName = platform.frontmostApplicationName()

        guard accessibilityPermissionStatus == .granted else {
            capturedTarget = nil
            debugSnapshot.capturedAppName = appName
            debugSnapshot.targetSummary = "Accessibility access is not granted, so Transcriptor cannot capture the active text field."
            return
        }

        capturedTarget = platform.captureFocusedTarget()
        debugSnapshot.capturedAppName = capturedTarget?.appName ?? appName
        debugSnapshot.targetSummary = captureSummary(for: capturedTarget)
    }

    public func clearCapturedTarget() {
        capturedTarget = nil
    }

    public func insertCapturedTranscript(_ text: String, settings: GeneralSettings) async -> TranscriptInsertionOutcome {
        defer {
            capturedTarget = nil
        }

        guard !text.isEmpty else {
            return finish(.failed("No transcript text was available to insert."))
        }

        guard settings.insertTranscriptIntoActiveApp else {
            if settings.alsoCopyTranscriptToClipboard {
                platform.copyTextToPasteboard(text)
                return finish(.copiedToClipboard("Transcript copied to the clipboard."))
            }

            return finish(.savedOnly("Transcript saved to history."))
        }

        guard accessibilityPermissionStatus == .granted else {
            return finish(copyOrSaveOnly(
                text: text,
                settings: settings,
                copiedMessage: "Accessibility access is off. Transcript copied to the clipboard so you can paste it manually.",
                savedMessage: "Accessibility access is off. Transcript saved to history. Paste manually."
            ))
        }

        guard let target = capturedTarget ?? platform.captureFocusedTarget() else {
            debugSnapshot.targetSummary = "The original text field is no longer available."
            return finish(copyOrSaveOnly(
                text: text,
                settings: settings,
                copiedMessage: "The original text field is no longer available. Transcript copied to the clipboard.",
                savedMessage: "The original text field is no longer available. Transcript saved to history."
            ))
        }

        if target.isSecureField {
            debugSnapshot.targetSummary = "Secure text field detected."
            return finish(copyOrSaveOnly(
                text: text,
                settings: settings,
                copiedMessage: "Secure text field detected. Transcript copied to the clipboard instead of being inserted.",
                savedMessage: "Secure text field detected. Transcript saved to history. Paste manually."
            ))
        }

        do {
            try await platform.activateApplication(for: target)
        } catch {
            debugSnapshot.targetSummary = "The original app is no longer available."
            return finish(copyOrSaveOnly(
                text: text,
                settings: settings,
                copiedMessage: "The original app is no longer available. Transcript copied to the clipboard.",
                savedMessage: "The original app is no longer available. Transcript saved to history."
            ))
        }

        guard platform.isTargetStillFocused(target) else {
            debugSnapshot.targetSummary = "The original insertion target lost focus before Transcriptor could insert the transcript."
            return finish(copyOrSaveOnly(
                text: text,
                settings: settings,
                copiedMessage: "The original text field changed before insertion finished. Transcript copied to the clipboard.",
                savedMessage: "The original text field changed before insertion finished. Transcript saved to history."
            ))
        }

        do {
            if try platform.insertViaAccessibility(text, into: target) {
                if settings.alsoCopyTranscriptToClipboard {
                    platform.copyTextToPasteboard(text)
                }
                debugSnapshot.targetSummary = "Transcript inserted into \(target.appName)."
                return finish(.inserted("Transcript inserted into the active app."))
            }
        } catch let error as TranscriptInsertionPlatformError {
            switch error {
            case .targetUnavailable:
                debugSnapshot.targetSummary = "The original app is no longer available."
                return finish(copyOrSaveOnly(
                    text: text,
                    settings: settings,
                    copiedMessage: "The original app is no longer available. Transcript copied to the clipboard.",
                    savedMessage: "The original app is no longer available. Transcript saved to history."
                ))
            case .secureField:
                debugSnapshot.targetSummary = "Secure text field detected."
                return finish(copyOrSaveOnly(
                    text: text,
                    settings: settings,
                    copiedMessage: "Secure text field detected. Transcript copied to the clipboard instead of being inserted.",
                    savedMessage: "Secure text field detected. Transcript saved to history. Paste manually."
                ))
            case .unsupportedTarget, .pasteFailed:
                break
            }
        } catch {}

        do {
            try await platform.pasteViaClipboard(
                text,
                into: target,
                restorePreviousClipboard: settings.restoreClipboardAfterInsertion && !settings.alsoCopyTranscriptToClipboard
            )

            if settings.alsoCopyTranscriptToClipboard {
                platform.copyTextToPasteboard(text)
            }

            // A synthetic ⌘V can't be verified into the target field, so the
            // message says "pasted" — never a stronger claim than what ran.
            debugSnapshot.targetSummary = "Transcript pasted into \(target.appName)."
            return finish(.inserted("Transcript pasted into the active app."))
        } catch let error as TranscriptInsertionPlatformError {
            switch error {
            case .targetUnavailable:
                debugSnapshot.targetSummary = "The original app is no longer available."
                return finish(copyOrSaveOnly(
                    text: text,
                    settings: settings,
                    copiedMessage: "The original app is no longer available. Transcript copied to the clipboard.",
                    savedMessage: "The original app is no longer available. Transcript saved to history."
                ))
            case .secureField:
                debugSnapshot.targetSummary = "Secure text field detected."
                return finish(copyOrSaveOnly(
                    text: text,
                    settings: settings,
                    copiedMessage: "Secure text field detected. Transcript copied to the clipboard instead of being inserted.",
                    savedMessage: "Secure text field detected. Transcript saved to history. Paste manually."
                ))
            case .pasteFailed, .unsupportedTarget:
                debugSnapshot.targetSummary = "Automatic insertion failed for the captured target."
                return finish(copyOrSaveOnly(
                    text: text,
                    settings: settings,
                    copiedMessage: "Automatic insertion failed. Transcript copied to the clipboard so you can paste it manually.",
                    savedMessage: "Automatic insertion failed. Transcript saved to history. Paste manually."
                ))
            }
        } catch {
            debugSnapshot.targetSummary = "Automatic insertion failed for the captured target."
            return finish(copyOrSaveOnly(
                text: text,
                settings: settings,
                copiedMessage: "Automatic insertion failed. Transcript copied to the clipboard so you can paste it manually.",
                savedMessage: "Automatic insertion failed. Transcript saved to history. Paste manually."
            ))
        }
    }

    private func captureSummary(for target: CapturedTextTarget?) -> String {
        guard let target else {
            return "No focused text field was captured."
        }

        if target.isSecureField {
            return "Focused secure text field captured in \(target.appName)."
        }

        return "Focused text field captured in \(target.appName)."
    }

    private func copyOrSaveOnly(
        text: String,
        settings: GeneralSettings,
        copiedMessage: String,
        savedMessage: String
    ) -> TranscriptInsertionOutcome {
        if settings.alsoCopyTranscriptToClipboard {
            platform.copyTextToPasteboard(text)
            return .copiedToClipboard(copiedMessage)
        }

        return .savedOnly(savedMessage)
    }

    private func finish(_ outcome: TranscriptInsertionOutcome) -> TranscriptInsertionOutcome {
        debugSnapshot.lastOutcome = outcome
        debugSnapshot.lastUpdatedAt = .now
        return outcome
    }
}

// kAXTrustedCheckOptionPrompt is a CF global var whose reference strict
// concurrency rejects ("shared mutable state") even from a constant — and its
// documented value is the literal string below. CFDictionary looks keys up by
// content, so we use the literal and skip the global entirely.
private let axPromptOptionKey = "AXTrustedCheckOptionPrompt"

@MainActor
protocol TranscriptInsertionPlatform {
    var isAccessibilityTrusted: Bool { get }

    func frontmostApplicationName() -> String?
    func requestAccessibilityPermissionPrompt() -> Bool
    func openAccessibilitySettings()
    func captureFocusedTarget() -> CapturedTextTarget?
    func activateApplication(for target: CapturedTextTarget) async throws
    func isTargetStillFocused(_ target: CapturedTextTarget) -> Bool
    func insertViaAccessibility(_ text: String, into target: CapturedTextTarget) throws -> Bool
    func pasteViaClipboard(_ text: String, into target: CapturedTextTarget, restorePreviousClipboard: Bool) async throws
    func copyTextToPasteboard(_ text: String)
}

enum TranscriptInsertionPlatformError: Error {
    case targetUnavailable
    case secureField
    case unsupportedTarget
    case pasteFailed
}

final class CapturedTextTarget: @unchecked Sendable {
    let appName: String
    let bundleIdentifier: String?
    let processIdentifier: pid_t
    let isSecureField: Bool
    let appElement: AXUIElement
    let focusedElement: AXUIElement

    init(
        appName: String,
        bundleIdentifier: String?,
        processIdentifier: pid_t,
        isSecureField: Bool,
        appElement: AXUIElement,
        focusedElement: AXUIElement
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.processIdentifier = processIdentifier
        self.isSecureField = isSecureField
        self.appElement = appElement
        self.focusedElement = focusedElement
    }
}

@MainActor
final class LiveTranscriptInsertionPlatform: TranscriptInsertionPlatform {
    /// Upper bound (seconds) on any single Accessibility message. Short on
    /// purpose: capture happens on the main actor at record start, so this is
    /// the longest the recording overlay can ever freeze waiting on another
    /// app's AX server. Responsive apps answer in well under this; unresponsive
    /// ones time out and we degrade gracefully to clipboard insertion.
    private static let axMessagingTimeout: Float = 0.5

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    func frontmostApplicationName() -> String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }

    /// Secure-field detection, kept as a pure function so it's unit-testable:
    /// `AXSecureTextField` is a SUBROLE (`kAXSecureTextFieldSubrole`) — a
    /// password field's role is plain `AXTextField`, so comparing the role
    /// alone could never match and every secure-field branch was dead code.
    /// The subrole is authoritative; the role-level comparison stays for
    /// non-conforming apps that report the secure marker on the role itself.
    static func isSecureFieldElement(role: String?, subrole: String?) -> Bool {
        subrole == (kAXSecureTextFieldSubrole as String) || role == (kAXSecureTextFieldSubrole as String)
    }

    /// Whether a focused element can plausibly accept inserted text. Buttons,
    /// checkboxes, and other non-text controls must never become insertion
    /// targets — a write into the wrong control is worse than a clipboard
    /// fallback. Custom editors (Electron, web content) use nonstandard roles
    /// but still expose a string value plus a selection range, which is the
    /// closest AX signal for "editable" and is treated as such here.
    static func isEditableTextElement(role: String?, hasStringValue: Bool, hasSelectionRange: Bool) -> Bool {
        let textRoles: Set<String> = [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            kAXComboBoxRole as String,
        ]
        if let role, textRoles.contains(role) {
            return true
        }

        return hasStringValue && hasSelectionRange
    }

    func requestAccessibilityPermissionPrompt() -> Bool {
        // `AXIsProcessTrusted()` alone only queries; it never registers the app
        // in Privacy ▸ Accessibility, so a user sent to System Settings finds
        // an empty list and must add Transcriptor by hand. Asking with the
        // prompt option posts the real system alert once and adds the entry.
        let options = [axPromptOptionKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func captureFocusedTarget() -> CapturedTextTarget? {
        guard
            isAccessibilityTrusted,
            let app = NSWorkspace.shared.frontmostApplication,
            // Never capture Transcriptor's own UI — e.g. a recording started
            // from the toolbar while the settings window is focused — or the
            // transcript would be aimed back at our own controls.
            app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        // Bound every Accessibility message to this app. Without a timeout, a
        // single `AXUIElementCopyAttributeValue` to a busy or AX-unfriendly
        // frontmost app blocks the calling thread for the system default (~6s,
        // and effectively forever for a wedged app). Because capture runs on the
        // main actor the instant recording starts, that block freezes the whole
        // recording overlay — the "randomly hangs, can't do anything" symptom.
        // A short timeout caps any freeze; a slow app simply isn't captured and
        // insertion falls back to the clipboard, which is the right trade-off.
        AXUIElementSetMessagingTimeout(appElement, Self.axMessagingTimeout)
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedValue else {
            return nil
        }
        let focusedElement = focusedValue as! AXUIElement
        AXUIElementSetMessagingTimeout(focusedElement, Self.axMessagingTimeout)

        let role = stringAttribute(kAXRoleAttribute as CFString, on: focusedElement)
        let subrole = stringAttribute(kAXSubroleAttribute as CFString, on: focusedElement)
        let isSecureField = Self.isSecureFieldElement(role: role, subrole: subrole)

        // Secure fields are captured (flagged) so the service can deliberately
        // choose the clipboard path; any other non-editable focus is ignored.
        guard isSecureField || Self.isEditableTextElement(
            role: role,
            hasStringValue: stringAttribute(kAXValueAttribute as CFString, on: focusedElement) != nil,
            hasSelectionRange: selectedTextRange(on: focusedElement) != nil
        ) else {
            return nil
        }

        return CapturedTextTarget(
            appName: app.localizedName ?? "Current App",
            bundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier,
            isSecureField: isSecureField,
            appElement: appElement,
            focusedElement: focusedElement
        )
    }

    func activateApplication(for target: CapturedTextTarget) async throws {
        guard let app = NSRunningApplication(processIdentifier: target.processIdentifier) else {
            throw TranscriptInsertionPlatformError.targetUnavailable
        }

        _ = app.activate()
        try? await Task.sleep(for: .milliseconds(120))
    }

    func isTargetStillFocused(_ target: CapturedTextTarget) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier else {
            return false
        }

        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(target.appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedValue else {
            return false
        }

        let focusedElement = focusedValue as! AXUIElement
        return CFEqual(focusedElement, target.focusedElement)
    }

    func insertViaAccessibility(_ text: String, into target: CapturedTextTarget) throws -> Bool {
        guard !target.isSecureField else {
            throw TranscriptInsertionPlatformError.secureField
        }

        guard NSRunningApplication(processIdentifier: target.processIdentifier) != nil else {
            throw TranscriptInsertionPlatformError.targetUnavailable
        }

        guard var selectedRange = selectedTextRange(on: target.focusedElement) else {
            return false
        }

        // Preferred path: write `AXSelectedText`, which replaces the current
        // selection at the caret — the one mutation Cocoa text views and most
        // AX-aware editors honour. Only success confirmed by re-reading the
        // value counts; an element that silently discards the write falls
        // through to the splice path (which would then read stale state and
        // bail to paste — it never double-inserts, because a confirmed write
        // already returned).
        if AXUIElementSetAttributeValue(target.focusedElement, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success,
           confirmsInsertion(text, atLocation: selectedRange.location, in: target.focusedElement) {
            selectedRange.location += (text as NSString).length
            selectedRange.length = 0
            restoreCaret(selectedRange, on: target.focusedElement)
            return true
        }

        // Fallback for elements that reject `AXSelectedText` writes: splice
        // the text into `AXValue` ourselves.
        guard let currentValue = stringAttribute(kAXValueAttribute as CFString, on: target.focusedElement) else {
            return false
        }

        let nsValue = currentValue as NSString
        let clampedLocation = min(max(selectedRange.location, 0), nsValue.length)
        let clampedLength = min(max(selectedRange.length, 0), nsValue.length - clampedLocation)
        let updatedValue = nsValue.replacingCharacters(in: NSRange(location: clampedLocation, length: clampedLength), with: text)

        guard AXUIElementSetAttributeValue(target.focusedElement, kAXValueAttribute as CFString, updatedValue as CFTypeRef) == .success else {
            return false
        }

        // CFRange/NSRange count UTF-16 units; `String.count` counts grapheme
        // clusters, so any emoji or combined character used to misplace the caret.
        selectedRange.location = clampedLocation + (text as NSString).length
        selectedRange.length = 0
        restoreCaret(selectedRange, on: target.focusedElement)

        // Verify by re-reading the value: an unconfirmed write is a failure,
        // not an "inserted" report.
        return confirmsInsertion(text, atLocation: clampedLocation, in: target.focusedElement)
    }

    /// Re-reads the element's `AXValue`: the insertion counts as confirmed only
    /// when the written text is actually present at the expected position.
    private func confirmsInsertion(_ text: String, atLocation location: Int, in element: AXUIElement) -> Bool {
        guard let value = stringAttribute(kAXValueAttribute as CFString, on: element) else {
            return false
        }

        let nsValue = value as NSString
        let expectedRange = NSRange(location: location, length: (text as NSString).length)
        guard nsValue.length >= expectedRange.location + expectedRange.length else {
            return false
        }

        return nsValue.substring(with: expectedRange) == text
    }

    private func restoreCaret(_ range: CFRange, on element: AXUIElement) {
        var mutableRange = range
        guard let newSelection = AXValueCreate(.cfRange, &mutableRange) else {
            return
        }
        _ = AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, newSelection)
    }

    func pasteViaClipboard(_ text: String, into target: CapturedTextTarget, restorePreviousClipboard: Bool) async throws {
        guard !target.isSecureField else {
            throw TranscriptInsertionPlatformError.secureField
        }

        guard let app = NSRunningApplication(processIdentifier: target.processIdentifier) else {
            throw TranscriptInsertionPlatformError.targetUnavailable
        }

        let clipboardSnapshot = restorePreviousClipboard ? pasteboardSnapshot() : nil
        copyTextToPasteboard(text)
        // The change count right after our write: if the count differs when we
        // get to restoring, something else touched the clipboard meanwhile —
        // don't stomp the user's newer copy.
        let expectedChangeCount = NSPasteboard.general.changeCount

        _ = app.activate()
        try? await Task.sleep(for: .milliseconds(150))

        guard sendPasteCommand() else {
            if let clipboardSnapshot, NSPasteboard.general.changeCount == expectedChangeCount {
                restorePasteboardSnapshot(clipboardSnapshot)
            }
            throw TranscriptInsertionPlatformError.pasteFailed
        }

        // The paste keystroke is asynchronous — the target app reads the
        // pasteboard on its own time, so restore only after a solid wait or
        // the field would receive the OLD clipboard contents.
        try? await Task.sleep(for: .milliseconds(400))

        if let clipboardSnapshot, NSPasteboard.general.changeCount == expectedChangeCount {
            restorePasteboardSnapshot(clipboardSnapshot)
        }
    }

    func copyTextToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func stringAttribute(_ attribute: CFString, on element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }

        return value as? String
    }

    private func selectedTextRange(on element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let value,
              // The attribute is declared AXValue-carrying but a hostile or
              // buggy AX server can hand back anything — check before casting.
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        let axValue = value as! AXValue // safe: the type ID was checked above
        guard AXValueGetType(axValue) == .cfRange else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range),
              // A caretless element reports kCFNotFound; clamping that to 0
              // would insert at the top of the document — refuse instead.
              range.location != kCFNotFound else {
            return nil
        }
        return range
    }

    private func sendPasteCommand() -> Bool {
        guard
            let source = CGEventSource(stateID: .combinedSessionState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
        return true
    }

    private func pasteboardSnapshot() -> [PasteboardItemSnapshot] {
        let pasteboard = NSPasteboard.general
        return pasteboard.pasteboardItems?.map { item in
            let dataByType = Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type.rawValue, $0) }
            })
            return PasteboardItemSnapshot(dataByType: dataByType)
        } ?? []
    }

    private func restorePasteboardSnapshot(_ snapshot: [PasteboardItemSnapshot]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        for itemSnapshot in snapshot {
            let item = NSPasteboardItem()
            for (type, data) in itemSnapshot.dataByType {
                item.setData(data, forType: NSPasteboard.PasteboardType(type))
            }
            pasteboard.writeObjects([item])
        }
    }
}

private struct PasteboardItemSnapshot: Sendable {
    var dataByType: [String: Data]
}
