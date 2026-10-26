// Renders the Consta app icon (a small constellation on a night-sky squircle) into an .icns.
//
//     swift scripts/make-icon.swift OUTPUT.icns
//
// The icon is drawn in code so no image files live in the repo.
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns")

func render(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    // Draw on Apple's 1024pt icon grid: an 824pt rounded square centered in the canvas.
    let scale = CGFloat(pixels) / 1024
    ctx.scaleBy(x: scale, y: scale)

    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = 20
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSGradient(colors: [
        NSColor(red: 0.36, green: 0.30, blue: 0.95, alpha: 1),
        NSColor(red: 0.12, green: 0.10, blue: 0.38, alpha: 1),
        NSColor(red: 0.05, green: 0.05, blue: 0.16, alpha: 1),
    ])!.draw(in: tile, angle: -70)
    // Soft glow behind the constellation.
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.18), NSColor.white.withAlphaComponent(0)])!
        .draw(fromCenter: NSPoint(x: 560, y: 600), radius: 0, toCenter: NSPoint(x: 560, y: 600), radius: 420, options: [])

    // Faint background stars.
    let dust: [(CGFloat, CGFloat, CGFloat)] = [
        (210, 790, 5), (330, 860, 3.5), (820, 830, 4), (760, 260, 3.5), (250, 300, 4),
        (880, 560, 3), (420, 210, 3), (180, 560, 3), (650, 870, 3),
    ]
    NSColor.white.withAlphaComponent(0.45).setFill()
    for (x, y, r) in dust { NSBezierPath(ovalIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)).fill() }

    // The constellation, echoing the menu bar glyph.
    let stars: [CGPoint] = [
        CGPoint(x: 290, y: 390), CGPoint(x: 450, y: 640), CGPoint(x: 640, y: 520),
        CGPoint(x: 760, y: 740), CGPoint(x: 700, y: 330),
    ]
    let lines = NSBezierPath()
    lines.move(to: stars[0])
    for star in stars.dropFirst() { lines.line(to: star) }
    lines.move(to: stars[2])
    lines.line(to: stars[4])
    lines.lineWidth = 14
    lines.lineCapStyle = .round
    lines.lineJoinStyle = .round
    NSColor.white.withAlphaComponent(0.55).setStroke()
    lines.stroke()

    for (index, star) in stars.enumerated() {
        let radius: CGFloat = index == 1 ? 50 : 36
        NSGradient(colors: [NSColor.white.withAlphaComponent(0.55), NSColor.white.withAlphaComponent(0)])!
            .draw(fromCenter: star, radius: 0, toCenter: star, radius: radius * 2.6, options: [])
        NSColor.white.setFill()
        NSBezierPath(ovalIn: CGRect(x: star.x - radius, y: star.y - radius, width: radius * 2, height: radius * 2)).fill()
    }
    NSGraphicsContext.restoreGraphicsState()

    // Thin highlight on the rim, like glass.
    NSColor.white.withAlphaComponent(0.22).setStroke()
    let rim = NSBezierPath(roundedRect: tile.insetBy(dx: 2, dy: 2), xRadius: 183, yRadius: 183)
    rim.lineWidth = 4
    rim.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let iconset = FileManager.default.temporaryDirectory.appending(path: "AppIcon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let name = factor == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        let data = render(pixels: points * factor).representation(using: .png, properties: [:])!
        try data.write(to: iconset.appending(path: name))
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
exit(iconutil.terminationStatus)
