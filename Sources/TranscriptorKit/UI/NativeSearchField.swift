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
        field.onBecomeFirstResponder = {
            // Guarantee the keystrokes route to this app, not whatever was
            // frontmost when the window appeared.
            NSApp.activate(ignoringOtherApps: true)
            field.window?.makeKey()
        }
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        private let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            text.wrappedValue = field.stringValue
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
