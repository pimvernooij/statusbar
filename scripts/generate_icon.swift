#!/usr/bin/swift
import AppKit
import CoreGraphics

func createIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus()
        return img
    }
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // --- Background: rounded rect with gradient ---
    let margin = s * 0.08
    let radius = s * 0.22
    let bgRect = CGRect(x: margin, y: margin, width: s - margin * 2, height: s - margin * 2)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        CGColor(red: 0.10, green: 0.55, blue: 0.92, alpha: 1.0),  // top: bright blue
        CGColor(red: 0.12, green: 0.42, blue: 0.78, alpha: 1.0),  // bottom: deeper blue
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: s / 2, y: s - margin),
                           end: CGPoint(x: s / 2, y: margin),
                           options: [])
    ctx.restoreGState()

    // --- Cloud shape using bezier path ---
    let cx = s * 0.50
    let cy = s * 0.52  // slightly above center (flipped coords: y=0 is bottom)
    let cloudScale = s * 0.42

    func cloudPath(offsetX: CGFloat = 0, offsetY: CGFloat = 0) -> CGPath {
        let path = CGMutablePath()
        // Build cloud from overlapping circles
        let circles: [(CGFloat, CGFloat, CGFloat)] = [
            // (x_offset, y_offset, radius) relative to cloud center
            (-0.42, -0.08, 0.32),   // left bump
            (-0.10,  0.30, 0.38),   // top-left bump
            ( 0.25,  0.35, 0.36),   // top-right bump (tallest)
            ( 0.52,  0.05, 0.28),   // right bump
            ( 0.05, -0.18, 0.50),   // bottom wide fill
        ]
        for (ox, oy, r) in circles {
            let x = cx + ox * cloudScale + offsetX
            let y = cy + oy * cloudScale + offsetY
            let cr = r * cloudScale
            path.addEllipse(in: CGRect(x: x - cr, y: y - cr, width: cr * 2, height: cr * 2))
        }
        return path
    }

    // Cloud shadow
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    ctx.setFillColor(CGColor(red: 0.04, green: 0.20, blue: 0.55, alpha: 0.30))
    ctx.addPath(cloudPath(offsetX: s * 0.008, offsetY: -s * 0.025))
    ctx.fillPath()
    ctx.restoreGState()

    // Main cloud (white)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95))
    ctx.addPath(cloudPath())
    ctx.fillPath()
    ctx.restoreGState()

    // --- Pulse/heartbeat line ---
    let pulseY = cy - s * 0.02
    let pulsePoints: [(CGFloat, CGFloat)] = [
        (-0.38,  0.00),
        (-0.18,  0.00),
        (-0.12, -0.10),
        (-0.06,  0.16),
        ( 0.01, -0.22),
        ( 0.08,  0.14),
        ( 0.14, -0.06),
        ( 0.20,  0.00),
        ( 0.40,  0.00),
    ]

    let pulsePath = CGMutablePath()
    for (i, (px, py)) in pulsePoints.enumerated() {
        let x = cx + px * cloudScale * 2.0
        let y = pulseY + py * cloudScale * 1.3
        if i == 0 {
            pulsePath.move(to: CGPoint(x: x, y: y))
        } else {
            pulsePath.addLine(to: CGPoint(x: x, y: y))
        }
    }

    // Pulse shadow
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let shadowTransform = CGAffineTransform(translationX: s * 0.004, y: -s * 0.012)
    if let shadowPulse = pulsePath.copy(using: [shadowTransform]) {
        ctx.addPath(shadowPulse)
        ctx.setStrokeColor(CGColor(red: 0.04, green: 0.20, blue: 0.55, alpha: 0.25))
        ctx.setLineWidth(s * 0.045)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.strokePath()
    }
    ctx.restoreGState()

    // Main pulse line (green)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    ctx.addPath(pulsePath)
    ctx.setStrokeColor(CGColor(red: 0.18, green: 0.80, blue: 0.35, alpha: 1.0))
    ctx.setLineWidth(s * 0.04)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()
    ctx.restoreGState()

    img.unlockFocus()
    return img
}

func savePNG(_ image: NSImage, to path: String, pixelSize: Int) {
    let size = NSSize(width: pixelSize, height: pixelSize)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = size

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(origin: .zero, size: size),
               from: NSRect(origin: .zero, size: image.size),
               operation: .copy,
               fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()

    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}

// --- Main ---
let iconDir = "StatusBar/Assets.xcassets/AppIcon.appiconset"

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

// Render at high res and scale down for best quality
let masterSize = 1024
let master = createIcon(size: masterSize)

for (filename, px) in sizes {
    let path = "\(iconDir)/\(filename)"
    savePNG(master, to: path, pixelSize: px)
    print("  \(filename) (\(px)x\(px))")
}
print("Done!")
