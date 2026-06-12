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

        // Onboarding: force-show with TRANSCRIPTOR_QA_ONBOARDING=1, otherwise
        // suppress the first-launch guide during any QA run so it doesn't block
        // screenshots of other screens.
        if environment["TRANSCRIPTOR_QA_ONBOARDING"] == "1" {
            appState.hasSeenWelcomeGuide = false
        } else if environment.keys.contains(where: { $0.hasPrefix("TRANSCRIPTOR_QA_") }) {
            appState.hasSeenWelcomeGuide = true
        }

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

        if environment["TRANSCRIPTOR_QA_OPEN_SETTINGS"] == "1" {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                appState.openSettings(pane: nil)
            }
        }

        if let snapshotPathPrefix = environment["TRANSCRIPTOR_QA_SNAPSHOT"] {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                Self.writeWindowSnapshots(pathPrefix: snapshotPathPrefix)
                NSApp.terminate(nil)
            }
        }
    }

    /// Renders each visible window's view hierarchy in-process (no Screen
    /// Recording permission required) and writes PNGs for QA review.
    @MainActor
    private static func writeWindowSnapshots(pathPrefix: String) {
        for (index, window) in NSApp.windows.enumerated() where window.isVisible {
            guard let contentView = window.contentView else {
                continue
            }
            let view = contentView.superview ?? contentView
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                continue
            }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                continue
            }
            let suffix = NSApp.windows.count > 1 ? "-w\(index)" : ""
            try? data.write(to: URL(fileURLWithPath: "\(pathPrefix)\(suffix).png"))
        }
    }

    var body: some Scene {
        WindowGroup {
            MainWindowView(appState: appState)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appState.openSettings()
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

                Button("Settings…") {
                    appState.openSettings()
                }
            }
        }
    }
}
