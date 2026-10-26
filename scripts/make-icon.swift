// Renders the Consta app icon (the menu bar glyph in ink on a pale glass squircle) into an .icns.
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
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 20
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    // Pale glass: near-white at the top, a cool grey at the bottom.
    NSGradient(colors: [
        NSColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1),
        NSColor(red: 0.90, green: 0.91, blue: 0.93, alpha: 1),
    ])!.draw(in: tile, angle: -90)

    // The menu bar glyph, drawn on its 16pt grid and scaled up: three stars joined by two lines.
    let ink = NSColor(red: 0x1d / 255, green: 0x1d / 255, blue: 0x1f / 255, alpha: 1)
    let grid: CGFloat = 38
    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: 512 + (x - 8) * grid, y: 512 - (y - 7.5) * grid)
    }
    let stars = [point(3, 11), point(8, 4), point(13, 9)]
    let radius = 1.6 * grid
    let glyph = NSBezierPath()
    for star in stars {
        glyph.appendOval(in: CGRect(x: star.x - radius, y: star.y - radius, width: radius * 2, height: radius * 2))
    }
    for (from, to) in zip(stars, stars.dropFirst()) {
        let dx = to.x - from.x, dy = to.y - from.y
        let trim = radius / hypot(dx, dy)
        glyph.move(to: CGPoint(x: from.x + dx * trim, y: from.y + dy * trim))
        glyph.line(to: CGPoint(x: to.x - dx * trim, y: to.y - dy * trim))
    }
    glyph.lineWidth = grid
    glyph.lineCapStyle = .round
    ink.setStroke()
    glyph.stroke()
    NSGraphicsContext.restoreGraphicsState()

    // A hairline edge and a bright inner rim, like glass.
    NSColor.black.withAlphaComponent(0.08).setStroke()
    let edge = NSBezierPath(roundedRect: tile.insetBy(dx: 1, dy: 1), xRadius: 184, yRadius: 184)
    edge.lineWidth = 2
    edge.stroke()
    NSColor.white.withAlphaComponent(0.9).setStroke()
    let rim = NSBezierPath(roundedRect: tile.insetBy(dx: 4, dy: 4), xRadius: 181, yRadius: 181)
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
