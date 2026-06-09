import AppKit
import Carbon
import SwiftUI

public struct HotkeyRecorderButton: View {
    @Binding private var configuration: HotkeyConfiguration
    @State private var isCapturing = false
    @State private var monitor: Any?

    public init(configuration: Binding<HotkeyConfiguration>) {
        _configuration = configuration
    }

    public var body: some View {
        HStack(spacing: 12) {
            Button(isCapturing ? "Press Shortcut..." : configuration.displayString) {
                if isCapturing {
                    stopCapturing()
                } else {
                    startCapturing()
                }
            }

            Button("Reset") {
                configuration = HotkeyConfiguration()
            }
            .disabled(isCapturing)
        }
        .onDisappear {
            stopCapturing()
        }
    }

    private func startCapturing() {
        isCapturing = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isCapturing else {
                return event
            }

            if event.keyCode == UInt16(kVK_Escape) {
                stopCapturing()
                return nil
            }

            guard let hotkey = HotkeyConfiguration(event: event) else {
                NSSound.beep()
                return nil
            }

            configuration = hotkey
            stopCapturing()
            return nil
        }
    }

    private func stopCapturing() {
        isCapturing = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
