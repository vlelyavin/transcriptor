import SwiftUI
import Observation

/// A single, full-width, continuously animated waveform — the macOS-native
/// "listening" affordance (Siri-style). One smooth line whose amplitude
/// breathes with the live microphone level; no separate icon-based
/// equalizer, no capsule bars.
///
/// The view reads `voiceInputController.liveLevels` directly inside
/// `Canvas`'s renderer *through a `TimelineView`*, so the wave redraws on
/// every animation frame from the freshest level snapshot. This fixes the
/// historical "meter frozen while listening" bug structurally: the old
/// meter depended on the overlay panel's SwiftUI re-rendering on
/// `@Observable` changes — which, inside a borderless `NSPanel` whose
/// `contentView` is replaced on each `refreshPresentation`, never fired
/// between state transitions. Reading the level every frame makes the
/// drawing independent of the panel's update plumbing.
struct ContinuousWaveformView: View {
    /// Observed read-only controller; only `liveLevels` is read per frame.
    var voiceInputController: VoiceInputController
    /// Tint for the wave (accent by default, red while audio is hot).
    var tint: Color = .accentColor

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 45)) { timeline in
            Canvas { context, size in
                draw(in: &context, size: size, date: timeline.date)
            }
        }
        .accessibilityHidden(true)
    }

    private func draw(
        in context: inout GraphicsContext,
        size: CGSize,
        date: Date
    ) {
        let snapshot = voiceInputController.liveLevels
        let level = Double(snapshot.rms)
        let peak = Double(snapshot.peak)

        let height = size.height
        let mid = height / 2
        let width = size.width
        let now = date.timeIntervalSinceReferenceDate

        // Amplitude envelope: smooth toward the current level so the wave
        // breathes instead of jittering. Speech-vs-silence shaping keeps a
        // visible idle ripple so the line never looks dead.
        let envelope = max(level, 0.045)

        // Waveform: layered sines with slowly rotating phase. Higher
        // harmonics grow with the instantaneous peak so consonants pop.
        var path = Path()
        let points = max(Int(width / 3), 24)
        let baseFrequency = 2.1
        let phase = now * 2.6

        for i in 0...points {
            let t = Double(i) / Double(points)
            let x = t * width

            let fundamental = sin((t * baseFrequency * 2 * .pi) + phase)
            let harmonic = sin((t * baseFrequency * 4.7 * .pi) - phase * 1.7)
            let shimmer = sin((t * baseFrequency * 9.3 * .pi) + phase * 2.3)

            let harmonicMix = fundamental * 0.72 + harmonic * 0.2 * (0.4 + peak) + shimmer * 0.08 * (0.3 + level)
            let amplitude = harmonicMix * envelope
            let y = mid - amplitude * (height * 0.42)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Fade the line's opacity with level so idle state is subtle and
        // active speech is vivid — depth without a second color.
        let opacity = 0.35 + min(level * 2.2, 0.65)
        context.stroke(
            path,
            with: .color(tint.opacity(opacity)),
            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
        )

        // A soft under-glow only while the user is actually speaking.
        if level > 0.08 {
            context.stroke(
                path,
                with: .color(tint.opacity(0.18)),
                style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
            )
        }
    }
}
