#!/usr/bin/env swift
import AppKit

// Renders the Transcriptor app icon as an .icns. The icon mirrors the in-app
// beveled tile: a dark top-to-bottom gradient squircle with a white waveform
// glyph, set on a transparent canvas with macOS-style margins and a soft
// shadow. Run: swift Scripts/generate_app_icon.swift

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("dist/AppIcon.iconset")
let resourcesIcon = root.appendingPathComponent("Sources/Transcriptor/Resources/AppIcon.icns")

try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(
    at: resourcesIcon.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

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

    // macOS icons leave a margin around the rounded tile.
    let inset = canvas * 0.08
    let tileRect = NSRect(x: inset, y: inset, width: canvas - inset * 2, height: canvas - inset * 2)
    let radius = tileRect.width * 0.225
    let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: radius, yRadius: radius)

    // Soft drop shadow.
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.30)
    shadow.shadowBlurRadius = canvas * 0.025
    shadow.shadowOffset = NSSize(width: 0, height: -canvas * 0.012)
    shadow.set()

    // Dark vertical gradient fill.
    let gradient = NSGradient(colors: [
        NSColor(white: 0.30, alpha: 1.0),
        NSColor(white: 0.13, alpha: 1.0),
    ])!
    gradient.draw(in: tilePath, angle: -90)

    // Clear the shadow before drawing the inner stroke / glyph.
    NSShadow().set()

    // Soft top highlight stroke.
    NSColor.white.withAlphaComponent(0.18).setStroke()
    let stroke = NSBezierPath(roundedRect: tileRect.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius)
    stroke.lineWidth = max(1, canvas * 0.004)
    stroke.stroke()

    // White waveform glyph centered.
    let config = NSImage.SymbolConfiguration(pointSize: tileRect.width * 0.52, weight: .semibold)
    if let symbol = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let tinted = NSImage(size: symbol.size)
        tinted.lockFocus()
        symbol.draw(at: .zero, from: NSRect(origin: .zero, size: symbol.size), operation: .sourceOver, fraction: 1)
        NSColor.white.set()
        NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
        tinted.unlockFocus()

        let glyphRect = NSRect(
            x: tileRect.midX - tinted.size.width / 2,
            y: tileRect.midY - tinted.size.height / 2,
            width: tinted.size.width,
            height: tinted.size.height
        )
        tinted.draw(in: glyphRect, from: NSRect(origin: .zero, size: tinted.size), operation: .sourceOver, fraction: 1)
    }

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

// Convert to .icns.
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", resourcesIcon.path]
try process.run()
process.waitUntilExit()

print(process.terminationStatus == 0
    ? "Wrote \(resourcesIcon.path)"
    : "iconutil failed (\(process.terminationStatus))")
