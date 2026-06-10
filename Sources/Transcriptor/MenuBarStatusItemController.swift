import AppKit
import Observation
import TranscriptorKit

@MainActor
final class MenuBarStatusItemController: NSObject {
    private enum WorkflowState {
        case idle
        case recording
        case transcribing
        case failed

        var symbolName: String {
            switch self {
            case .idle:
                return "mic"
            case .recording:
                return "mic.fill"
            case .transcribing:
                return "waveform.badge.magnifyingglass"
            case .failed:
                return "exclamationmark.circle.fill"
            }
        }

        var tintColor: NSColor? {
            switch self {
            case .idle:
                return nil
            case .recording:
                return .systemRed
            case .transcribing:
                return .systemBlue
            case .failed:
                return .systemOrange
            }
        }
    }

    private let appState: AppState
    private var statusItem: NSStatusItem?

    init(appState: AppState) {
        self.appState = appState
        super.init()
        observeChanges()
        refresh()
    }

    func refresh() {
        guard appState.generalSettings.showMenuBarIcon else {
            removeStatusItem()
            return
        }

        let item = ensureStatusItem()
        configureButton(for: item)
        item.menu = buildMenu()
    }

    private func observeChanges() {
        withObservationTracking {
            _ = appState.generalSettings.showMenuBarIcon
            _ = appState.voiceInputController.state
            _ = appState.transcriptionQueueController.activeJob
            _ = appState.overlaySupplementalPhase
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeChanges()
                self?.refresh()
            }
        }
    }

    private func ensureStatusItem() -> NSStatusItem {
        if let statusItem {
            return statusItem
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.behavior = [.removalAllowed]
        statusItem = item
        return item
    }

    private func removeStatusItem() {
        guard let statusItem else {
            return
        }

        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    private func configureButton(for item: NSStatusItem) {
        guard let button = item.button else {
            return
        }

        let workflowState = workflowState
        button.image = NSImage(
            systemSymbolName: workflowState.symbolName,
            accessibilityDescription: "Transcriptor"
        )
        button.image?.isTemplate = true
        button.contentTintColor = workflowState.tintColor
        button.toolTip = tooltipText(for: workflowState)
    }

    private func tooltipText(for state: WorkflowState) -> String {
        switch state {
        case .idle:
            return "Transcriptor is ready."
        case .recording:
            return "Transcriptor is recording."
        case .transcribing:
            return "Transcriptor is transcribing."
        case .failed:
            return appState.voiceInputController.failureMessage ?? "Transcriptor hit a voice input error."
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let startStopTitle = appState.voiceInputController.isRecording ? "Stop Voice Input" : "Start Voice Input"
        let startStopItem = NSMenuItem(title: startStopTitle, action: #selector(toggleVoiceInput), keyEquivalent: "")
        startStopItem.target = self
        startStopItem.isEnabled = ![
            VoiceInputControllerState.requestingPermission,
            .stopping,
        ].contains(appState.voiceInputController.state)
        menu.addItem(startStopItem)

        menu.addItem(.separator())

        menu.addItem(menuItem(title: "Open Transcriptor", action: #selector(openTranscriptor)))
        menu.addItem(menuItem(title: "Open History", action: #selector(openHistory)))
        menu.addItem(menuItem(title: "Open Settings", action: #selector(openSettingsView)))

        menu.addItem(.separator())

        let toggleMenuBarItem = menuItem(
            title: appState.generalSettings.showMenuBarIcon ? "Hide Menu Bar Icon" : "Show Menu Bar Icon",
            action: #selector(toggleMenuBarIcon)
        )
        toggleMenuBarItem.state = appState.generalSettings.showMenuBarIcon ? .on : .off
        menu.addItem(toggleMenuBarItem)

        menu.addItem(.separator())
        menu.addItem(menuItem(title: "Quit Transcriptor", action: #selector(quitApp)))
        return menu
    }

    private func menuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private var workflowState: WorkflowState {
        if case .error = appState.overlaySupplementalPhase {
            return .failed
        }

        switch appState.voiceInputController.state {
        case .recording, .stopping:
            return .recording
        case .failed:
            return .failed
        case .pendingTranscription:
            return .transcribing
        case .requestingPermission:
            return .recording
        case .idle:
            break
        }

        if let activeJob = appState.transcriptionQueueController.activeJob, appState.historyEntry(id: activeJob.entryID) != nil {
            return .transcribing
        }

        if let supplementalPhase = appState.overlaySupplementalPhase {
            switch supplementalPhase {
            case .transcribing, .inserting:
                return .transcribing
            case .saved:
                return .idle
            case .error, .setupRequired:
                return .failed
            }
        }

        return .idle
    }

    @objc
    private func toggleVoiceInput() {
        if appState.voiceInputController.isRecording {
            appState.voiceInputController.stopFromToolbar()
        } else {
            appState.voiceInputController.startFromToolbar()
        }
    }

    @objc
    private func openTranscriptor() {
        bringAppToFront(screen: .overview)
    }

    @objc
    private func openHistory() {
        bringAppToFront(screen: .history)
    }

    @objc
    private func openSettingsView() {
        appState.openSettings()
        NSApp.activate(ignoringOtherApps: true)

        for window in NSApp.windows {
            guard window.canBecomeMain else {
                continue
            }

            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc
    private func toggleMenuBarIcon() {
        appState.generalSettings.showMenuBarIcon.toggle()
        refresh()
    }

    @objc
    private func quitApp() {
        NSApp.terminate(nil)
    }

    private func bringAppToFront(screen: NavigationScreen) {
        appState.selectedScreen = screen
        NSApp.activate(ignoringOtherApps: true)

        for window in NSApp.windows {
            guard window.canBecomeMain else {
                continue
            }

            window.makeKeyAndOrderFront(nil)
        }
    }
}
