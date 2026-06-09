import AppKit
import SwiftUI
import TranscriptorKit

@main
struct TranscriptorApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainWindowView(appState: appState)
        }
        .commands {
            CommandMenu("Transcriptor") {
                Button("Import Audio") {
                    appState.selectedScreen = .importAudio
                }
                .keyboardShortcut("I", modifiers: [.command, .shift])

                Button("Search History") {
                    appState.selectedScreen = .history
                    NotificationCenter.default.post(name: .transcriptorFocusHistorySearch, object: nil)
                }
                .keyboardShortcut("F", modifiers: [.command])

                Divider()

                Button(appState.voiceInputController.isRecording ? "Stop Voice Input" : "Start Voice Input") {
                    if appState.voiceInputController.isRecording {
                        appState.voiceInputController.stopFromToolbar()
                    } else {
                        appState.voiceInputController.startFromToolbar()
                    }
                }
                .disabled(
                    appState.voiceInputController.state == .requestingPermission
                        || appState.voiceInputController.state == .stopping
                )

                Divider()

                Button("Open Settings…") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }

        Settings {
            SettingsView(appState: appState)
                .frame(minWidth: 820, minHeight: 560)
        }
    }
}
