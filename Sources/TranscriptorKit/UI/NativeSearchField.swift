import AppKit
import SwiftUI

/// A genuine AppKit `NSSearchField` bridged into SwiftUI.
///
/// The previous SwiftUI `TextField` + `onTapGesture` approach could not reliably
/// take first responder when the window was not yet key, so keystrokes leaked to
/// the previously active application. A real `NSSearchField` handles its own
/// mouse-down → make-key path and gives us the exact rounded System Settings
/// appearance for free. We additionally activate the app and make the window key
/// on focus so typing always lands here.
struct NativeSearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Search"
    /// Bumped by the owner (e.g. the `Cmd+F` command) to request keyboard focus.
    /// Counters are one-shot: the field focuses when the value changes, and
    /// again on creation if the current request is non-zero (the screen was
    /// just opened by the same command).
    var focusRequest: Int = 0

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = FocusReportingSearchField()
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.sendsWholeSearchString = false
        field.sendsSearchStringImmediately = true
        field.focusRingType = .default
        field.controlSize = .regular
        field.font = .systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        // SwiftUI proposes the frame, but AppKit's intrinsic hugging otherwise
        // keeps the field at ~200 pt — visibly narrower than System Settings.
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentHuggingPriority(.defaultLow, for: .vertical)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        field.onBecomeFirstResponder = {
            // Guarantee the keystrokes route to this app, not whatever was
            // frontmost when the window appeared.
            NSApp.activate(ignoringOtherApps: true)
            field.window?.makeKey()
        }
        // A request that was issued in the same runloop turn as presenting the
        // screen must still land: retry asynchronously until the field is in a
        // window and that window can become key.
        context.coordinator.lastFocusRequest = focusRequest
        if focusRequest > 0 {
            context.coordinator.focus(field)
        }
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder

        if focusRequest != context.coordinator.lastFocusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            if focusRequest > 0 {
                context.coordinator.focus(nsView)
            }
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        private let text: Binding<String>
        var lastFocusRequest = 0

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            text.wrappedValue = field.stringValue
        }

        /// Moves first responder to the search field. SwiftUI may attach the
        /// field to its window a runloop or two after `makeNSView`, so retry a
        /// few times instead of silently dropping the request.
        func focus(_ field: NSSearchField, attempt: Int = 0) {
            DispatchQueue.main.async { [weak field] in
                guard let field else { return }
                guard let window = field.window else {
                    if attempt < 20 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            self.focus(field, attempt: attempt + 1)
                        }
                    }
                    return
                }
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                window.makeFirstResponder(field)
                // Select any existing query so typing replaces it, like ⌘F in
                // native apps.
                field.currentEditor()?.selectAll(nil)
            }
        }
    }
}

/// `NSSearchField` that reports when it becomes first responder so we can ensure
/// the host window is key.
private final class FocusReportingSearchField: NSSearchField {
    var onBecomeFirstResponder: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            onBecomeFirstResponder?()
        }
        return became
    }
}
