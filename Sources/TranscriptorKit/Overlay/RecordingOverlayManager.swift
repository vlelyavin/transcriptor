import AppKit
import Observation
import os
import SwiftUI

@MainActor
public final class RecordingOverlayManager {
    private let log = Logger(subsystem: "com.vlelyavin.Transcriptor", category: "overlay")
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
            hidePanels()
            return
        }

        let screen = presentationScreen()
        let panel = makePanelIfNeeded()
        hideTask?.cancel()

        let panelSize: NSSize
        let rootView: AnyView
        let isResultCard: Bool
        let cardWidth: CGFloat
        let cardHeight: CGFloat

        if let resultContent = resultContent(for: supplementalPhase) {
            // Interactive transcript-preview / unconfigured result card.
            // It is its own surface, so the recording overlay's transparent
            // shadow envelope does not apply.
            let actions = actionsProvider?() ?? RecordingOverlayActions()
            rootView = AnyView(ResultOverlayView(content: resultContent, actions: actions))
            panelSize = NSSize(width: 460, height: preferredHeight(for: resultContent))
            isResultCard = true
            cardWidth = panelSize.width
            cardHeight = panelSize.height
        } else {
            let recordingMode = recordingModeProvider()
            rootView = AnyView(
                RecordingOverlayView(
                    voiceInputController: voiceInputController,
                    overlayState: overlayState,
                    recordingMode: recordingMode,
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
                // The card draws its own shadow. The transparent margin gives
                // that shadow room inside the window, so it is never clipped
                // by the panel's bounds.
                .padding(OverlayDesign.Shadow.margin)
                .frame(
                    width: OverlayEnvelope.size.width,
                    height: OverlayEnvelope.size.height,
                    alignment: overlayState.position == .topCenter ? .top : .bottom
                )
            )
            panelSize = OverlayEnvelope.size
            isResultCard = false
            let geometry = cardGeometry(for: overlayState, recordingMode: recordingMode)
            cardWidth = geometry.width
            cardHeight = geometry.height
        }

        // A first-mouse-accepting hosting view is the whole point of the
        // non-activating panel: the overlay's buttons (toggle-mode Stop/Cancel,
        // result-card actions) respond on the FIRST click even while another
        // app holds focus. A plain NSHostingView returns
        // `acceptsFirstMouse == false`, so the initial clicks were swallowed
        // and only "passed through" after the panel had incidentally become key.
        //
        // The same view also hit-tests only the card, so a click on the
        // transparent 28 pt shadow margin reaches the app underneath instead
        // of being eaten by an invisible window.
        let hostingView = OverlayHostingView(rootView: rootView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.restrictsHitsToCard = !isResultCard
        hostingView.cardWidth = cardWidth
        hostingView.cardHeight = cardHeight
        hostingView.cardAnchoredTop = overlayState.position == .topCenter
        panel.contentViewController = nil
        panel.contentView = hostingView

        // The recording card draws a SwiftUI shadow inside the envelope; the
        // window's own shadow would be computed from the card's alpha mask and
        // duplicated/clipped by the margin. The result card fills its window
        // exactly, so it keeps the native window shadow.
        panel.hasShadow = isResultCard
        panel.setContentSize(panelSize)
        position(
            panel: panel,
            screen: screen,
            using: overlayState.position,
            cardMargin: isResultCard ? 0 : OverlayDesign.Shadow.margin
        )
        showPanel(panel)

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
            _ = overlayStateProvider?().displayMode
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
            contentRect: NSRect(origin: .zero, size: OverlayEnvelope.size),
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
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.alphaValue = 1
        // AppKit's fade on top of the SwiftUI card reads as a double animation
        // and made the old overlay feel sluggish.
        panel.animationBehavior = .none
        self.panel = panel
        return panel
    }

    /// Positions the panel by the card's edge, not by the window's: the
    /// transparent shadow margin must not move the visible card.
    private func position(
        panel: NSPanel,
        screen: NSScreen,
        using position: OverlayPosition,
        cardMargin: CGFloat
    ) {
        let visibleFrame = screen.visibleFrame
        let size = panel.frame.size
        let originX = visibleFrame.midX - size.width / 2
        let originY: CGFloat

        switch position {
        case .topCenter:
            // Card top sits 12 pt under the menu bar.
            originY = visibleFrame.maxY - 12 + cardMargin - size.height
        case .bottomCenter:
            // Card bottom sits 24 pt above the bottom of the visible area.
            originY = visibleFrame.minY + 24 - cardMargin
        }

        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    private func showPanel(_ panel: NSPanel) {
        panel.alphaValue = 1
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    private func hidePanels() {
        log.notice("hide overlay panel")
        hideTask?.cancel()
        panel?.orderOut(nil)
    }

    private func scheduleHide(after duration: Duration) {
        log.notice("schedule auto-hide in \(String(describing: duration), privacy: .public)")
        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: duration)
            self?.hidePanels()
        }
    }

    private func cardGeometry(
        for overlayState: OverlayState,
        recordingMode: RecordingMode
    ) -> (width: CGFloat, height: CGFloat) {
        switch overlayState.displayMode {
        case .standard:
            return (OverlayDesign.Standard.width, OverlayDesign.Standard.minHeight)
        case .compact:
            return (
                OverlayDesign.Compact.width(
                    showsTimer: true,
                    showsWave: overlayState.showsLiveAudioIndicator,
                    showsStop: recordingMode == .toggleToTalk
                ),
                OverlayDesign.Compact.height
            )
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

/// The fixed window around the card. It is large enough for the tallest
/// standard card (78 pt) plus the 28 pt shadow margin on both sides; the card
/// animates inside it and the window itself never changes size.
private enum OverlayEnvelope {
    static let size = NSSize(
        width: OverlayDesign.Standard.width + OverlayDesign.Shadow.margin * 2,
        height: OverlayDesign.Standard.maxHeight + OverlayDesign.Shadow.margin * 2
    )
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
/// window isn't key, and (for the recording card) refuses clicks that land in
/// the transparent shadow margin.
private final class OverlayHostingView<Content: View>: NSHostingView<Content> {
    var restrictsHitsToCard = false
    var cardWidth: CGFloat = 0
    var cardHeight: CGFloat = 0
    var cardAnchoredTop = true

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard restrictsHitsToCard, cardWidth > 0, cardHeight > 0 else {
            return super.hitTest(point)
        }

        let local = convert(point, from: superview)
        // `NSHostingView` is flipped (top-left origin) on current macOS, but
        // compute against the actual flag so a future flip cannot turn the
        // click-through margin into a dead zone over the card.
        let cardY: CGFloat
        if isFlipped {
            cardY = cardAnchoredTop
                ? OverlayDesign.Shadow.margin
                : bounds.height - OverlayDesign.Shadow.margin - cardHeight
        } else {
            cardY = cardAnchoredTop
                ? bounds.height - OverlayDesign.Shadow.margin - cardHeight
                : OverlayDesign.Shadow.margin
        }
        let cardRect = CGRect(
            x: (bounds.width - cardWidth) / 2,
            y: cardY,
            width: cardWidth,
            height: cardHeight
        )
        guard cardRect.contains(local) else {
            return nil
        }
        return super.hitTest(point)
    }

    @MainActor required init(rootView: Content) {
        super.init(rootView: rootView)
    }

    @MainActor required dynamic init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
