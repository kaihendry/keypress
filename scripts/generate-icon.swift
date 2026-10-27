#!/usr/bin/env swift
import AppKit

// Original vector artwork. Render each icon size directly for crisp small-size edges.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources")
let iconset = root.appendingPathComponent("build/Keypress.iconset")
try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

func rounded(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func fill(_ path: NSBezierPath, _ shade: NSColor) {
    shade.setFill()
    path.fill()
}

func gradient(_ path: NSBezierPath, from: UInt32, to: UInt32, angle: CGFloat = 90) {
    NSGradient(starting: color(from), ending: color(to))!.draw(in: path, angle: angle)
}

func shadow(blur: CGFloat, offset: CGSize, opacity: CGFloat, draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = offset
    shadow.shadowColor = color(0x071B45, alpha: opacity)
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

func artwork() {
    let tile = rounded(CGRect(x: 96, y: 96, width: 832, height: 832), radius: 188)
    shadow(blur: 22, offset: CGSize(width: 0, height: -12), opacity: 0.28) {
        fill(tile, color(0x1855BB))
    }
    gradient(tile, from: 0x153D91, to: 0x3388F3, angle: 70)

    // A quiet rim and reflected light give the tile depth without adding detail.
    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    let glow = NSBezierPath(ovalIn: CGRect(x: -60, y: 590, width: 900, height: 620))
    fill(glow, color(0x8FDDFF, alpha: 0.08))
    NSGraphicsContext.restoreGraphicsState()
    color(0xFFFFFF, alpha: 0.16).setStroke()
    tile.lineWidth = 3
    tile.stroke()

    // The lower edge is the keycap's bevel, not a second key.
    let base = rounded(CGRect(x: 232, y: 218, width: 560, height: 560), radius: 118)
    shadow(blur: 38, offset: CGSize(width: 0, height: -25), opacity: 0.36) {
        fill(base, color(0xB4D1EF))
    }
    gradient(base, from: 0xA5C3E8, to: 0xE5F1FF)
    let face = rounded(CGRect(x: 232, y: 260, width: 560, height: 526), radius: 118)
    gradient(face, from: 0xE5F0FF, to: 0xFFFFFF)
    color(0xFFFFFF, alpha: 0.85).setStroke()
    face.lineWidth = 3
    face.stroke()

    let ink = color(0x205BB9)
    // Crown and shoulder button; all details remain legible at Finder sizes.
    fill(rounded(CGRect(x: 480, y: 696, width: 64, height: 30), radius: 10), ink)
    fill(rounded(CGRect(x: 499, y: 666, width: 26, height: 40), radius: 6), ink)
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: 639, yBy: 636)
    transform.rotate(byDegrees: -42)
    transform.concat()
    fill(rounded(CGRect(x: -19, y: -5, width: 38, height: 30), radius: 8), ink)
    NSGraphicsContext.restoreGraphicsState()

    let dial = NSBezierPath(ovalIn: CGRect(x: 359, y: 365, width: 306, height: 306))
    ink.setStroke()
    dial.lineWidth = 32
    dial.stroke()

    let hand = NSBezierPath()
    hand.move(to: CGPoint(x: 512, y: 609))
    hand.line(to: CGPoint(x: 512, y: 518))
    hand.line(to: CGPoint(x: 571, y: 484))
    hand.lineWidth = 28
    hand.lineCapStyle = .round
    hand.lineJoinStyle = .round
    ink.setStroke()
    hand.stroke()
    fill(NSBezierPath(ovalIn: CGRect(x: 495, y: 501, width: 34, height: 34)), ink)
}

func render(size: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB,
                                  bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    artwork()
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        let name = "icon_\(points)x\(points)\(suffix).png"
        try render(size: points * scale).write(to: iconset.appendingPathComponent(name))
    }
}
try render(size: 1024).write(to: resources.appendingPathComponent("AppIcon.png"))
print("Rendered Keypress icon and macOS icon sizes")
