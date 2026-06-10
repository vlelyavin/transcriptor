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
        Self.applyQAOverridesIfRequested(to: appState)
    }

    /// Screenshot/QA automation hooks. Inactive unless TRANSCRIPTOR_QA_* environment
    /// variables are set, so normal launches are unaffected.
    private static func applyQAOverridesIfRequested(to appState: AppState) {
        let environment = ProcessInfo.processInfo.environment

        if let rawScreen = environment["TRANSCRIPTOR_QA_SCREEN"],
           let screen = NavigationScreen(rawValue: rawScreen) {
            appState.selectedScreen = screen
        }

        if let rawPane = environment["TRANSCRIPTOR_QA_SETTINGS_PANE"],
           let pane = SettingsPane(rawValue: rawPane) {
            appState.selectedSettingsPane = pane
        }

        if let appearance = environment["TRANSCRIPTOR_QA_APPEARANCE"] {
            NSApplication.shared.appearance = NSAppearance(named: appearance == "light" ? .aqua : .darkAqua)
        }

        if environment["TRANSCRIPTOR_QA_START_VOICE"] == "1" {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                appState.voiceInputController.startFromToolbar()
            }
        }
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
