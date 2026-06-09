import AppKit
import Observation
import SwiftUI

@MainActor
public final class RecordingOverlayManager {
    private var panel: NSPanel?
    private var voiceInputController: VoiceInputController?
    private var overlayStateProvider: (() -> OverlayState)?
    private var hideTask: Task<Void, Never>?

    public init() {}

    public func bind(
        voiceInputController: VoiceInputController,
        overlayStateProvider: @escaping () -> OverlayState
    ) {
        self.voiceInputController = voiceInputController
        self.overlayStateProvider = overlayStateProvider
        observeChanges()
        refreshPresentation()
    }

    public func refreshPresentation() {
        guard
            let voiceInputController,
            let overlayStateProvider
        else {
            return
        }

        let overlayState = overlayStateProvider()
        let shouldShow = overlayState.isEnabled && [
            VoiceInputControllerState.requestingPermission,
            VoiceInputControllerState.recording,
            .stopping,
            .pendingTranscription,
            .failed,
        ].contains(voiceInputController.state)

        guard shouldShow else {
            hidePanel(animated: true)
            return
        }

        let panel = makePanelIfNeeded()
        hideTask?.cancel()
        panel.contentViewController = NSHostingController(
            rootView: RecordingOverlayView(
                voiceInputController: voiceInputController,
                overlayState: overlayState
            )
        )
        panel.setContentSize(NSSize(width: 340, height: 132))
        position(panel: panel, using: overlayState.position)
        showPanel(panel)

        if voiceInputController.state == .failed {
            scheduleHide(after: .seconds(2))
        }
    }

    private func observeChanges() {
        withObservationTracking {
            _ = voiceInputController?.state
            _ = overlayStateProvider?().isEnabled
            _ = overlayStateProvider?().position
            _ = overlayStateProvider?().showsLiveAudioIndicator
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

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 132),
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
        panel.ignoresMouseEvents = true
        panel.alphaValue = 0
        panel.animationBehavior = .utilityWindow
        self.panel = panel
        return panel
    }

    private func position(panel: NSPanel, using position: OverlayPosition) {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        guard let screen else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let size = panel.frame.size
        let originX = visibleFrame.midX - size.width / 2
        let originY: CGFloat

        switch position {
        case .topCenter:
            originY = visibleFrame.maxY - size.height - 24
        case .bottomCenter:
            originY = visibleFrame.minY + 24
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

    private func hidePanel(animated: Bool) {
        hideTask?.cancel()
        guard let panel else {
            return
        }

        guard animated, panel.isVisible else {
            panel.orderOut(nil)
            panel.alphaValue = 0
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
            }
        }
    }

    private func scheduleHide(after duration: Duration) {
        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: duration)
            self?.hidePanel(animated: true)
        }
    }
}
