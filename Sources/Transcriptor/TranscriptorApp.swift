import AppKit
import SwiftUI
import TranscriptorKit

@main
struct TranscriptorApp: App {
    @State private var appState: AppState
    private let menuBarStatusItemController: MenuBarStatusItemController

    init() {
        let appState = AppState()
        _appState = State(initialValue: appState)
        menuBarStatusItemController = MenuBarStatusItemController(appState: appState)
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView(appState: appState)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appState.openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

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
            }
        }
    }
}
