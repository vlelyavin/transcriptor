import SwiftUI

// MARK: - Phase

/// What the card is telling the user. One case per thing that changes the
/// picture — not one per internal state. The manager derives it from
/// `VoiceInputController.state` + `OverlaySupplementalPhase`.
enum OverlayPhase: Equatable, Sendable {
    case permission
    case listening
    case finishing
    case working(String)      // "Transcribing", "Inserting"
    case inserted(String?)    // detail: the inserted text's first line
    case failed(String)
}

enum RecordingModeKind: Sendable {
    case hold
    case toggle
}

// MARK: - Card

/// The recording overlay: one row, two sizes.
///
/// Standard is a fixed 372 pt strip while the microphone or the transcriber
/// is busy, and hugs its text once the words are in. Compact is a 40 pt pill.
/// Both share the surface, the type scale and the motion, so switching
/// between them reads as the same card refolding.
struct RecordingOverlayCard: View {
    let phase: OverlayPhase
    let levels: [Float]
    let elapsed: TimeInterval
    var mode: OverlayDisplayMode = .standard
    var recordingMode: RecordingModeKind = .toggle
    var showsWaveform: Bool = true
    var onStop: () -> Void = {}
    var onCancel: () -> Void = {}
    /// Preview-only: draws the wave from fixed magnitudes so a still frame can
    /// show the gesture. `nil` in the app, where the springs drive it.
    var previewValues: [CGFloat]? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch mode {
            case .standard: standard
            case .compact: compact
            }
        }
        .overlaySurface(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .animation(reduceMotion ? OverlayDesign.Motion.reducedFade : OverlayDesign.Motion.morph, value: mode)
        .animation(reduceMotion ? OverlayDesign.Motion.reducedFade : OverlayDesign.Motion.text, value: phase)
        .accessibilityElement(children: .contain)
    }

    private var cornerRadius: CGFloat {
        mode == .standard ? OverlayDesign.Standard.cornerRadius : OverlayDesign.Compact.cornerRadius
    }

    // MARK: Standard

    /// While the microphone is open the card says nothing in words: the orb
    /// moves with the voice and the clock counts. Words only appear once there
    /// is something to report (working, inserted, failed).
    private var standard: some View {
        Group {
            if isListening {
                listeningRow
            } else {
                statusRow
            }
        }
    }

    private var listeningRow: some View {
        HStack(spacing: OverlayDesign.Standard.spacing) {
            ListeningOrb(levels: levels, reduceMotion: reduceMotion)

            Text(timeLabel)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Spacer(minLength: OverlayDesign.Standard.spacing)

            if showsWaveform {
                wave(
                    bars: OverlayDesign.Wave.compactBars,
                    barWidth: OverlayDesign.Wave.compactBarWidth,
                    gap: OverlayDesign.Wave.compactGap,
                    height: OverlayDesign.Wave.compactHeight
                )
                .transition(.opacity)
            }

            Spacer(minLength: OverlayDesign.Standard.spacing)

            HStack(spacing: OverlayDesign.Standard.tightSpacing) {
                if showsStop { stopButton }
                if showsCancel { cancelButton }
            }
        }
        .padding(.horizontal, OverlayDesign.Standard.horizontalPadding)
        .padding(.vertical, 10)
        .frame(width: OverlayDesign.Standard.width, alignment: .leading)
        .frame(minHeight: OverlayDesign.Standard.minHeight)
    }

    private var statusRow: some View {
        HStack(spacing: 0) {
            HStack(alignment: detail == nil ? .center : .top, spacing: OverlayDesign.Standard.tightSpacing) {
                indicator
                    .frame(width: 18, height: 18)
                    .padding(.top, detail == nil ? 0 : 1)

                // The clock sits at the leading edge, next to the dot, the way
                // a recorder shows it — and it never moves when the trailing
                // buttons come and go.
                if showsTimer {
                    Text(timeLabel)
                        .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .frame(width: 34, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .contentTransition(.opacity)

                    if let detail {
                        Text(detail)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: hasActivitySlot ? OverlayDesign.Standard.maxTitleWidth : 300, alignment: .leading)
            }

            if hasActivitySlot {
                // The air lives on both sides of the wave, so no single gap
                // can grow into a void when the title is short.
                Spacer(minLength: OverlayDesign.Standard.spacing)

                activitySlot

                Spacer(minLength: OverlayDesign.Standard.spacing)
            }

            HStack(spacing: OverlayDesign.Standard.tightSpacing) {
                if showsStop { stopButton }
                if showsCancel { cancelButton }
            }
        }
        .padding(.horizontal, OverlayDesign.Standard.horizontalPadding)
        .padding(.vertical, 12)
        // Recording rows are fixed width so the controls never wander; result
        // banners hug their text so they do not end in a dead zone.
        .frame(width: hasActivitySlot ? OverlayDesign.Standard.width : nil, alignment: .leading)
        .frame(minHeight: OverlayDesign.Standard.minHeight)
    }

    /// The wave while listening, a progress track while working, nothing once
    /// the words are in. The slot keeps its size either way, so the row never
    /// re-flows between states.
    @ViewBuilder
    private var activitySlot: some View {
        ZStack {
            if showsWaveform, isListening {
                wave(
                    bars: OverlayDesign.Wave.barCount,
                    barWidth: OverlayDesign.Wave.barWidth,
                    gap: OverlayDesign.Wave.gap,
                    height: OverlayDesign.Wave.height
                )
                .transition(.opacity)
            } else if isWorking {
                ActivityTrack(
                    width: OverlayDesign.Standard.activityWidth,
                    reduceMotion: reduceMotion
                )
                .transition(.opacity)
            }
        }
        .frame(width: OverlayDesign.Standard.activityWidth, height: OverlayDesign.Standard.activityHeight)
    }

    // MARK: Compact

    private var compact: some View {
        HStack(spacing: OverlayDesign.Compact.spacing) {
            indicator
                .frame(width: 14, height: 14)

            if showsTimer {
                Text(timeLabel)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            if showsWaveform, isListening {
                wave(
                    bars: OverlayDesign.Wave.compactBars,
                    barWidth: OverlayDesign.Wave.compactBarWidth,
                    gap: OverlayDesign.Wave.compactGap,
                    height: OverlayDesign.Wave.compactHeight
                )
                .transition(.opacity)
            }

            if showsStop { stopButton }
        }
        .padding(.horizontal, OverlayDesign.Compact.horizontalPadding)
        .frame(minWidth: OverlayDesign.Compact.minWidth, minHeight: OverlayDesign.Compact.height)
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: Indicator

    @ViewBuilder
    private var indicator: some View {
        switch phase {
        case .listening:
            ListeningDot(reduceMotion: reduceMotion)
        case .permission:
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange)
        case .finishing, .working:
            // No spinner: the activity track in the wave's slot carries the
            // motion, so the row keeps one moving part instead of two.
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.16))
                    .frame(width: 16, height: 16)
                Circle()
                    .fill(Color.accentColor.opacity(0.55))
                    .frame(width: 7, height: 7)
            }
        case .inserted:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
        }
    }

    // MARK: Wave

    @ViewBuilder
    private func wave(bars: Int, barWidth: CGFloat, gap: CGFloat, height: CGFloat) -> some View {
        if let previewValues {
            WaveformSnapshot(values: previewValues, barWidth: barWidth, gap: gap, height: height, tint: .accentColor)
        } else {
            LiveWaveformView(
                levels: levels,
                bars: bars,
                barWidth: barWidth,
                gap: gap,
                height: height,
                tint: .accentColor
            )
        }
    }

    // MARK: Buttons

    /// A filled accent circle with a rounded stop glyph. The glyph is drawn
    /// rather than taken from SF Symbols because `stop.fill` has square
    /// corners, which read as sharp next to the card's continuous radii.
    private var stopButton: some View {
        Button(action: onStop) {
            RoundedRectangle(cornerRadius: 1.6, style: .continuous)
                .fill(.white)
                .frame(width: 9, height: 9)
                .frame(width: OverlayDesign.Button.stop, height: OverlayDesign.Button.stop)
                .background(
                    Circle()
                        .fill(Color.accentColor)
                        .overlay(
                            Circle().strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
                        )
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Stop recording")
        .accessibilityLabel("Stop recording")
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: OverlayDesign.Button.cancel, height: OverlayDesign.Button.cancel)
                .background(Circle().fill(.quaternary))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Cancel recording")
        .accessibilityLabel("Cancel recording")
    }

    // MARK: Derivations

    private var isListening: Bool { phase == .listening }

    /// The wave's slot: present while the microphone is open or the app is
    /// working. Once the words are in, the row gives that width back to the
    /// text.
    private var hasActivitySlot: Bool {
        switch phase {
        case .listening, .finishing, .working: true
        case .permission, .inserted, .failed: false
        }
    }

    private var isWorking: Bool {
        switch phase {
        case .finishing, .working: true
        default: false
        }
    }

    private var showsStop: Bool { phase == .listening && recordingMode == .toggle }

    /// The clock belongs to the recording, not to the result: a finished card
    /// shows words, not a stopped stopwatch.
    private var showsTimer: Bool {
        switch phase {
        case .listening, .finishing, .working: true
        case .permission, .inserted, .failed: false
        }
    }

    private var showsCancel: Bool {
        // Only while recording: the panel is non-interactive in every other
        // state, so a visible ✕ there would be a dead control.
        phase == .listening && recordingMode == .toggle
    }

    private var title: String {
        switch phase {
        case .permission: "Microphone Access"
        case .listening: "Listening"
        case .finishing: "Finishing"
        case .working(let label): label
        case .inserted: "Inserted"
        case .failed: "Couldn’t Transcribe"
        }
    }

    private var detail: String? {
        switch phase {
        case .listening:
            recordingMode == .hold ? "Release to finish" : nil
        case .inserted(let text):
            text.flatMap { $0.isEmpty ? nil : $0 }
        case .failed(let message):
            message
        case .permission:
            "Allow access to start"
        default:
            nil
        }
    }

    private var timeLabel: String {
        let seconds = max(0, Int(elapsed))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - Activity track

/// A 3 pt track with a highlight running along it: the same "work is
/// happening" idea as the wave, without a second spinner. Reduce Motion
/// leaves the highlight parked at 35%.
private struct ActivityTrack: View {
    let width: CGFloat
    let reduceMotion: Bool
    @State private var running = false

    private let height: CGFloat = 3
    private let head: CGFloat = 30

    var body: some View {
        Capsule(style: .continuous)
            .fill(.quaternary)
            .frame(width: width, height: height)
            .overlay(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.8))
                    .frame(width: head, height: height)
                    .offset(x: running ? width - head : 0)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: OverlayDesign.Motion.sweep).repeatForever(autoreverses: true),
                        value: running
                    )
                    .opacity(reduceMotion ? 0.35 : 1)
            }
            .onAppear { running = !reduceMotion }
            .accessibilityHidden(true)
    }
}

// MARK: - Listening dot

/// The listening orb: a small sphere that brightens and swells with the voice
/// and carries a soft halo. One object replaces the dot, the "Listening" label
/// and the "Release to finish" hint, so the card reads at a glance.
private struct ListeningOrb: View {
    let levels: [Float]
    let reduceMotion: Bool

    @State private var breathed = false

    private var intensity: CGFloat {
        guard !levels.isEmpty else { return 0 }
        let mean = levels.reduce(Float(0)) { $0 + $1 * $1 } / Float(levels.count)
        return min(1, max(0, CGFloat(sqrt(mean)) * OverlayDesign.Orb.gain))
    }

    var body: some View {
        let size = OverlayDesign.Orb.size
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.20))
                .frame(width: size, height: size)
                .blur(radius: 7)
                .scaleEffect((breathed ? 1.5 : 1.18) + intensity * 0.30)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color.accentColor.opacity(0.95),
                            Color.accentColor.opacity(0.55)
                        ],
                        center: UnitPoint(x: 0.36, y: 0.30),
                        startRadius: 1,
                        endRadius: size * 0.78
                    )
                )
                .frame(width: size, height: size)
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.28), lineWidth: 0.6)
                }
                .scaleEffect(1 + intensity * 0.16)

            Circle()
                .fill(Color.white.opacity(0.42))
                .frame(width: size * 0.26, height: size * 0.26)
                .blur(radius: size * 0.10)
                .offset(x: -size * 0.17, y: -size * 0.20)
        }
        .frame(width: size * OverlayDesign.Orb.glowScale, height: size * OverlayDesign.Orb.glowScale)
        .animation(
            reduceMotion ? nil : .spring(duration: 0.16, bounce: 0.28),
            value: intensity
        )
        .onAppear { breathed = !reduceMotion }
        .animation(
            reduceMotion
                ? nil
                : .easeInOut(duration: OverlayDesign.Motion.pulse).repeatForever(autoreverses: true),
            value: breathed
        )
        .accessibilityLabel("Recording")
    }
}

/// An 8 pt dot in a soft halo that breathes while the microphone is open.
/// Reduce Motion stops the breathing and keeps the halo, so the state stays
/// legible without movement.
private struct ListeningDot: View {
    let reduceMotion: Bool
    @State private var breathing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.18))
                .frame(width: OverlayDesign.Dot.halo, height: OverlayDesign.Dot.halo)
                .scaleEffect(breathing ? 1.0 : 0.72)
                .animation(
                    reduceMotion
                        ? nil
                        : .easeInOut(duration: OverlayDesign.Motion.pulse).repeatForever(autoreverses: true),
                    value: breathing
                )

            Circle()
                .fill(Color.accentColor)
                .frame(width: OverlayDesign.Dot.size, height: OverlayDesign.Dot.size)
        }
        .onAppear { breathing = !reduceMotion }
        .accessibilityLabel("Recording")
    }
}
