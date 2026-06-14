import AppKit
import SwiftUI

/// First-launch welcome guide, presented as a sheet, with two steps:
///
/// 1. **Intro** — what Transcriptor does (how-it-works), ending with a "Proceed"
///    primary button.
/// 2. **Set Up** — asks for the permissions the app needs (Microphone and
///    Accessibility) and points to the Models page to download a transcription
///    model. Downloading a model is **not required** to finish — the user can
///    start exploring and add one later — but the step makes clear that
///    transcription stays unavailable until at least one model is downloaded.
///
/// Primary (focus) actions use the accent `borderedProminent` style in the
/// bottom-right; secondary actions are plain/gray in the bottom-left.
public struct WelcomeGuideView: View {
    @Bindable private var appState: AppState

    private enum Step {
        case intro
        case setUp
    }

    @State private var step: Step = .intro

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    switch step {
                    case .intro:
                        introContent
                    case .setUp:
                        setUpContent
                    }
                }
                .padding(28)
            }

            Divider()

            footer
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .frame(width: 460)
        .frame(minHeight: 580)
        // The guide is dismissible (setup is optional), but the two-step flow is
        // driven by its buttons, so block stray swipe/click-away dismissal.
        .interactiveDismissDisabled(true)
        .onAppear {
            appState.refreshAccessibilityPermissionStatus()
            appState.refreshMicrophonePermissionStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // The user may grant a permission in System Settings and switch back —
            // re-check so the step updates without a relaunch.
            appState.refreshAccessibilityPermissionStatus()
            appState.refreshMicrophonePermissionStatus()
        }
    }

    // MARK: - Step 1: Intro

    private var introContent: some View {
        VStack(spacing: 20) {
            header
            howItWorks
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.28), Color(white: 0.16)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }

            Text("Welcome to Transcriptor")
                .font(.title2.weight(.bold))

            Text("Press your shortcut, speak, and your words appear right where you're typing. Everything is stored locally on your Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepRow(
                symbol: "command",
                title: "Press \(appState.recordingState.hotkey.displayString)",
                detail: "Start dictation from anywhere with your global shortcut."
            )
            stepRow(
                symbol: "waveform",
                title: "Speak",
                detail: "A compact overlay shows a live indicator while you talk."
            )
            stepRow(
                symbol: "text.cursor",
                title: "Get your transcript",
                detail: "It's inserted into the active text field, or shown for review."
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A feature row in Apple's "Welcome to…" style: a leading tinted SF Symbol
    /// (no filled badge), a title, and a one-line description.
    private func stepRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Step 2: Set up

    private var setUpContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 8) {
                Text("Set Up Transcriptor")
                    .font(.title2.weight(.bold))
                Text("Grant the permissions Transcriptor needs to record and type for you. You can change these anytime in Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                microphoneCard
                accessibilityCard
                modelCard
            }
        }
    }

    private var microphoneCard: some View {
        permissionCard(
            done: appState.isMicrophoneGranted,
            title: appState.isMicrophoneGranted ? "Microphone access granted" : "Allow microphone access",
            detail: "Transcriptor records from your microphone so it can turn speech into text.",
            actionTitle: "Allow Microphone"
        ) {
            Task { await appState.requestMicrophonePermission() }
            appState.openMicrophonePrivacySettings()
        }
    }

    private var accessibilityCard: some View {
        permissionCard(
            done: appState.isAccessibilityGranted,
            title: appState.isAccessibilityGranted ? "Accessibility access granted" : "Allow Accessibility access",
            detail: "macOS requires Accessibility access so Transcriptor can insert dictated text into the app you're typing in.",
            actionTitle: "Allow Accessibility"
        ) {
            appState.requestAccessibilityPermissionPrompt()
            appState.openAccessibilityPrivacySettings()
        }
    }

    /// The optional model step. Downloading is not required to finish onboarding,
    /// but this card makes the consequence explicit: no transcription until a
    /// model is installed.
    private var modelCard: some View {
        permissionCard(
            done: appState.isTranscriptionConfigured,
            title: appState.isTranscriptionConfigured ? "Transcription model ready" : "Download a transcription model",
            detail: appState.isTranscriptionConfigured
                ? "A speech model is set up and runs entirely on your Mac."
                : "Optional now — explore first if you like. Transcription stays unavailable until you download at least one model from the Models page.",
            actionTitle: "Choose a Model…",
            actionIsProminent: false
        ) {
            appState.openModelsFromWelcomeGuide()
        }
    }

    /// A consistent requirement card: a status glyph (green check when done, a
    /// neutral circle when pending), a title and explanation, and a trailing
    /// action button (hidden once the requirement is satisfied).
    private func permissionCard(
        done: Bool,
        title: String,
        detail: String,
        actionTitle: String,
        actionIsProminent: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(done ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !done {
                    if actionIsProminent {
                        Button(actionTitle, action: action)
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button(actionTitle, action: action)
                            .buttonStyle(.bordered)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.separator, lineWidth: 0.5)
        )
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        HStack {
            // Secondary action sits in the bottom-left and stays gray.
            switch step {
            case .intro:
                EmptyView()
            case .setUp:
                Button("Back") {
                    step = .intro
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            // Primary (focus) action sits in the bottom-right with the accent.
            switch step {
            case .intro:
                Button("Proceed") {
                    step = .setUp
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            case .setUp:
                Button("Start Exploring") {
                    appState.dismissWelcomeGuide()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

#if DEBUG
struct WelcomeGuideView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeGuideView(appState: .preview)
    }
}
#endif
