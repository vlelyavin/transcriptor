import AppKit
import Observation
import SwiftUI

@MainActor
public final class RecordingOverlayManager {
    private var panel: NSPanel?
    private var voiceInputController: VoiceInputController?
    private var overlayStateProvider: (() -> OverlayState)?

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
            VoiceInputControllerState.recording,
            .stopping,
            .pendingTranscription,
        ].contains(voiceInputController.state)

        guard shouldShow else {
            panel?.orderOut(nil)
            return
        }

        let panel = makePanelIfNeeded()
        panel.contentViewController = NSHostingController(
            rootView: RecordingOverlayView(
                voiceInputController: voiceInputController,
                overlayState: overlayState
            )
        )
        panel.setContentSize(NSSize(width: 340, height: 132))
        position(panel: panel, using: overlayState.position)
        panel.orderFrontRegardless()
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
}
