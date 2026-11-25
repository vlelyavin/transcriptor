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
        HStack(spacing: 8) {
            if configuration != HotkeyConfiguration(), !isCapturing {
                Button("Reset") {
                    configuration = HotkeyConfiguration()
                }
            }

            Button {
                if isCapturing {
                    stopCapturing()
                } else {
                    startCapturing()
                }
            } label: {
                Text(isCapturing ? "Type Shortcut…" : configuration.displayString)
                    .frame(minWidth: 64)
            }
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
