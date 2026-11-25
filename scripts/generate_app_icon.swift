#!/usr/bin/env swift
import AppKit

// Renders the Transcriptor app icon as an .icns: a black squircle on Apple's
// macOS icon grid (824/1024 tile, 100 px margin) with a voice-memo style
// waveform: blue spoken part, white remainder, split by a text caret. Run from the repo root: swift scripts/generate_app_icon.swift

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("dist/AppIcon.iconset")
let resourcesIcon = root.appendingPathComponent("Sources/Transcriptor/Resources/AppIcon.icns")

try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(
    at: resourcesIcon.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

func rgb(_ hex: UInt32) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

func renderIcon(canvas: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvas),
        pixelsHigh: Int(canvas),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: canvas, height: canvas)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let inset = canvas * 100 / 1024
    let tileRect = NSRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)
    let radius = tileRect.width * 0.2237
    let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: radius, yRadius: radius)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = canvas * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -canvas * 0.01)
    shadow.set()
    NSGradient(colors: [rgb(0x232326), rgb(0x0B0B0C)])!.draw(in: tilePath, angle: -90)
    NSShadow().set()

    // Glass edge: brightest on top, like Apple's dark icons.
    NSGraphicsContext.saveGraphicsState()
    let rimWidth = max(1, canvas * 0.004)
    let rim = NSBezierPath(roundedRect: tileRect.insetBy(dx: rimWidth / 2, dy: rimWidth / 2), xRadius: radius, yRadius: radius)
    let rimOutline = NSBezierPath(cgPath: rim.cgPath.copy(strokingWithWidth: rimWidth, lineCap: .butt, lineJoin: .round, miterLimit: 10))
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.28), NSColor.white.withAlphaComponent(0.05)])!
        .draw(in: rimOutline, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Voice-memo style waveform: spoken part in Apple blue, the rest in white,
    // split by a text caret (voice → text).
    let unit = tileRect.width / 824
    let barWidth = 13 * unit
    let step = 33 * unit
    let caretX = tileRect.midX + 20 * unit
    let blueHeights: [CGFloat] = [0.06, 0.18, 0.12, 0.40, 0.30, 0.78, 0.52, 0.64, 0.92, 0.46, 0.70]
    let whiteHeights: [CGFloat] = [0.10, 0.30, 0.42, 0.20, 0.24, 0.08, 0.14, 0.05, 0.08]
    let maxHeight = tileRect.height * 0.66

    func bar(at x: CGFloat, _ h: CGFloat) -> NSBezierPath {
        let height = max(barWidth, maxHeight * h)
        return NSBezierPath(
            roundedRect: NSRect(x: x - barWidth / 2, y: tileRect.midY - height / 2, width: barWidth, height: height),
            xRadius: barWidth / 2, yRadius: barWidth / 2
        )
    }

    let blue = NSBezierPath()
    for (i, h) in blueHeights.reversed().enumerated() {
        blue.append(bar(at: caretX - CGFloat(i + 1) * step, h))
    }
    NSGradient(colors: [rgb(0x5AB0FF), rgb(0x0A6CFF)])!.draw(in: blue, angle: -90)

    let white = NSBezierPath()
    for (i, h) in whiteHeights.enumerated() {
        white.append(bar(at: caretX + CGFloat(i + 1) * step, h))
    }
    rgb(0xF2F2F7).setFill()
    white.fill()

    // Text caret (I-beam) with a soft blue glow.
    let caretHeight = tileRect.height * 0.74
    let stem = 12 * unit
    let serif = 56 * unit
    let caret = NSBezierPath(roundedRect: NSRect(x: caretX - stem / 2, y: tileRect.midY - caretHeight / 2, width: stem, height: caretHeight), xRadius: stem / 2, yRadius: stem / 2)
    for y in [tileRect.midY - caretHeight / 2, tileRect.midY + caretHeight / 2 - stem] {
        caret.append(NSBezierPath(roundedRect: NSRect(x: caretX - serif / 2, y: y, width: serif, height: stem), xRadius: stem / 2, yRadius: stem / 2))
    }
    let glow = NSShadow()
    glow.shadowColor = rgb(0x2E8BFF).withAlphaComponent(0.9)
    glow.shadowBlurRadius = canvas * 0.03
    glow.shadowOffset = .zero
    NSGraphicsContext.saveGraphicsState()
    glow.set()
    rgb(0x7DBBFF).setFill()
    caret.fill()
    NSGraphicsContext.restoreGraphicsState()
    rgb(0xBFDDFF).setFill()
    caret.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let variants: [(name: String, px: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for variant in variants {
    let rep = renderIcon(canvas: variant.px)
    guard let data = rep.representation(using: .png, properties: [:]) else { continue }
    try data.write(to: iconset.appendingPathComponent("\(variant.name).png"))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", resourcesIcon.path]
try process.run()
process.waitUntilExit()

print(process.terminationStatus == 0
    ? "Wrote \(resourcesIcon.path)"
    : "iconutil failed (\(process.terminationStatus))")
