import AppKit
import Observation
import os
import SwiftUI

@MainActor
public final class RecordingOverlayManager {
    private let log = Logger(subsystem: "com.vlelyavin.Transcriptor", category: "overlay")
    private var dimmingPanel: NSPanel?
    private var panel: NSPanel?
    private var voiceInputController: VoiceInputController?
    private var overlayStateProvider: (() -> OverlayState)?
    private var recordingModeProvider: (() -> RecordingMode)?
    private var supplementalPhaseProvider: (() -> OverlaySupplementalPhase?)?
    private var actionsProvider: (() -> RecordingOverlayActions)?
    private var hideTask: Task<Void, Never>?

    public init() {}

    public func bind(
        voiceInputController: VoiceInputController,
        overlayStateProvider: @escaping () -> OverlayState,
        recordingModeProvider: @escaping () -> RecordingMode,
        supplementalPhaseProvider: @escaping () -> OverlaySupplementalPhase?,
        actionsProvider: @escaping () -> RecordingOverlayActions = { RecordingOverlayActions() }
    ) {
        self.voiceInputController = voiceInputController
        self.overlayStateProvider = overlayStateProvider
        self.recordingModeProvider = recordingModeProvider
        self.supplementalPhaseProvider = supplementalPhaseProvider
        self.actionsProvider = actionsProvider
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

        log.notice("refresh: state=\(voiceInputController.state.rawValue, privacy: .public) supplemental=\(String(describing: supplementalPhase), privacy: .public) shouldShow=\(shouldShow, privacy: .public)")

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

        let panelSize: NSSize
        let rootView: AnyView
        if let resultContent = resultContent(for: supplementalPhase) {
            // Interactive transcript-preview / unconfigured result card.
            let actions = actionsProvider?() ?? RecordingOverlayActions()
            rootView = AnyView(ResultOverlayView(content: resultContent, actions: actions))
            panelSize = NSSize(width: 460, height: preferredHeight(for: resultContent))
        } else {
            rootView = AnyView(
                RecordingOverlayView(
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
            panelSize = NSSize(width: 320, height: 120)
        }

        // Use a first-mouse-accepting hosting view so the overlay's buttons
        // (toggle-mode Done/Cancel, result-card actions) respond on the FIRST
        // click even while another app holds focus. A plain NSHostingView
        // returns `acceptsFirstMouse == false`, which is why the initial clicks
        // were being swallowed and only "passed through" after the panel had
        // incidentally become key.
        let hostingView = FirstMouseHostingView(rootView: rootView)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentViewController = nil
        panel.contentView = hostingView

        dimmingPanel.setFrame(screen.frame, display: false)
        panel.setContentSize(panelSize)
        position(panel: panel, screen: screen, using: overlayState.position)
        showPanel(dimmingPanel)
        showPanel(panel)

        let isResultCard = resultContent(for: supplementalPhase) != nil
        let interactive = allowsInteraction(for: voiceInputController.state, mode: recordingModeProvider()) || isResultCard
        // Decide whether the panel may take key-window status. ONLY the
        // post-recording result card is allowed to (its text selection / default
        // button want it, and there is no live dictation left to disrupt). During
        // recording the panel must never become key — see `FloatingOverlayPanel`.
        (panel as? FloatingOverlayPanel)?.mayBecomeKey = isResultCard
        panel.ignoresMouseEvents = !interactive
        if interactive {
            // Order the panel forward WITHOUT activating Transcriptor and without
            // making it key. While recording, `FloatingOverlayPanel.canBecomeKey`
            // is false, so this can't hand key status to the overlay; with
            // `.nonactivatingPanel`, the app the user is dictating into keeps both
            // *active* and *key* status.
            //
            // We must NOT call `NSApp.activate(...)` or `panel.makeKey()` here, and
            // the overlay's buttons must NOT carry `.keyboardShortcut` (which would
            // demand key status). Any of those hands key/active status to
            // Transcriptor and was the root of every toggle-mode symptom:
            //   • the live meter froze and the global shortcut + Done stopped
            //     responding a second or two in, because the user's app and the
            //     overlay fought over key-window status across processes;
            //   • automatic insertion silently failed — by paste time the captured
            //     field was no longer frontmost, so it fell back to "saved only";
            //   • Cmd+V wouldn't paste in the terminal, because keystrokes were
            //     being routed to the overlay panel that had grabbed the key window.
            //
            // Done/Cancel still respond (a button click is delivered via
            // `acceptsFirstMouse` without the panel needing to be key), and the
            // global shortcut remains a reliable, focus-preserving way to stop.
            panel.orderFrontRegardless()
        } else {
            // Passive states (hold-to-talk live meter, progress) must never
            // steal focus from wherever the user is typing.
            panel.resignKey()
        }

        // Auto-hide is driven by the supplemental phase first, because a
        // supplemental card always supersedes the raw recorder state. Ongoing
        // work (`transcribing`/`inserting`) and interactive cards
        // (`preview`/`unconfigured`) must NEVER auto-hide — otherwise the
        // overlay can vanish mid-transcription, which reads as "stuck".
        if let supplementalPhase {
            switch supplementalPhase {
            case .error:
                scheduleHide(after: .seconds(2))
            case .setupRequired:
                scheduleHide(after: .seconds(3.5))
            case .saved:
                scheduleHide(after: .seconds(1.2))
            case .transcribing, .inserting, .preview, .unconfigured:
                hideTask?.cancel()
            }
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
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 210),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        // Whether the panel may take key-window status is decided per state in
        // `refreshPresentation` via `FloatingOverlayPanel.mayBecomeKey`: false
        // while recording (so the overlay can never steal keyboard focus from the
        // app being dictated into), true only for the post-recording result card.
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
        // It has no controls and must never own the key window (see the main
        // panel for why a non-activating panel becoming key breaks keyboard
        // routing in the user's app).
        dimmingPanel.becomesKeyOnlyIfNeeded = true
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
        log.notice("hide panels (animated=\(animated, privacy: .public))")
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
        log.notice("schedule auto-hide in \(String(describing: duration), privacy: .public)")
        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: duration)
            self?.hidePanels(animated: true)
        }
    }

    private func allowsInteraction(for state: VoiceInputControllerState, mode: RecordingMode) -> Bool {
        state == .recording && mode == .toggleToTalk
    }

    private func resultContent(for phase: OverlaySupplementalPhase?) -> ResultOverlayView.Content? {
        switch phase {
        case let .preview(payload):
            return .preview(payload)
        case let .unconfigured(payload):
            return .unconfigured(payload)
        default:
            return nil
        }
    }

    private func preferredHeight(for content: ResultOverlayView.Content) -> CGFloat {
        switch content {
        case .preview:
            return 270
        case .unconfigured:
            return 220
        }
    }

    private func presentationScreen() -> NSScreen {
        NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main ?? NSScreen.screens[0]
    }
}

private final class FloatingOverlayPanel: NSPanel {
    /// Whether the panel is allowed to take key-window status. Set per state by
    /// `RecordingOverlayManager.refreshPresentation`.
    ///
    /// It is `false` while recording: a `.nonactivatingPanel` that becomes key
    /// while another app is active creates a cross-app split where the user's
    /// app stays *active* but THIS panel owns the *key* window — which froze the
    /// live meter, wedged the global shortcut + Done, and routed Cmd+V to the
    /// overlay instead of the app being dictated into. A SwiftUI
    /// `.keyboardShortcut` is enough to demand that key status, so the recording
    /// overlay also carries none; its buttons are clicked via `acceptsFirstMouse`,
    /// which never needs a key window.
    ///
    /// It is `true` only for the post-recording result card, where keyboard
    /// affordances are wanted and there is no live dictation left to disrupt.
    var mayBecomeKey = false
    override var canBecomeKey: Bool { mayBecomeKey }
}

/// A SwiftUI hosting view that accepts the first mouse click even when its
/// window isn't key. Without this, clicking a control in the non-activating
/// overlay while another app is focused only keys the window and discards the
/// click — so Done/Cancel appeared to ignore the first press(es).
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    @MainActor required init(rootView: Content) {
        super.init(rootView: rootView)
    }

    @MainActor required dynamic init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
