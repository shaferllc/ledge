#!/usr/bin/env swift
// Generates AppIcon.icns for Ledge — a dark rounded tile with a bright notch
// hanging from the top edge and a small dashboard dot row below it.
import AppKit

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext

    let rect = NSRect(x: 0, y: 0, width: size, height: size)

    // Rounded-tile background gradient.
    let corner = size * 0.22
    let tile = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.04, dy: size * 0.04),
                            xRadius: corner, yRadius: corner)
    tile.addClip()
    let grad = NSGradient(colors: [
        NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.16, alpha: 1),
        NSColor(calibratedRed: 0.03, green: 0.03, blue: 0.05, alpha: 1),
    ])!
    grad.draw(in: rect, angle: -90)

    // The notch: a black rounded shape hanging from the top, with concave wings.
    let w = size * 0.46
    let h = size * 0.16
    let top = rect.maxY - size * 0.10
    let left = rect.midX - w / 2
    let wing = size * 0.05
    let br = size * 0.045

    let notch = NSBezierPath()
    notch.move(to: NSPoint(x: left - wing, y: top))
    notch.curve(to: NSPoint(x: left, y: top - wing),
                controlPoint1: NSPoint(x: left, y: top),
                controlPoint2: NSPoint(x: left, y: top - wing))
    notch.line(to: NSPoint(x: left, y: top - h + br))
    notch.curve(to: NSPoint(x: left + br, y: top - h),
                controlPoint1: NSPoint(x: left, y: top - h),
                controlPoint2: NSPoint(x: left, y: top - h))
    notch.line(to: NSPoint(x: left + w - br, y: top - h))
    notch.curve(to: NSPoint(x: left + w, y: top - h + br),
                controlPoint1: NSPoint(x: left + w, y: top - h),
                controlPoint2: NSPoint(x: left + w, y: top - h))
    notch.line(to: NSPoint(x: left + w, y: top - wing))
    notch.curve(to: NSPoint(x: left + w + wing, y: top),
                controlPoint1: NSPoint(x: left + w, y: top - wing),
                controlPoint2: NSPoint(x: left + w, y: top))
    notch.close()
    NSColor.black.setFill()
    notch.fill()

    // Accent dot row (dashboard slots) inside the notch.
    let dotColors = [
        NSColor(calibratedRed: 0.36, green: 0.78, blue: 0.98, alpha: 1),
        NSColor(calibratedRed: 0.66, green: 0.55, blue: 0.98, alpha: 1),
        NSColor(calibratedRed: 0.98, green: 0.66, blue: 0.40, alpha: 1),
    ]
    let dotR = size * 0.028
    let spacing = size * 0.085
    let cy = top - h * 0.5
    let startX = rect.midX - spacing
    for (i, color) in dotColors.enumerated() {
        color.setFill()
        let dx = startX + CGFloat(i) * spacing
        NSBezierPath(ovalIn: NSRect(x: dx - dotR, y: cy - dotR,
                                    width: dotR * 2, height: dotR * 2)).fill()
    }

    _ = ctx
    image.unlockFocus()
    return image
}

func png(_ image: NSImage, _ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = "AppIcon.iconset"
try? fm.removeItem(atPath: iconset)
try! fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let specs: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in specs {
    let img = drawIcon(size: CGFloat(px))
    try! png(img, px).write(to: URL(fileURLWithPath: "\(iconset)/\(name).png"))
}

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset, "-o", "AppIcon.icns"]
try! p.run()
p.waitUntilExit()
print("Wrote AppIcon.icns")
