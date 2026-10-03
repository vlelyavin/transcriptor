import AppKit
import Carbon
import SwiftUI
import TranscriptorKit

/// Owns the activation policy. Transcriptor is a menu bar app
/// (`LSUIElement`): it shows a Dock icon — and takes part in Cmd-Tab — only
/// while one of its windows is open, or always when the user turned on
/// "Show Dock icon".
///
/// While a window is open the app is promoted to `.regular`. That also keeps
/// the fix for the original bug this delegate was written for: a process that
/// comes up as accessory/background (e.g. `swift run`) can't make its window
/// key, so keystrokes leaked to the previously active app, and it ignored the
/// system light/dark appearance.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set in `applicationWillFinishLaunching` — while the 'oapp' AppleEvent
    /// that launched us is still current — so scene construction (which reads
    /// this to suppress the window on macOS 15+) sees the right value.
    private(set) var launchedAsLoginItem = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        launchedAsLoginItem = Self.detectLoginItemLaunch()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = NotificationCenter.default
        for name in [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didBecomeMainNotification,
            NSWindow.willCloseNotification,
            NSWindow.didChangeOcclusionStateNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
            .transcriptorDockIconPreferenceChanged,
        ] {
            center.addObserver(self, selector: #selector(windowSetChanged(_:)), name: name, object: nil)
        }
        updateActivationPolicy()

        guard !launchedAsLoginItem else {
            // A login-item launch must stay invisible in the background: no
            // activation (which would steal focus from the user's session) and
            // no window. macOS 15+ suppresses the Window scene outright via
            // `defaultLaunchBehavior`; on earlier systems the window is already
            // being created by now, so close it on the next runloop turn.
            DispatchQueue.main.async {
                for window in NSApp.windows where !(window is NSPanel) && window.canBecomeMain {
                    window.close()
                }
            }
            return
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    /// Whether macOS launched this process as a login item. `SMAppService`
    /// passes no argv marker, but LaunchServices flags the 'oapp' AppleEvent
    /// that delivers the launch with `keyAELaunchedAsLogInItem` — the same
    /// signal login-item helpers have relied on for years. Must be read while
    /// that event is still current (i.e. during finish-launching).
    private static func detectLoginItemLaunch() -> Bool {
        guard
            let event = NSAppleEventManager.shared().currentAppleEvent,
            event.eventClass == AEEventClass(kCoreEventClass),
            event.eventID == AEEventID(kAEOpenApplication),
            let propData = event.paramDescriptor(forKeyword: keyAEPropData)
                ?? event.attributeDescriptor(forKeyword: keyAEPropData)
        else {
            return false
        }

        // The flag lives inside the `keyAEPropData` record — try each accessor
        // level since NSAppleEventDescriptor's mapping onto AE records differs
        // by keyword kind.
        return propData.descriptor(forKeyword: keyAELaunchedAsLogInItem)?.booleanValue
            ?? propData.paramDescriptor(forKeyword: keyAELaunchedAsLogInItem)?.booleanValue
            ?? propData.attributeDescriptor(forKeyword: keyAELaunchedAsLogInItem)?.booleanValue
            ?? false
    }

    @objc
    private func windowSetChanged(_ notification: Notification) {
        // `willClose` fires while the window is still visible; re-evaluate on
        // the next runloop turn, after it is gone.
        DispatchQueue.main.async { [weak self] in
            self?.updateActivationPolicy()
        }
    }

    private func updateActivationPolicy() {
        let hasOpenWindow = NSApp.windows.contains { window in
            window.isVisible && window.canBecomeMain && !(window is NSPanel)
        }
        let desired: NSApplication.ActivationPolicy = (AppState.prefersDockIcon || hasOpenWindow) ? .regular : .accessory
        guard NSApp.activationPolicy() != desired else {
            return
        }
        NSApp.setActivationPolicy(desired)
        if desired == .regular {
            applyDockIcon()
            // Re-activate right after the promotion: activating while still
            // `.accessory` doesn't attach the main menu, and nothing else
            // re-activates afterwards, so the app's menus could stay dead
            // until the user switched apps and back.
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
        // A login-item launch must not flash the window. On macOS 15+ the
        // scene is suppressed outright; on earlier systems AppDelegate closes
        // the window right after launch instead.
        if #available(macOS 15, *) {
            windowScene
                .defaultLaunchBehavior(appDelegate.launchedAsLoginItem ? .suppressed : .automatic)
        } else {
            windowScene
        }
    }

    private var windowScene: some Scene {
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
