import SwiftUI

/// First-launch setup gate, presented as a sheet. Downloading and configuring a
/// transcription model is **mandatory**: the sheet cannot be dismissed until a
/// transcription path exists. It offers a one-click path to the recommended
/// model so the fastest route to a working app is also the obvious one.
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
        .frame(minHeight: 540)
        // Setup is mandatory — block interactive (swipe/click-away) dismissal
        // until a transcription path is configured.
        .interactiveDismissDisabled(!appState.isTranscriptionConfigured)
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
        } else if let model = appState.recommendedSetupModel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Download a transcription model")
                            .font(.body.weight(.semibold))
                        Text("Transcriptor needs a speech model to turn your voice into text. It runs entirely on your Mac.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }

                Divider()

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
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var footer: some View {
        HStack {
            Spacer()

            if appState.isTranscriptionConfigured {
                Button("Start Using Transcriptor") {
                    appState.dismissWelcomeGuide()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            } else if recommendedModelIsBusy {
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
