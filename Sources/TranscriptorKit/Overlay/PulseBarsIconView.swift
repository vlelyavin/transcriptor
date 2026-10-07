import SwiftUI

/// The recording overlay's leading status tile while listening: the familiar
/// beveled dark icon tile, but its bars are LIVE — five symmetric vertical
/// bars that pulse smoothly with the microphone level (the Apple Watch /
/// iMessage voice-memo pattern). Replaces both the static waveform glyph
/// and the capsule strip that used to sit under the title.
///
/// Stability rules learned from the first redesign attempt: bars are
/// mirrored symmetrically around the center, positions are fixed, and
/// heights interpolate toward their targets every frame — no phase
/// rotation, no arbitrary harmonics, nothing that can look "wobbly".
struct PulseBarsIconView: View {
    var voiceInputController: VoiceInputController
    /// Tile edge length.
    var size: CGFloat = 40
    var animated: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            Canvas { context, size in
                draw(in: &context, size: size, date: timeline.date)
            }
        }
        .frame(width: size, height: size)
        .background {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.28), Color(white: 0.16)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        }
        .shadow(color: .black.opacity(0.18), radius: 0.5, y: 0.5)
        .accessibilityHidden(true)
    }

    private func draw(
        in context: inout GraphicsContext,
        size: CGSize,
        date: Date
    ) {
        let snapshot = voiceInputController.liveLevels
        // Speech shaping: rms*4 already capped at 1; give quiet speech more
        // presence with a gentle gamma, then clamp.
        let level = pow(min(max(Double(snapshot.rms), 0), 1), 0.75)

        // Deterministic time base for the idle shimmer (very slow, subtle).
        let t = date.timeIntervalSinceReferenceDate

        // Five bars, symmetric around the center: heights differ by a fixed
        // spatial profile (classic voice-note look: short, tall, tallest,
        // tall, short) modulated by level and a slow shared breathing wave.
        let barCount = 5
        let barWidth = size.width * 0.09
        let gap = size.width * 0.055
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * gap
        let startX = (size.width - totalWidth) / 2
        let maxBarHeight = size.height * 0.52
        let minBarHeight = size.height * 0.10

        // Fixed spatial profile (0...1) for a stable silhouette.
        let profile: [Double] = [0.55, 0.85, 1.0, 0.85, 0.55]

        for i in 0..<barCount {
            // Shared slow pulse so the whole cluster feels alive but calm.
            let pulse = 0.82 + 0.18 * sin(t * 2.2 + Double(i) * 0.55)
            let target = level * profile[i] * pulse

            // Height: never below the idle stub so bars are always visible.
            let height = minBarHeight + max(target, 0.12) * (maxBarHeight - minBarHeight)

            let x = startX + CGFloat(i) * (barWidth + gap)
            let bar = CGRect(
                x: x,
                y: (size.height - height) / 2,
                width: barWidth,
                height: height
            )
            let path = Path(roundedRect: bar, cornerRadius: barWidth / 2, style: .continuous)
            context.fill(path, with: .color(.white.opacity(0.95)))
        }
    }
}
