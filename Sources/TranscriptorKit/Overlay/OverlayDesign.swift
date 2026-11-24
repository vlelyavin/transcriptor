import SwiftUI

// MARK: - Design tokens

/// One place for every number the overlay uses. Sizes are in points at 1x.
enum OverlayDesign {
    enum Standard {
        /// Fixed: a status strip that changes width mid-dictation reads as
        /// collapsing. The air is split by two spacers so no single gap
        /// grows into a void when the title is short.
        static let width: CGFloat = 372
        static let maxTitleWidth: CGFloat = 168
        /// The slot the wave lives in — kept while working so the row never
        /// re-flows, and filled with a progress track instead.
        static var activityWidth: CGFloat {
            Wave.width(bars: Wave.barCount, bar: Wave.barWidth, gap: Wave.gap)
        }
        static let activityHeight: CGFloat = 22
        static let minHeight: CGFloat = 64
        /// Tallest a standard card gets: title plus two lines of detail.
        static let maxHeight: CGFloat = 78
        static let cornerRadius: CGFloat = 18
        /// Leading/trailing inset of the content row.
        static let horizontalPadding: CGFloat = 14
        /// Gap between the row's blocks.
        static let spacing: CGFloat = 12
        /// Gap between an indicator or button and the block beside it.
        static let tightSpacing: CGFloat = 10
    }

    enum Compact {
        static let minWidth: CGFloat = 132
        static let height: CGFloat = 40
        /// A pill: half the height.
        static let cornerRadius: CGFloat = 20
        static let horizontalPadding: CGFloat = 12
        static let spacing: CGFloat = 8

        /// Width the card will take, so the panel can hit-test exactly it.
        static func width(showsTimer: Bool, showsWave: Bool, showsStop: Bool) -> CGFloat {
            var width = horizontalPadding * 2 + 14
            if showsTimer { width += spacing + 32 }
            if showsWave {
                width += spacing + Wave.width(bars: Wave.compactBars, bar: Wave.compactBarWidth, gap: Wave.compactGap)
            }
            if showsStop { width += spacing + Button.stop }
            return max(minWidth, width)
        }
    }

    enum Wave {
        /// Seventeen mirrored capsules: the frame the user picked from the
        /// design renders. Odd on purpose, so one bar sits exactly on the
        /// centre axis and the wave reads as symmetric.
        static let barCount = 17
        static let barWidth: CGFloat = 2.5
        static let gap: CGFloat = 1.5
        static let height: CGFloat = 22
        /// A silent band still shows this much: the row never disappears.
        static let minHeight: CGFloat = 2.5
        /// Per-band spring durations. Attack is quick enough to catch a
        /// syllable; release is slow enough to read as a tail, not a flicker.
        static let attack: Double = 0.10
        static let release: Double = 0.30
        /// Perceptual boost so quiet speech still moves the bars.
        static let gamma: Float = 0.62
        /// Compact bars.
        static let compactBars = 12
        static let compactBarWidth: CGFloat = 2
        static let compactGap: CGFloat = 2
        static let compactHeight: CGFloat = 16

        static func width(bars: Int, bar: CGFloat, gap: CGFloat) -> CGFloat {
            CGFloat(bars) * bar + CGFloat(max(bars - 1, 0)) * gap
        }
    }

    enum Dot {
        static let size: CGFloat = 8
        /// The halo behind a listening dot.
        static let halo: CGFloat = 18
    }

    /// The listening orb: one living object instead of a dot, a label and a
    /// hint stacked on top of each other.
    enum Orb {
        static let size: CGFloat = 34
        /// Room for the glow around the sphere.
        static let glowScale: CGFloat = 1.22
        /// Perceptual boost so quiet speech still moves the orb.
        static let gain: CGFloat = 2.4
    }

    enum Button {
        static let stop: CGFloat = 24
        static let cancel: CGFloat = 20
    }

    enum Motion {
        /// Hex's `MORPH`: 0.30s, bounce 0.15. Used for arriving, morphing
        /// between modes, and leaving, so all three read as one material.
        static let morph = Animation.spring(duration: 0.30, bounce: 0.15)
        /// Reduce Motion: 0.16s crossfade, no scale, no travel (Hex `REDUCED_FADE`).
        static let reducedFade = Animation.easeOut(duration: 0.16)
        /// A line of text changing its words.
        static let text = Animation.easeInOut(duration: 0.16)
        /// The listening dot's breathing, in seconds.
        static let pulse: Double = 1.2
        /// The activity track's sweep, in seconds.
        static let sweep: Double = 0.8
    }

    enum Shadow {
        static let ambientRadius: CGFloat = 20
        static let ambientY: CGFloat = 8
        /// Light mode takes a lighter shadow: the same black over a pale
        /// desktop reads as grime rather than depth.
        static let ambientOpacity: Double = 0.26
        static let ambientOpacityLight: Double = 0.16
        static let contactRadius: CGFloat = 2
        static let contactY: CGFloat = 1
        static let contactOpacity: Double = 0.14
        static let contactOpacityLight: Double = 0.08
        /// Transparent room the panel must leave around the card so the
        /// SwiftUI shadow is not clipped by the window's bounds.
        static let margin: CGFloat = 28
    }
}

// MARK: - Surface style

/// Which material the card draws. `automatic` is what the app uses: Liquid
/// Glass on macOS 26+, vibrancy below it. Previews and render tests pin one
/// so a screenshot is reproducible on any machine.
enum OverlaySurfaceStyle: Sendable {
    case automatic
    case glass
    case material
}

private struct OverlaySurfaceStyleKey: EnvironmentKey {
    static let defaultValue = OverlaySurfaceStyle.automatic
}

extension EnvironmentValues {
    var overlaySurfaceStyle: OverlaySurfaceStyle {
        get { self[OverlaySurfaceStyleKey.self] }
        set { self[OverlaySurfaceStyleKey.self] = newValue }
    }
}

// MARK: - Surface

/// The card's material, edge and shadow.
///
/// macOS 26 and later draw a real Liquid Glass surface; earlier systems get a
/// vibrancy card built from `.regularMaterial` with the same optics: a light
/// top highlight, a dark rim, and a two-part shadow (tight contact + wide
/// ambient). Both paths are the same size, so nothing moves when the system
/// changes its mind about how a floating panel should look.
struct OverlaySurface<S: InsettableShape>: ViewModifier {
    let shape: S
    var shadowed: Bool = true
    @Environment(\.overlaySurfaceStyle) private var style
    @Environment(\.colorScheme) private var colorScheme

    private var highlight: LinearGradient {
        LinearGradient(
            colors: [.white.opacity(0.26), .white.opacity(0.04)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var ambient: Double {
        shadowed ? (colorScheme == .dark ? OverlayDesign.Shadow.ambientOpacity : OverlayDesign.Shadow.ambientOpacityLight) : 0
    }

    private var contact: Double {
        shadowed ? (colorScheme == .dark ? OverlayDesign.Shadow.contactOpacity : OverlayDesign.Shadow.contactOpacityLight) : 0
    }

    /// The rim is `.primary` at low alpha, so it is a light line on a dark
    /// card and a dark line on a pale one — the one edge treatment that
    /// survives both appearances.
    private var rim: Color { .primary.opacity(0.10) }

    private var usesGlass: Bool {
        switch style {
        case .automatic, .glass:
            if #available(macOS 26.0, *) { return true }
            return false
        case .material:
            return false
        }
    }

    func body(content: Content) -> some View {
        if usesGlass, #available(macOS 26.0, *) {
            content
                .glassEffect(.regular, in: shape)
                .overlay {
                    shape
                        .inset(by: 0.5)
                        .strokeBorder(highlight, lineWidth: 0.5)
                        .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(ambient), radius: OverlayDesign.Shadow.ambientRadius, y: OverlayDesign.Shadow.ambientY)
                .shadow(color: .black.opacity(contact), radius: OverlayDesign.Shadow.contactRadius, y: OverlayDesign.Shadow.contactY)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay {
                    shape
                        .inset(by: 0.5)
                        .strokeBorder(highlight, lineWidth: 0.5)
                        .allowsHitTesting(false)
                }
                .overlay {
                    shape
                        .inset(by: 0.5)
                        .strokeBorder(rim, lineWidth: 0.5)
                        .allowsHitTesting(false)
                }
                .clipShape(shape)
                .shadow(color: .black.opacity(ambient), radius: OverlayDesign.Shadow.ambientRadius, y: OverlayDesign.Shadow.ambientY)
                .shadow(color: .black.opacity(contact), radius: OverlayDesign.Shadow.contactRadius, y: OverlayDesign.Shadow.contactY)
        }
    }
}

extension View {
    func overlaySurface<S: InsettableShape>(_ shape: S) -> some View {
        modifier(OverlaySurface(shape: shape))
    }
}
