import AppKit
import SwiftUI

/// First-launch setup gate, presented as a sheet. Setup is **mandatory**: the
/// sheet cannot be dismissed until BOTH a transcription model is configured AND
/// Accessibility access is granted — the two things the app needs to deliver its
/// core value (speak, transcribe, and type into the active app). It offers a
/// one-click path to each so the fastest route to a working app is the obvious
/// one.
public struct WelcomeGuideView: View {
    @Bindable private var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    howItWorks

                    VStack(spacing: 12) {
                        modelStepCard
                        accessibilityStepCard
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
        // Setup is mandatory — block interactive (swipe/click-away) dismissal
        // until every required step is complete.
        .interactiveDismissDisabled(appState.requiresSetup)
        .onAppear { appState.refreshAccessibilityPermissionStatus() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // The user may grant Accessibility in System Settings and switch
            // back — re-check so the gate updates without a relaunch.
            appState.refreshAccessibilityPermissionStatus()
        }
        .onChange(of: appState.readyLocalModelIDs) { _, _ in
            // As soon as the recommended model finishes downloading, select it
            // so the user lands in a ready-to-use state with no extra clicks.
            appState.finishModelSetupIfReady()
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

    // MARK: - Required setup steps

    @ViewBuilder
    private var modelStepCard: some View {
        if appState.isTranscriptionConfigured {
            requirementCard(
                done: true,
                title: "Transcription model ready",
                detail: "A speech model is set up and runs entirely on your Mac."
            )
        } else if let model = appState.recommendedSetupModel {
            requirementCard(done: false, title: "Download a transcription model", detail: "Transcriptor needs a speech model to turn your voice into text. It runs entirely on your Mac.") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recommended")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(model.name)
                                .font(.callout.weight(.semibold))
                        }
                        Spacer()
                        Text(model.downloadSizeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let progress = recommendedModelState.progressValue {
                        ProgressView(value: progress)
                            .controlSize(.small)
                        Text("Downloading… \(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if recommendedModelIsLoading {
                        ProgressView()
                            .controlSize(.small)
                        Text("Preparing model…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let failureMessage = recommendedModelState.detailMessage {
                        Text(failureMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var accessibilityStepCard: some View {
        if appState.isAccessibilityGranted {
            requirementCard(
                done: true,
                title: "Accessibility access granted",
                detail: "Transcriptor can type your transcript into the app you're using."
            )
        } else {
            requirementCard(
                done: false,
                title: "Grant Accessibility access",
                detail: "macOS requires Accessibility access so Transcriptor can insert dictated text into the app you're typing in. Without it, dictation can't reach other apps."
            )
        }
    }

    /// A consistent requirement card: a status glyph (green check when done,
    /// accent dot when pending), a title and explanation, and optional extra
    /// content (e.g. the model download progress).
    @ViewBuilder
    private func requirementCard(
        done: Bool,
        title: String,
        detail: String,
        @ViewBuilder extra: () -> some View = { EmptyView() }
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(done ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            extra()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.separator, lineWidth: 0.5)
        )
    }

    private var footer: some View {
        HStack {
            Spacer()

            if !appState.isTranscriptionConfigured {
                if recommendedModelIsBusy {
                    Button("Downloading…") {}
                        .disabled(true)
                } else {
                    Button(recommendedModelState.detailMessage == nil ? "Download Model" : "Retry Download") {
                        appState.beginModelSetup()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.recommendedSetupModel == nil)
                }
            } else if !appState.isAccessibilityGranted {
                Button("Grant Accessibility Access") {
                    appState.requestAccessibilityPermissionPrompt()
                    appState.openAccessibilityPrivacySettings()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            } else {
                Button("Start Using Transcriptor") {
                    appState.dismissWelcomeGuide()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Recommended model state helpers

    private var recommendedModelState: LocalModelState {
        guard let model = appState.recommendedSetupModel else { return .notDownloaded }
        return appState.whisperModelManager.item(for: model.id)?.state ?? .notDownloaded
    }

    private var recommendedModelIsLoading: Bool {
        switch recommendedModelState {
        case .loading, .deleting:
            true
        default:
            false
        }
    }

    private var recommendedModelIsBusy: Bool {
        recommendedModelState.progressValue != nil || recommendedModelIsLoading
    }
}

#if DEBUG
struct WelcomeGuideView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeGuideView(appState: .preview)
    }
}
#endif
