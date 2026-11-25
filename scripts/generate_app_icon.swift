#!/usr/bin/env swift
import AppKit

// Renders the Transcriptor app icon as an .icns: a black squircle on Apple's
// macOS icon grid (824/1024 tile, 100 px margin) with a glowing gradient
// waveform. Run from the repo root: swift scripts/generate_app_icon.swift

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
    NSGradient(colors: [rgb(0x1E1E21), rgb(0x050506)])!.draw(in: tilePath, angle: -90)
    NSShadow().set()

    // Faint violet glow behind the waveform gives the black tile depth.
    NSGraphicsContext.saveGraphicsState()
    tilePath.addClip()
    NSGradient(colors: [
        rgb(0x7A4DFF).withAlphaComponent(0.28),
        rgb(0x7A4DFF).withAlphaComponent(0.0),
    ])!.draw(
        fromCenter: NSPoint(x: tileRect.midX, y: tileRect.midY), radius: 0,
        toCenter: NSPoint(x: tileRect.midX, y: tileRect.midY), radius: tileRect.width * 0.55,
        options: []
    )
    NSGraphicsContext.restoreGraphicsState()

    // Glass edge: brightest on top, like Apple's dark icons.
    NSGraphicsContext.saveGraphicsState()
    let rim = NSBezierPath(roundedRect: tileRect.insetBy(dx: canvas * 0.002, dy: canvas * 0.002), xRadius: radius, yRadius: radius)
    rim.lineWidth = max(1, canvas * 0.004)
    rim.setClip()
    let rimOutline = NSBezierPath(cgPath: rim.cgPath.copy(strokingWithWidth: rim.lineWidth, lineCap: .butt, lineJoin: .round, miterLimit: 10))
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.30), NSColor.white.withAlphaComponent(0.06)])!
        .draw(in: rimOutline, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Waveform: rounded bars with a cyan → blue → violet → pink gradient.
    let heights: [CGFloat] = [0.20, 0.42, 0.70, 0.52, 0.95, 0.62, 0.80, 0.40, 0.20]
    let barWidth = tileRect.width * 0.062
    let gap = tileRect.width * 0.040
    let totalWidth = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
    let maxHeight = tileRect.height * 0.58
    let bars = NSBezierPath()
    for (index, h) in heights.enumerated() {
        let height = max(barWidth, maxHeight * h)
        let rect = NSRect(
            x: tileRect.midX - totalWidth / 2 + CGFloat(index) * (barWidth + gap),
            y: tileRect.midY - height / 2,
            width: barWidth,
            height: height
        )
        bars.append(NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2))
    }
    let colors = [rgb(0x4FD1FF), rgb(0x3D7BFF), rgb(0x9B5CFF), rgb(0xFF4F9A)]

    let glow = NSShadow()
    glow.shadowColor = rgb(0x8A5CFF).withAlphaComponent(0.75)
    glow.shadowBlurRadius = canvas * 0.045
    glow.shadowOffset = .zero
    NSGraphicsContext.saveGraphicsState()
    glow.set()
    rgb(0x6A5CFF).setFill()
    bars.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: colors)!.draw(in: bars, angle: 0)

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
