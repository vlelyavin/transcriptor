import SwiftUI

// MARK: - Frame-rate independent spring

/// A critically damped spring, solved in closed form, so the picture is the
/// same at 30, 60 or 120 Hz and a late frame can never overshoot.
///
/// This is the same model Hex uses for its dot scope (`rune_hud::spring`),
/// with the bounce term dropped: a level meter wants no overshoot, only a
/// fast rise and a slower fall.
struct WaveSpring {
    private(set) var x: CGFloat = 0
    private var v: CGFloat = 0

    mutating func step(toward target: CGFloat, duration: Double, dt: Double) {
        guard dt > 0, duration > 0 else { return }
        let w = CGFloat(2 * Double.pi / duration)
        let dt = CGFloat(dt)
        let x0 = x - target
        let v0 = v
        let e = exp(-w * dt)
        x = target + (x0 + (v0 + w * x0) * dt) * e
        v = (v0 - w * (v0 + w * x0) * dt) * e
        if abs(x - target) < 0.0005, abs(v) < 0.0005 {
            x = target
            v = 0
        }
    }
}

// MARK: - Animator

/// Holds the spring state for every band.
///
/// Deliberately **not** `@Observable` and not `@MainActor`-annotated: it is
/// stepped from inside the canvas' draw closure and must not invalidate the
/// view graph by itself — `TimelineView` already redraws at the display's
/// rate. Keeping it out of SwiftUI's observation keeps a recording at one
/// redraw per frame instead of one per frame *plus* one per audio sample.
///
/// Confined to the main thread by construction: it is only ever touched from
/// the view's draw closure, and the canvas is not asynchronous.
final class WaveAnimator {
    private(set) var values: [CGFloat]

    private var springs: [WaveSpring]
    private var last: Date?

    init(bands: Int = OverlayDesign.Wave.barCount) {
        values = Array(repeating: 0, count: bands)
        springs = Array(repeating: WaveSpring(), count: bands)
    }

    /// Resizes when the view asks for a different band count (the compact
    /// pill draws fewer bars than the standard card).
    func resize(to bands: Int) {
        guard bands != values.count, bands > 0 else { return }
        values = Array(repeating: 0, count: bands)
        springs = Array(repeating: WaveSpring(), count: bands)
        last = nil
    }

    /// Feeds one audio snapshot in and settles the springs to `date`.
    func step(levels: [Float], to date: Date, attack: Double, release: Double) {
        let dt = last.map { date.timeIntervalSince($0) } ?? 0
        last = date
        // A stalled frame must not teleport the bars; a burst of catch-up
        // frames must not be stepped as one long frame either.
        let clamped = min(max(dt, 0), 1.0 / 15.0)

        let targets = Self.targets(from: levels, bands: values.count, gamma: OverlayDesign.Wave.gamma)

        for i in values.indices {
            let target = targets[i]
            let duration = target > springs[i].x ? attack : release
            springs[i].step(toward: target, duration: duration, dt: clamped)
            values[i] = springs[i].x
        }
    }

    /// Resamples the recorder's bands to the bar count, applies the perceptual
    /// curve, then runs one 3-tap smoothing pass so neighbouring bars read as
    /// one wave instead of a row of unrelated sliders.
    static func targets(from levels: [Float], bands: Int, gamma: Float) -> [CGFloat] {
        guard bands > 0 else { return [] }
        guard !levels.isEmpty else { return Array(repeating: 0, count: bands) }

        var shaped = levels.map { level -> CGFloat in
            let clamped = min(max(level, 0), 1)
            return CGFloat(pow(clamped, gamma))
        }

        // Upsample by linear interpolation when the recorder gives fewer
        // bands than we draw (12 -> 20 is the shipping case).
        if shaped.count != bands, shaped.count > 1 {
            let lastSource = CGFloat(shaped.count - 1)
            shaped = (0..<bands).map { i in
                let position = CGFloat(i) / CGFloat(bands - 1) * lastSource
                let low = Int(position.rounded(.down))
                let high = min(low + 1, shaped.count - 1)
                let t = position - CGFloat(low)
                return shaped[low] + (shaped[high] - shaped[low]) * t
            }
        }

        guard shaped.count > 2 else { return shaped }
        var smoothed = shaped
        for i in 1..<(shaped.count - 1) {
            smoothed[i] = shaped[i - 1] * 0.22 + shaped[i] * 0.56 + shaped[i + 1] * 0.22
        }
        return smoothed
    }
}

// MARK: - Snapshot (previews and render tests)

/// Draws the wave from fixed magnitudes instead of the springs. Used by
/// previews, screenshot tests and the design renders — never in the app.
struct WaveformSnapshot: View {
    let values: [CGFloat]
    let barWidth: CGFloat
    let gap: CGFloat
    let height: CGFloat
    let tint: Color

    var body: some View {
        Canvas(rendersAsynchronously: false) { canvas, size in
            let centre = size.height / 2
            let shading = GraphicsContext.Shading.linearGradient(
                Gradient(stops: [
                    .init(color: tint.opacity(0.55), location: 0),
                    .init(color: tint, location: 0.5),
                    .init(color: tint.opacity(0.55), location: 1),
                ]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            )
            var x: CGFloat = 0
            for value in values {
                let barHeight = OverlayDesign.Wave.minHeight
                    + value * (size.height - OverlayDesign.Wave.minHeight)
                let rect = CGRect(x: x, y: centre - barHeight / 2, width: barWidth, height: barHeight)
                canvas.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: shading)
                x += barWidth + gap
            }
        }
        .frame(
            width: OverlayDesign.Wave.width(bars: values.count, bar: barWidth, gap: gap),
            height: height
        )
    }
}

// MARK: - The wave

/// A mirrored, rounded-cap waveform that follows the microphone.
///
/// Two clocks, on purpose: audio arrives at ~20 Hz, the display asks for
/// frames at 60–120 Hz. `TimelineView` supplies the frame clock; the springs
/// turn 20 Hz data into motion at the frame rate, so the wave glides instead
/// of stepping, and the cost stays flat because nothing is animated through
/// Core Animation (the bug that made the old meter freeze the overlay).
struct LiveWaveformView: View {
    let levels: [Float]
    var bars: Int = OverlayDesign.Wave.barCount
    var barWidth: CGFloat = OverlayDesign.Wave.barWidth
    var gap: CGFloat = OverlayDesign.Wave.gap
    var height: CGFloat = OverlayDesign.Wave.height
    var tint: Color = .accentColor
    var isActive: Bool = true
    var showsCenterLine: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var animator = WaveAnimator()

    private var width: CGFloat {
        OverlayDesign.Wave.width(bars: bars, bar: barWidth, gap: gap)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isActive)) { context in
            Canvas(rendersAsynchronously: false) { canvas, size in
                draw(in: &canvas, size: size, at: context.date)
            }
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, at date: Date) {
        animator.resize(to: bars)
        animator.step(
            levels: levels,
            to: date,
            attack: OverlayDesign.Wave.attack,
            release: OverlayDesign.Wave.release
        )
        let centre = size.height / 2
        let live = animator.values
        guard live.count == bars else { return }

        // One shading for every bar. Building a gradient per bar per frame was
        // the old meter's hidden cost; a single gradient keeps the canvas in
        // the microsecond range.
        let shading = GraphicsContext.Shading.linearGradient(
            Gradient(stops: [
                .init(color: tint.opacity(0.55), location: 0),
                .init(color: tint, location: 0.5),
                .init(color: tint.opacity(0.55), location: 1),
            ]),
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 0, y: size.height)
        )

        // The line the wave rests on, so silence still reads as "listening".
        if showsCenterLine {
            canvas.fill(
                Path(CGRect(x: 0, y: centre - 0.25, width: size.width, height: 0.5)),
                with: .color(tint.opacity(0.18))
            )
        }

        var x: CGFloat = 0
        for i in 0..<bars {
            var magnitude = live[i]
            // Reduce Motion keeps the wave honest but calmer: no spring
            // overshoot in the first place, and a little less travel.
            if reduceMotion { magnitude *= 0.85 }
            let barHeight = OverlayDesign.Wave.minHeight
                + magnitude * (size.height - OverlayDesign.Wave.minHeight)
            let rect = CGRect(
                x: x,
                y: centre - barHeight / 2,
                width: barWidth,
                height: barHeight
            )
            canvas.fill(
                Path(roundedRect: rect, cornerRadius: barWidth / 2),
                with: shading
            )

            x += barWidth + gap
        }
    }
}
