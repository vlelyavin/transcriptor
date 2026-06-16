import SwiftUI

public struct OverviewView: View {
    @Bindable private var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    /// History storage limit bounds, shared with the Storage settings pane: the
    /// lower bound tracks current usage (so the cap can't be set below the space
    /// history already uses), up to 2 GB.
    private var storageLimitRange: ClosedRange<Int> { appState.minimumHistoryLimitMegabytes...2_048 }

    private var storageLimitBinding: Binding<Int> {
        Binding(
            get: {
                min(max(appState.storageSettings.capMegabytes, storageLimitRange.lowerBound), storageLimitRange.upperBound)
            },
            set: { newValue in
                appState.storageSettings.capMegabytes = min(max(newValue, storageLimitRange.lowerBound), storageLimitRange.upperBound)
            }
        )
    }

    /// Auto-transcribe is only meaningful once a transcription model exists; the
    /// binding mirrors the guard used on the Import and Models screens.
    private var autoTranscribeBinding: Binding<Bool> {
        Binding(
            get: { appState.transcriptionPreferences.autoTranscribeAfterCapture && appState.canEnableAutoTranscribe },
            set: { appState.transcriptionPreferences.autoTranscribeAfterCapture = $0 && appState.canEnableAutoTranscribe }
        )
    }

    /// Binds the unified "Active model" picker to the app's active target,
    /// falling back to the first available target when the stored selection is
    /// no longer ready. Shared logic with the Models page so both stay in sync.
    private var activeTargetBinding: Binding<AppState.ActiveTarget> {
        Binding(
            get: {
                if let active = appState.activeTarget, appState.availableTargets.contains(active) {
                    return active
                }
                return appState.availableTargets.first ?? .local(appState.transcriptionPreferences.selectedModelID)
            },
            set: { appState.selectTarget($0) }
        )
    }

    public var body: some View {
        Form {
            Section {
                heroHeader
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            if appState.transcriptionReadiness == .needsModel {
                Section {
                    setupRow
                }
            }

            Section {
                linkedRow("Voice input shortcut", destination: .settings(.keyboardShortcut)) {
                    Text(appState.recordingState.hotkey.displayString)
                        .font(.system(.body, design: .monospaced))
                }

                Picker("Input mode", selection: $appState.recordingState.mode) {
                    ForEach(RecordingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                linkedRow("Current state", destination: .settings(.advanced)) {
                    Text(appState.voiceInputController.state.rawValue.capitalized)
                }

                Toggle("Overlay", isOn: $appState.overlayState.isEnabled)

                Toggle("Insert into active app", isOn: $appState.generalSettings.insertTranscriptIntoActiveApp)

                if appState.generalSettings.insertTranscriptIntoActiveApp,
                   appState.accessibilityPermissionStatus != .granted {
                    Text("Needs Accessibility access to type into other apps.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Voice Input")
            }

            Section {
                activeModelRow

                linkedRow("Ready local models", destination: .screen(.models)) {
                    Text("\(appState.readyLocalModelIDs.count)")
                }

                Toggle("Auto-transcribe", isOn: autoTranscribeBinding)
                    .disabled(!appState.canEnableAutoTranscribe)
            } header: {
                Text("Transcription")
            } footer: {
                if appState.transcriptionReadiness == .needsModel {
                    Text("Transcription isn't possible yet. Download at least one model from the Models page to start turning recordings into text.")
                }
            }

            Section {
                linkedRow("Managed usage", destination: .settings(.storage)) {
                    Text(megabyteString(for: appState.storageUsage.totalManagedBytes))
                }

                LabeledContent("History limit") {
                    MegabyteStepperField(value: storageLimitBinding, range: storageLimitRange)
                }

                linkedRow("History items", destination: .screen(.history)) {
                    Text("\(appState.historyStore.entries.count)")
                }

                if let storageWarningMessage = appState.storageWarningMessage {
                    Text(storageWarningMessage)
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
            } header: {
                Text("Storage")
            }

            // Recent History is only shown once there is history to show — an
            // empty placeholder section adds noise on a fresh install.
            if !appState.historyStore.entries.isEmpty {
                Section {
                    ForEach(appState.historyStore.entries.prefix(5)) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.displayName)
                                .lineLimit(1)

                            Text("\(entry.transcriptionStatus.title) • \(formattedDate(entry.createdAt))")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(entry.transcriptPreview.isEmpty ? "Pending transcription" : entry.transcriptPreview)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 2)
                    }

                    Button("Open History") {
                        appState.sidebarSelection = .screen(.history)
                    }
                } header: {
                    Text("Recent History")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Overview")
        .onAppear { appState.ensureActiveTargetValid() }
    }

    /// Native System Settings-style hero: large app glyph, name, and a one-line
    /// description of what the app does.
    private var heroHeader: some View {
        VStack(spacing: 10) {
            // The app's own icon (the same artwork shown in the Dock and the
            // installer), so the Overview hero matches the app's identity.
            appIcon

            Text("Transcriptor")
                .font(.title2.weight(.bold))

            Text("Press your shortcut, speak, and your words are typed for you — transcribed on-device and saved to a private local history.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    /// The same beveled waveform tile used as the first sidebar icon, scaled up
    /// so the hero reads as part of the app's icon family.
    private var appIcon: some View {
        SidebarIconView(systemImage: NavigationScreen.overview.systemImage, size: 64)
    }

    /// Persistent call-to-action shown until a transcription model (or cloud
    /// provider) is configured. Rendered as a standard grouped Settings row —
    /// an icon, label, and prominent action button — rather than a custom card,
    /// matching the way native System Settings surfaces setup recommendations.
    private var setupRow: some View {
        LabeledContent {
            Button("Set Up…") {
                appState.presentWelcomeGuide()
            }
            .buttonStyle(.borderedProminent)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Set up transcription")
                        .font(.body.weight(.semibold))
                    Text("Download a model to turn recordings into text. Until then, Transcriptor still works as a voice recorder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// A status row that navigates to the place where the value can actually be
    /// changed. The whole row is the click target (like native System Settings
    /// list rows); the chevron is only a visual affordance.
    private func linkedRow(
        _ title: String,
        destination: SidebarItem,
        @ViewBuilder value: () -> some View
    ) -> some View {
        OverviewNavigationRow(
            title: title,
            help: helpText(for: destination),
            action: { appState.sidebarSelection = destination },
            value: value
        )
    }

    private func helpText(for destination: SidebarItem) -> String {
        switch destination {
        case let .screen(screen):
            "Open \(screen.title)"
        case let .settings(pane):
            "Change in Settings › \(pane.title)"
        }
    }

    /// The unified "Active model" row: a tile icon and title on the left, the
    /// live readiness status directly beneath the title, and the model selector
    /// on the trailing edge. This folds what used to be two separate rows
    /// ("Status" + "Active model") into one, matching how native System Settings
    /// pairs a primary control with its current state.
    private var activeModelRow: some View {
        HStack(spacing: 12) {
            SidebarIconView(systemImage: NavigationScreen.models.systemImage, size: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text("Active Model")
                transcriptionStatusLabel
            }

            Spacer(minLength: 12)

            activeModelSelector
        }
        .padding(.vertical, 2)
    }

    /// Trailing model selector. With ready targets it's a native pop-up picker;
    /// with none, it offers a one-tap jump to the Models page to download one.
    @ViewBuilder
    private var activeModelSelector: some View {
        if appState.availableTargets.isEmpty {
            Button("Download…") {
                appState.sidebarSelection = .screen(.models)
            }
        } else {
            Picker("Active model", selection: activeTargetBinding) {
                ForEach(appState.availableTargets, id: \.self) { target in
                    Text(appState.targetDisplayName(target)).tag(target)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
    }

    /// A compact readiness indicator in the native System Settings idiom: a small
    /// status dot (green when ready, red when a model is missing) with plain gray
    /// label text — no colored text, no checkmark glyph. A spinner stands in for
    /// the dot while the launch scan runs or the selected model loads into memory.
    @ViewBuilder
    private var transcriptionStatusLabel: some View {
        if appState.isSelectedModelLoading {
            busyStatus("Loading model…")
        } else {
            switch appState.transcriptionReadiness {
            case .preparing:
                busyStatus("Preparing…")
            case .ready:
                statusDot(color: .green, text: "Ready")
            case .needsModel:
                statusDot(color: .red, text: "No model downloaded")
            }
        }
    }

    private func busyStatus(_ text: String) -> some View {
        HStack(spacing: 5) {
            ProgressView()
                .controlSize(.small)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func statusDot(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func megabyteString(for bytes: Int64) -> String {
        String(format: "%.2f MB", Double(bytes) / 1_048_576)
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

}

/// A grouped-form navigation row whose entire surface is clickable and that
/// subtly highlights on hover, matching native System Settings list rows. The
/// trailing chevron is a visual indicator only — not the click target.
private struct OverviewNavigationRow<Value: View>: View {
    let title: String
    let help: String
    let action: () -> Void
    @ViewBuilder let value: Value
    @State private var isHovering = false

    init(
        title: String,
        help: String,
        action: @escaping () -> Void,
        @ViewBuilder value: () -> Value
    ) {
        self.title = title
        self.help = help
        self.action = action
        self.value = value()
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .foregroundStyle(.primary)

                Spacer(minLength: 12)

                value
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(StableRowButtonStyle())
        .onHover { isHovering = $0 }
        .listRowBackground(isHovering ? Color.primary.opacity(0.06) : Color.clear)
        .help(help)
    }
}
