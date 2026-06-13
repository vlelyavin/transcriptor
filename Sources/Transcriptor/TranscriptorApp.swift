import AppKit
import SwiftUI
import TranscriptorKit

/// Promotes the process to a regular foreground app and activates it on launch.
///
/// Without this, an executable launched outside a fully-registered app bundle
/// (e.g. `swift run`, or a freshly built bundle that LaunchServices hasn't
/// indexed) can come up as an accessory/background process: its window can't
/// become key, so keystrokes leak to whatever app was frontmost — the reported
/// "typing into search goes to the previous app" bug. Forcing `.regular` also
/// ensures the app participates in the system light/dark appearance instead of
/// being stuck in the default aqua (light) appearance.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
}

@main
struct TranscriptorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
            // The setup gate is mandatory at runtime, but for QA captures of
            // other screens it would otherwise cover everything — suppress it.
            appState.suppressSetupGate = true
        }

        if let rawScreen = environment["TRANSCRIPTOR_QA_SCREEN"],
           let screen = NavigationScreen(rawValue: rawScreen) {
            appState.selectedScreen = screen
        }

        if let rawPane = environment["TRANSCRIPTOR_QA_SETTINGS_PANE"],
           let pane = SettingsPane(rawValue: rawPane) {
            appState.selectedSettingsPane = pane
        }

        // Opens the first history entry's detail pane so QA can screenshot it
        // (the detail otherwise only appears after a tap in the compact layout).
        if environment["TRANSCRIPTOR_QA_HISTORY_DETAIL"] == "1",
           let firstEntryID = appState.historyStore.entries.first?.id {
            appState.openHistoryEntry(firstEntryID)
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
