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

@MainActor
public protocol TranscriptInsertionServing: AnyObject {
    var accessibilityPermissionStatus: AccessibilityPermissionStatus { get }
    var hasCapturedTarget: Bool { get }

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
        guard accessibilityPermissionStatus == .granted else {
            capturedTarget = nil
            return
        }

        capturedTarget = platform.captureFocusedTarget()
    }

    public func clearCapturedTarget() {
        capturedTarget = nil
    }

    public func insertCapturedTranscript(_ text: String, settings: GeneralSettings) async -> TranscriptInsertionOutcome {
        defer {
            capturedTarget = nil
        }

        guard !text.isEmpty else {
            return .failed("No transcript text was available to insert.")
        }

        guard settings.insertTranscriptIntoActiveApp else {
            if settings.alsoCopyTranscriptToClipboard {
                platform.copyTextToPasteboard(text)
                return .copiedToClipboard("Transcript copied to the clipboard.")
            }

            return .savedOnly("Transcript saved to history.")
        }

        guard accessibilityPermissionStatus == .granted else {
            if settings.alsoCopyTranscriptToClipboard {
                platform.copyTextToPasteboard(text)
                return .copiedToClipboard("Accessibility access is off. Transcript copied to the clipboard so you can paste it manually.")
            }

            return .savedOnly("Accessibility access is off. Transcript saved to history. Paste manually.")
        }

        guard let target = capturedTarget ?? platform.captureFocusedTarget() else {
            if settings.alsoCopyTranscriptToClipboard {
                platform.copyTextToPasteboard(text)
                return .copiedToClipboard("The original text field is no longer available. Transcript copied to the clipboard.")
            }

            return .savedOnly("The original text field is no longer available. Transcript saved to history.")
        }

        if target.isSecureField {
            if settings.alsoCopyTranscriptToClipboard {
                platform.copyTextToPasteboard(text)
                return .copiedToClipboard("Secure text field detected. Transcript copied to the clipboard instead of being inserted.")
            }

            return .savedOnly("Secure text field detected. Transcript saved to history. Paste manually.")
        }

        do {
            if try platform.insertViaAccessibility(text, into: target) {
                if settings.alsoCopyTranscriptToClipboard {
                    platform.copyTextToPasteboard(text)
                }
                return .inserted("Transcript inserted into the active app.")
            }
        } catch let error as TranscriptInsertionPlatformError {
            switch error {
            case .targetUnavailable:
                if settings.alsoCopyTranscriptToClipboard {
                    platform.copyTextToPasteboard(text)
                    return .copiedToClipboard("The original app is no longer available. Transcript copied to the clipboard.")
                }

                return .savedOnly("The original app is no longer available. Transcript saved to history.")
            case .secureField:
                if settings.alsoCopyTranscriptToClipboard {
                    platform.copyTextToPasteboard(text)
                    return .copiedToClipboard("Secure text field detected. Transcript copied to the clipboard instead of being inserted.")
                }

                return .savedOnly("Secure text field detected. Transcript saved to history. Paste manually.")
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

            return .inserted("Transcript inserted into the active app.")
        } catch let error as TranscriptInsertionPlatformError {
            switch error {
            case .targetUnavailable:
                if settings.alsoCopyTranscriptToClipboard {
                    platform.copyTextToPasteboard(text)
                    return .copiedToClipboard("The original app is no longer available. Transcript copied to the clipboard.")
                }

                return .savedOnly("The original app is no longer available. Transcript saved to history.")
            case .secureField:
                if settings.alsoCopyTranscriptToClipboard {
                    platform.copyTextToPasteboard(text)
                    return .copiedToClipboard("Secure text field detected. Transcript copied to the clipboard instead of being inserted.")
                }

                return .savedOnly("Secure text field detected. Transcript saved to history. Paste manually.")
            case .pasteFailed, .unsupportedTarget:
                if settings.alsoCopyTranscriptToClipboard {
                    platform.copyTextToPasteboard(text)
                    return .copiedToClipboard("Automatic insertion failed. Transcript copied to the clipboard so you can paste it manually.")
                }

                return .savedOnly("Automatic insertion failed. Transcript saved to history. Paste manually.")
            }
        } catch {
            if settings.alsoCopyTranscriptToClipboard {
                platform.copyTextToPasteboard(text)
                return .copiedToClipboard("Automatic insertion failed. Transcript copied to the clipboard so you can paste it manually.")
            }

            return .savedOnly("Automatic insertion failed. Transcript saved to history. Paste manually.")
        }
    }
}

@MainActor
protocol TranscriptInsertionPlatform {
    var isAccessibilityTrusted: Bool { get }

    func requestAccessibilityPermissionPrompt() -> Bool
    func openAccessibilitySettings()
    func captureFocusedTarget() -> CapturedTextTarget?
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
    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermissionPrompt() -> Bool {
        openAccessibilitySettings()
        return isAccessibilityTrusted
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
            let app = NSWorkspace.shared.frontmostApplication
        else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedValue else {
            return nil
        }
        let focusedElement = focusedValue as! AXUIElement

        let role = stringAttribute(kAXRoleAttribute as CFString, on: focusedElement)
        let isSecureField = role == "AXSecureTextField"

        return CapturedTextTarget(
            appName: app.localizedName ?? "Current App",
            bundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier,
            isSecureField: isSecureField,
            appElement: appElement,
            focusedElement: focusedElement
        )
    }

    func insertViaAccessibility(_ text: String, into target: CapturedTextTarget) throws -> Bool {
        guard !target.isSecureField else {
            throw TranscriptInsertionPlatformError.secureField
        }

        guard NSRunningApplication(processIdentifier: target.processIdentifier) != nil else {
            throw TranscriptInsertionPlatformError.targetUnavailable
        }

        guard let currentValue = stringAttribute(kAXValueAttribute as CFString, on: target.focusedElement),
              var selectedRange = selectedTextRange(on: target.focusedElement) else {
            return false
        }

        let nsValue = currentValue as NSString
        let clampedLocation = min(max(selectedRange.location, 0), nsValue.length)
        let clampedLength = min(max(selectedRange.length, 0), nsValue.length - clampedLocation)
        let replacementRange = NSRange(location: clampedLocation, length: clampedLength)
        let updatedValue = nsValue.replacingCharacters(in: replacementRange, with: text)

        let setResult = AXUIElementSetAttributeValue(target.focusedElement, kAXValueAttribute as CFString, updatedValue as CFTypeRef)
        guard setResult == .success else {
            return false
        }

        selectedRange.location = clampedLocation + text.count
        selectedRange.length = 0
        if let newSelection = axValue(for: selectedRange) {
            _ = AXUIElementSetAttributeValue(target.focusedElement, kAXSelectedTextRangeAttribute as CFString, newSelection)
        }

        return true
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

        _ = app.activate()
        try? await Task.sleep(for: .milliseconds(150))

        guard sendPasteCommand() else {
            if let clipboardSnapshot {
                restorePasteboardSnapshot(clipboardSnapshot)
            }
            throw TranscriptInsertionPlatformError.pasteFailed
        }

        try? await Task.sleep(for: .milliseconds(250))

        if let clipboardSnapshot {
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
              let value else {
            return nil
        }
        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cfRange else {
            return nil
        }

        var range = CFRange()
        return AXValueGetValue(axValue, .cfRange, &range) ? range : nil
    }

    private func axValue(for range: CFRange) -> AXValue? {
        var mutableRange = range
        return AXValueCreate(.cfRange, &mutableRange)
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
