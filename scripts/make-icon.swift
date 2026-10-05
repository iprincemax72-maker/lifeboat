// renders Resources/AppIcon.icns. run from the repo root: swift scripts/make-icon.swift
import AppKit

func rgb(_ hex: Int) -> CGColor {
    CGColor(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func draw(_ ctx: CGContext) {
    // big sur grid: an 824pt rounded square on a 1024 canvas
    let tile = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.3))
    ctx.addPath(tile)
    ctx.setFillColor(rgb(0x0B3A66))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tile)
    ctx.clip()
    let sea = CGGradient(colorsSpace: nil, colors: [rgb(0x3FB0E8), rgb(0x0B3A66)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(sea, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    let c = CGPoint(x: 512, y: 512)
    let outer: CGFloat = 290
    let inner: CGFloat = 150

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: CGColor(gray: 0, alpha: 0.35))
    ctx.addEllipse(in: CGRect(x: c.x - outer, y: c.y - outer, width: outer * 2, height: outer * 2))
    ctx.addEllipse(in: CGRect(x: c.x - inner, y: c.y - inner, width: inner * 2, height: inner * 2))
    ctx.setFillColor(rgb(0xFBF8F3))
    ctx.fillPath(using: .evenOdd)
    ctx.restoreGState()

    ctx.setFillColor(rgb(0xE5483B))
    for i in 0..<4 {
        let mid = CGFloat(i) * .pi / 2 + .pi / 4
        let band = CGMutablePath()
        band.addArc(center: c, radius: outer, startAngle: mid - .pi / 8, endAngle: mid + .pi / 8, clockwise: false)
        band.addArc(center: c, radius: inner, startAngle: mid + .pi / 8, endAngle: mid - .pi / 8, clockwise: true)
        band.closeSubpath()
        ctx.addPath(band)
        ctx.fillPath()
    }
    ctx.restoreGState()
}

func png(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    gc.cgContext.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)
    draw(gc.cgContext)
    gc.flushGraphics()
    return rep.representation(using: .png, properties: [:])!
}

let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: dir)
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for pt in [16, 32, 128, 256, 512] {
    try png(pt).write(to: dir.appendingPathComponent("icon_\(pt)x\(pt).png"))
    try png(pt * 2).write(to: dir.appendingPathComponent("icon_\(pt)x\(pt)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", dir.path, "-o", "Resources/AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()
