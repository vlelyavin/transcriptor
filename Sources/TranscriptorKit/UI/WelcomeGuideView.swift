import SwiftUI

/// First-launch welcome + setup guide, presented as a sheet. Explains the core
/// workflow and offers a one-click path to download a transcription model. The
/// user can always skip — the app still works as a voice recorder.
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
                    setupCard
                }
                .padding(28)
            }

            Divider()

            footer
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
        }
        .frame(width: 460)
        .frame(minHeight: 520)
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
                                colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
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
        VStack(alignment: .leading, spacing: 14) {
            stepRow(
                number: 1,
                title: "Press \(appState.recordingState.hotkey.displayString)",
                detail: "Start dictation from anywhere with your global shortcut."
            )
            stepRow(
                number: 2,
                title: "Speak",
                detail: "A compact overlay shows a live indicator while you talk."
            )
            stepRow(
                number: 3,
                title: "Get your transcript",
                detail: "It's inserted into the active text field, or shown for review."
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepRow(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor))

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

    @ViewBuilder
    private var setupCard: some View {
        if appState.isTranscriptionConfigured {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("You're ready to go")
                        .font(.body.weight(.semibold))
                    Text("A transcription model is set up. Try your shortcut now.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    Text("Set up transcription")
                        .font(.body.weight(.semibold))
                }

                Text("Download a local model to turn speech into text. It runs entirely on your Mac. You can skip this and use Transcriptor as a voice recorder — recordings can be transcribed later.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var footer: some View {
        HStack {
            if !appState.isTranscriptionConfigured {
                Button("Skip for now") {
                    appState.dismissWelcomeGuide()
                }
            }

            Spacer()

            if appState.isTranscriptionConfigured {
                Button("Done") {
                    appState.dismissWelcomeGuide()
                }
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Set Up Transcription") {
                    appState.beginModelSetup()
                }
                .keyboardShortcut(.defaultAction)
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
