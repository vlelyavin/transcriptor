import AppKit
import Carbon
import Foundation

public enum RecordingMode: String, CaseIterable, Identifiable, Hashable, Sendable {
    case holdToTalk
    case toggleToTalk

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .holdToTalk:
            "Hold to Talk"
        case .toggleToTalk:
            "Toggle to Talk"
        }
    }
}

public struct HotkeyConfiguration: Equatable, Sendable {
    public var keyCode: UInt32
    public var carbonModifiers: UInt32

    public init(
        keyCode: UInt32 = UInt32(kVK_Space),
        carbonModifiers: UInt32 = UInt32(optionKey | shiftKey)
    ) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    public init?(event: NSEvent) {
        let modifiers = Self.carbonModifiers(from: event.modifierFlags)
        guard modifiers != 0 else {
            return nil
        }

        self.init(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: modifiers
        )
    }

    public var isValid: Bool {
        carbonModifiers != 0
    }

    public var displayString: String {
        modifierSymbols + keyLabel
    }

    public var obviousConflictWarning: String? {
        if carbonModifiers == UInt32(cmdKey | shiftKey), keyCode == UInt32(kVK_ANSI_I) {
            return "This conflicts with Sotto's Import Audio command."
        }

        if carbonModifiers == UInt32(cmdKey), keyCode == UInt32(kVK_Space) {
            return "Command-Space often conflicts with Spotlight."
        }

        if carbonModifiers == UInt32(controlKey), keyCode == UInt32(kVK_Space) {
            return "Control-Space often conflicts with input source switching."
        }

        if carbonModifiers == UInt32(shiftKey) {
            return "Using Shift alone may conflict with normal typing in some apps."
        }

        return nil
    }

    public static func carbonModifiers(from modifierFlags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0

        if modifierFlags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }
        if modifierFlags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }
        if modifierFlags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }
        if modifierFlags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }

        return modifiers
    }

    private var modifierSymbols: String {
        var value = ""
        if carbonModifiers & UInt32(controlKey) != 0 {
            value += "^"
        }
        if carbonModifiers & UInt32(optionKey) != 0 {
            value += "⌥"
        }
        if carbonModifiers & UInt32(shiftKey) != 0 {
            value += "⇧"
        }
        if carbonModifiers & UInt32(cmdKey) != 0 {
            value += "⌘"
        }
        return value
    }

    private var keyLabel: String {
        switch keyCode {
        case UInt32(kVK_Space): "Space"
        case UInt32(kVK_Return): "Return"
        case UInt32(kVK_Tab): "Tab"
        case UInt32(kVK_Delete): "Delete"
        case UInt32(kVK_Escape): "Escape"
        case UInt32(kVK_LeftArrow): "Left"
        case UInt32(kVK_RightArrow): "Right"
        case UInt32(kVK_UpArrow): "Up"
        case UInt32(kVK_DownArrow): "Down"
        case UInt32(kVK_ANSI_A): "A"
        case UInt32(kVK_ANSI_B): "B"
        case UInt32(kVK_ANSI_C): "C"
        case UInt32(kVK_ANSI_D): "D"
        case UInt32(kVK_ANSI_E): "E"
        case UInt32(kVK_ANSI_F): "F"
        case UInt32(kVK_ANSI_G): "G"
        case UInt32(kVK_ANSI_H): "H"
        case UInt32(kVK_ANSI_I): "I"
        case UInt32(kVK_ANSI_J): "J"
        case UInt32(kVK_ANSI_K): "K"
        case UInt32(kVK_ANSI_L): "L"
        case UInt32(kVK_ANSI_M): "M"
        case UInt32(kVK_ANSI_N): "N"
        case UInt32(kVK_ANSI_O): "O"
        case UInt32(kVK_ANSI_P): "P"
        case UInt32(kVK_ANSI_Q): "Q"
        case UInt32(kVK_ANSI_R): "R"
        case UInt32(kVK_ANSI_S): "S"
        case UInt32(kVK_ANSI_T): "T"
        case UInt32(kVK_ANSI_U): "U"
        case UInt32(kVK_ANSI_V): "V"
        case UInt32(kVK_ANSI_W): "W"
        case UInt32(kVK_ANSI_X): "X"
        case UInt32(kVK_ANSI_Y): "Y"
        case UInt32(kVK_ANSI_Z): "Z"
        case UInt32(kVK_ANSI_0): "0"
        case UInt32(kVK_ANSI_1): "1"
        case UInt32(kVK_ANSI_2): "2"
        case UInt32(kVK_ANSI_3): "3"
        case UInt32(kVK_ANSI_4): "4"
        case UInt32(kVK_ANSI_5): "5"
        case UInt32(kVK_ANSI_6): "6"
        case UInt32(kVK_ANSI_7): "7"
        case UInt32(kVK_ANSI_8): "8"
        case UInt32(kVK_ANSI_9): "9"
        default: "Key \(keyCode)"
        }
    }
}
