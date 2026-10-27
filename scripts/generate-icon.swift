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
        fill(tile, color(0x302358))
    }
    gradient(tile, from: 0x282041, to: 0x675597, angle: 75)
    color(0xFFFFFF, alpha: 0.14).setStroke()
    tile.lineWidth = 3
    tile.stroke()

    // A single depressed key grounds the hand in a physical input action.
    let base = rounded(CGRect(x: 224, y: 239, width: 423, height: 179), radius: 50)
    shadow(blur: 30, offset: CGSize(width: 0, height: -20), opacity: 0.36) {
        fill(base, color(0xA59ABD))
    }
    gradient(base, from: 0x9F92B7, to: 0xDBD4E9)
    let face = rounded(CGRect(x: 224, y: 295, width: 423, height: 139), radius: 46)
    gradient(face, from: 0xDCD6EC, to: 0xFFFFFF)
    color(0xFFFFFF, alpha: 0.65).setStroke()
    face.lineWidth = 3
    face.stroke()

    // Contact and pressure: warm accents rather than a time or productivity symbol.
    let contact = NSBezierPath(ovalIn: CGRect(x: 382, y: 400, width: 148, height: 36))
    fill(contact, color(0xF08768, alpha: 0.65))

    // Side profile: the index finger bends down onto the key, the other fingers curl
    // into the palm, and a short wrist enters from the right.
    let hand = NSBezierPath()
    hand.move(to: CGPoint(x: 812, y: 617))
    hand.curve(to: CGPoint(x: 651, y: 727), controlPoint1: CGPoint(x: 748, y: 684), controlPoint2: CGPoint(x: 707, y: 726))
    hand.curve(to: CGPoint(x: 514, y: 753), controlPoint1: CGPoint(x: 618, y: 751), controlPoint2: CGPoint(x: 561, y: 757))
    hand.curve(to: CGPoint(x: 421, y: 676), controlPoint1: CGPoint(x: 465, y: 754), controlPoint2: CGPoint(x: 424, y: 724))
    hand.line(to: CGPoint(x: 402, y: 482))
    hand.curve(to: CGPoint(x: 455, y: 426), controlPoint1: CGPoint(x: 397, y: 446), controlPoint2: CGPoint(x: 421, y: 426))
    hand.curve(to: CGPoint(x: 513, y: 482), controlPoint1: CGPoint(x: 490, y: 426), controlPoint2: CGPoint(x: 512, y: 448))
    hand.line(to: CGPoint(x: 524, y: 605))
    hand.curve(to: CGPoint(x: 595, y: 555), controlPoint1: CGPoint(x: 551, y: 585), controlPoint2: CGPoint(x: 573, y: 570))
    hand.curve(to: CGPoint(x: 634, y: 453), controlPoint1: CGPoint(x: 621, y: 526), controlPoint2: CGPoint(x: 605, y: 482))
    hand.curve(to: CGPoint(x: 694, y: 427), controlPoint1: CGPoint(x: 652, y: 428), controlPoint2: CGPoint(x: 677, y: 419))
    hand.curve(to: CGPoint(x: 812, y: 463), controlPoint1: CGPoint(x: 739, y: 432), controlPoint2: CGPoint(x: 781, y: 451))
    hand.close()
    shadow(blur: 22, offset: CGSize(width: 0, height: -13), opacity: 0.28) {
        fill(hand, color(0xF8CAA6))
    }
    gradient(hand, from: 0xE9AA85, to: 0xFFE1BD, angle: 100)
    color(0xFFE6CC, alpha: 0.5).setStroke()
    hand.lineWidth = 3
    hand.stroke()

    let nail = rounded(CGRect(x: 424, y: 459, width: 66, height: 58), radius: 23)
    gradient(nail, from: 0xF4C7AF, to: 0xFFE7D0)

    // Two folds distinguish the curled fingers from a cursor or mechanical arm.
    let folds = NSBezierPath()
    folds.move(to: CGPoint(x: 605, y: 553))
    folds.curve(to: CGPoint(x: 675, y: 512), controlPoint1: CGPoint(x: 632, y: 545), controlPoint2: CGPoint(x: 657, y: 532))
    folds.move(to: CGPoint(x: 631, y: 491))
    folds.curve(to: CGPoint(x: 690, y: 474), controlPoint1: CGPoint(x: 649, y: 484), controlPoint2: CGPoint(x: 670, y: 478))
    folds.lineWidth = 11
    folds.lineCapStyle = .round
    color(0xB76E52, alpha: 0.6).setStroke()
    folds.stroke()

    // A cuff gives the silhouette a clear human wrist and a clean termination.
    let cuff = rounded(CGRect(x: 770, y: 444, width: 69, height: 204), radius: 22)
    gradient(cuff, from: 0xBDB0D9, to: 0xEEE6FF)

    let pressure = NSBezierPath()
    for (start, end) in [
        (CGPoint(x: 347, y: 465), CGPoint(x: 305, y: 478)),
        (CGPoint(x: 355, y: 529), CGPoint(x: 325, y: 558)),
        (CGPoint(x: 550, y: 455), CGPoint(x: 581, y: 477))
    ] {
        pressure.move(to: start)
        pressure.line(to: end)
    }
    pressure.lineWidth = 19
    pressure.lineCapStyle = .round
    color(0xFFA477).setStroke()
    pressure.stroke()
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
