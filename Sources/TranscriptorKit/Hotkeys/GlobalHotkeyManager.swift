import Carbon
import Foundation

public enum GlobalHotkeyRegistrationError: Error, LocalizedError {
    case invalidConfiguration
    case registrationFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "The selected shortcut is not valid."
        case let .registrationFailed(status):
            "Global shortcut registration failed with status \(status)."
        }
    }
}

@MainActor
public final class GlobalHotkeyManager {
    public var onPressed: (() -> Void)?
    public var onReleased: (() -> Void)?
    public private(set) var lastErrorMessage: String?
    public private(set) var currentConfiguration: HotkeyConfiguration

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    public init(configuration: HotkeyConfiguration = HotkeyConfiguration()) {
        self.currentConfiguration = configuration
    }

    public func register(_ configuration: HotkeyConfiguration) {
        unregister()
        currentConfiguration = configuration

        guard configuration.isValid else {
            lastErrorMessage = GlobalHotkeyRegistrationError.invalidConfiguration.localizedDescription
            return
        }

        installHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: fourCharCode("SOTT"), id: 1)
        let status = RegisterEventHotKey(
            UInt32(configuration.keyCode),
            configuration.carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            lastErrorMessage = GlobalHotkeyRegistrationError.registrationFailed(status).localizedDescription
            return
        }

        lastErrorMessage = nil
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else {
            return
        }

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, eventRef, userData in
                guard let userData, let eventRef else {
                    return OSStatus(eventNotHandledErr)
                }

                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handleHotkeyEvent(eventRef)
            },
            2,
            &eventTypes,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )
    }

    private func handleHotkeyEvent(_ eventRef: EventRef) -> OSStatus {
        let eventKind = GetEventKind(eventRef)
        switch eventKind {
        case UInt32(kEventHotKeyPressed):
            onPressed?()
        case UInt32(kEventHotKeyReleased):
            onReleased?()
        default:
            return OSStatus(eventNotHandledErr)
        }

        return noErr
    }

    private func fourCharCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { ($0 << 8) + OSType($1) }
    }
}
