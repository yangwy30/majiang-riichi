// Draws the three 1024 px app icons: a compass diamond crossed by a 1,000-point riichi stick.
// Run from app/: swift tools/make_app_icon.swift
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func draw(background: CGColor, diamond: CGColor, stick: CGColor, dot: CGColor, to name: String) {
    let size = 1024
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let center = CGPoint(x: 512, y: 512)
    ctx.setFillColor(background)
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

    // The compass diamond, same motif as the table screen.
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: .pi / 4)
    let side: CGFloat = 500
    ctx.setStrokeColor(diamond)
    ctx.setLineWidth(30)
    ctx.addPath(CGPath(roundedRect: CGRect(x: -side / 2, y: -side / 2, width: side, height: side),
                       cornerWidth: 44, cornerHeight: 44, transform: nil))
    ctx.strokePath()
    ctx.restoreGState()

    // The stick lies across the diamond, leaving a gap in the outline at both tips.
    let width: CGFloat = 780, height: CGFloat = 112
    let rect = CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    ctx.setStrokeColor(background)
    ctx.setLineWidth(44)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: height / 2, cornerHeight: height / 2, transform: nil))
    ctx.strokePath()
    ctx.setFillColor(stick)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: height / 2, cornerHeight: height / 2, transform: nil))
    ctx.fillPath()
    ctx.setFillColor(dot)
    ctx.fillEllipse(in: CGRect(x: center.x - 38, y: center.y - 38, width: 76, height: 76))

    let url = URL(fileURLWithPath: "MajiangApp/Resources/Assets.xcassets/AppIcon.appiconset/\(name).png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}

draw(background: color(0x23395B), diamond: color(0x8FA3C2), stick: color(0xF6F1E7), dot: color(0xC8402A), to: "AppIcon")
draw(background: color(0x10151F), diamond: color(0x3B5B8F), stick: color(0xECE6D9), dot: color(0xD9543C), to: "AppIcon-dark")
draw(background: color(0x000000), diamond: color(0x777777), stick: color(0xFFFFFF), dot: color(0x000000), to: "AppIcon-tinted")
