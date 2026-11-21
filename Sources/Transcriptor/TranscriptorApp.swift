import AppKit
import SwiftUI
import TranscriptorKit

/// Owns the activation policy. Transcriptor is a menu bar app
/// (`LSUIElement`): it shows a Dock icon only when the user turned on
/// "Always show Dock icon" (or asked for one while recording). An open window
/// does NOT promote it to `.regular` — that was the bug where turning the
/// preference off still left an icon in the Dock while Settings was open.
///
/// A `.accessory` app can still own key windows: every path that opens the
/// window goes through `AppState.showMainWindow()`, which activates the app.
/// That keeps Settings usable without paying for a Dock icon.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // The policy no longer depends on which windows are open; only the
        // user's Dock preference and the recording opt-in can change it.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dockIconPreferenceChanged(_:)),
            name: .transcriptorDockIconPreferenceChanged,
            object: nil
        )
        updateActivationPolicy()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func dockIconPreferenceChanged(_ notification: Notification) {
        updateActivationPolicy()
    }

    private func updateActivationPolicy() {
        let input = AppState.dockIconPolicyInput()
        let desired: NSApplication.ActivationPolicy = DockIconPolicy.shouldShowDockIcon(for: input)
            ? .regular
            : .accessory
        guard NSApp.activationPolicy() != desired else {
            return
        }
        let wasActive = NSApp.isActive
        NSApp.setActivationPolicy(desired)
        if desired == .regular {
            applyDockIcon()
        } else if wasActive {
            // Switching to `.accessory` deactivates the app and takes key
            // status away from an open Settings window. Activate it again
            // immediately: an accessory app's window stays keyable (verified
            // with a probe), and the user keeps typing after flipping the
            // preference. We only do this when the app was active, so a
            // background launch never steals focus.
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Sets the Dock icon from the bundled AppIcon at runtime. The static
    /// `CFBundleIconFile` is the source of truth for Finder/installer, but the
    /// running Dock icon can lag behind LaunchServices' icon cache — assigning
    /// it here guarantees the correct icon every launch.
    private func applyDockIcon() {
        let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
            ?? Bundle.module.url(forResource: "AppIcon", withExtension: "icns")
        if let url, let image = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = image
        }
    }

    /// Launching the app again (Spotlight, Finder, Dock) while it runs must
    /// always bring the window back — with the menu bar icon hidden and no
    /// Dock icon, that is the only way in.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .transcriptorShowMainWindowRequested, object: nil)
        return true
    }

    /// A menu bar app keeps running after its window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
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
        // A single window: re-opening it from the menu bar must not stack
        // duplicates.
        Window("Transcriptor", id: AppState.mainWindowID) {
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
