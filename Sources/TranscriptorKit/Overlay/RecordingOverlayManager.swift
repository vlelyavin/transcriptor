import AppKit
import Observation
import SwiftUI

@MainActor
public final class RecordingOverlayManager {
    private var dimmingPanel: NSPanel?
    private var panel: NSPanel?
    private var voiceInputController: VoiceInputController?
    private var overlayStateProvider: (() -> OverlayState)?
    private var recordingModeProvider: (() -> RecordingMode)?
    private var supplementalPhaseProvider: (() -> OverlaySupplementalPhase?)?
    private var hideTask: Task<Void, Never>?

    public init() {}

    public func bind(
        voiceInputController: VoiceInputController,
        overlayStateProvider: @escaping () -> OverlayState,
        recordingModeProvider: @escaping () -> RecordingMode,
        supplementalPhaseProvider: @escaping () -> OverlaySupplementalPhase?
    ) {
        self.voiceInputController = voiceInputController
        self.overlayStateProvider = overlayStateProvider
        self.recordingModeProvider = recordingModeProvider
        self.supplementalPhaseProvider = supplementalPhaseProvider
        observeChanges()
        refreshPresentation()
    }

    public func refreshPresentation() {
        guard
            let voiceInputController,
            let overlayStateProvider,
            let recordingModeProvider,
            let supplementalPhaseProvider
        else {
            return
        }

        let overlayState = overlayStateProvider()
        let supplementalPhase = supplementalPhaseProvider()
        let shouldShow = overlayState.isEnabled && [
            VoiceInputControllerState.requestingPermission,
            VoiceInputControllerState.recording,
            .stopping,
            .pendingTranscription,
            .failed,
        ].contains(voiceInputController.state) || supplementalPhase != nil

        guard shouldShow else {
            hidePanels(animated: true)
            return
        }

        let screen = presentationScreen()
        let dimmingPanel = makeDimmingPanelIfNeeded()
        let panel = makePanelIfNeeded()
        hideTask?.cancel()
        dimmingPanel.contentViewController = NSHostingController(
            rootView: Color.black.opacity(0.16)
                .ignoresSafeArea()
        )
        panel.contentViewController = NSHostingController(
            rootView: RecordingOverlayView(
                voiceInputController: voiceInputController,
                overlayState: overlayState,
                recordingMode: recordingModeProvider(),
                supplementalPhase: supplementalPhase,
                stopAction: {
                    voiceInputController.stopFromToolbar()
                },
                cancelAction: {
                    Task {
                        await voiceInputController.cancelRecording()
                    }
                }
            )
        )
        dimmingPanel.setFrame(screen.frame, display: false)
        panel.setContentSize(NSSize(width: 430, height: 286))
        position(panel: panel, screen: screen, using: overlayState.position)
        showPanel(dimmingPanel)
        showPanel(panel)
        panel.ignoresMouseEvents = !allowsInteraction(for: voiceInputController.state, mode: recordingModeProvider())

        if case .error = supplementalPhase {
            scheduleHide(after: .seconds(2))
        } else if case .saved = supplementalPhase {
            scheduleHide(after: .seconds(1.2))
        } else if voiceInputController.state == .failed {
            scheduleHide(after: .seconds(2))
        } else if voiceInputController.state == .pendingTranscription {
            scheduleHide(after: .seconds(1.2))
        }
    }

    private func observeChanges() {
        withObservationTracking {
            _ = voiceInputController?.state
            _ = overlayStateProvider?().isEnabled
            _ = overlayStateProvider?().position
            _ = overlayStateProvider?().showsLiveAudioIndicator
            _ = recordingModeProvider?()
            _ = supplementalPhaseProvider?()
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeChanges()
                self?.refreshPresentation()
            }
        }
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel {
            return panel
        }

        let panel = FloatingOverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 286),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.alphaValue = 0
        panel.animationBehavior = .utilityWindow
        self.panel = panel
        return panel
    }

    private func makeDimmingPanelIfNeeded() -> NSPanel {
        if let dimmingPanel {
            return dimmingPanel
        }

        let dimmingPanel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        dimmingPanel.isFloatingPanel = true
        dimmingPanel.hidesOnDeactivate = false
        dimmingPanel.level = .floating
        dimmingPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        dimmingPanel.backgroundColor = .clear
        dimmingPanel.isOpaque = false
        dimmingPanel.hasShadow = false
        dimmingPanel.ignoresMouseEvents = true
        dimmingPanel.alphaValue = 0
        self.dimmingPanel = dimmingPanel
        return dimmingPanel
    }

    private func position(panel: NSPanel, screen: NSScreen, using position: OverlayPosition) {
        let visibleFrame = screen.visibleFrame
        let size = panel.frame.size
        let originX = visibleFrame.midX - size.width / 2
        let originY: CGFloat

        switch position {
        case .topCenter:
            originY = visibleFrame.midY - size.height / 2
        case .bottomCenter:
            originY = visibleFrame.midY - size.height / 2 - 80
        }

        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    private func showPanel(_ panel: NSPanel) {
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            panel.animator().alphaValue = 1
        }
    }

    private func hidePanels(animated: Bool) {
        hideTask?.cancel()
        guard let panel, let dimmingPanel else {
            return
        }

        guard animated, panel.isVisible || dimmingPanel.isVisible else {
            panel.orderOut(nil)
            dimmingPanel.orderOut(nil)
            panel.alphaValue = 0
            dimmingPanel.alphaValue = 0
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 0
            dimmingPanel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
                dimmingPanel.orderOut(nil)
            }
        }
    }

    private func scheduleHide(after duration: Duration) {
        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: duration)
            self?.hidePanels(animated: true)
        }
    }

    private func allowsInteraction(for state: VoiceInputControllerState, mode: RecordingMode) -> Bool {
        state == .recording && mode == .toggleToTalk
    }

    private func presentationScreen() -> NSScreen {
        NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main ?? NSScreen.screens[0]
    }
}

private final class FloatingOverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
