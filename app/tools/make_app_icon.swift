// Draws the three 1024 px app icons: an ivory East wind tile lying on green felt.
// Run from app/: swift tools/make_app_icon.swift
import AppKit
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

struct Palette {
    var felt: [UInt32]
    var face: UInt32
    var back: UInt32
    var glyph: UInt32
}

func draw(_ p: Palette, to name: String) {
    let size = 1024
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    // Felt: brighter in the middle, darker at the edges.
    let felt = CGGradient(colorsSpace: space, colors: p.felt.map { color($0) } as CFArray, locations: [0, 0.6, 1])!
    ctx.drawRadialGradient(felt, startCenter: CGPoint(x: 512, y: 560), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 512), endRadius: 760, options: [.drawsAfterEndLocation])
    // Fine felt grain.
    var seed: UInt64 = 7
    func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(seed >> 33) / CGFloat(UInt64(1) << 31) }
    for _ in 0..<26000 {
        ctx.setFillColor(color(0xFFFFFF, 0.04 + rnd() * 0.05))
        ctx.fill(CGRect(x: rnd() * 1024, y: rnd() * 1024, width: 1.6, height: 1.6))
    }
    // The tile: ivory face with the yellow back showing along the bottom, soft shadow on the felt.
    let tile = CGRect(x: 512 - 230, y: 512 - 300, width: 460, height: 600)
    let radius: CGFloat = 70
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -26), blur: 50, color: color(0x000000, 0.45))
    ctx.setFillColor(color(p.back))
    ctx.addPath(CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.fillPath()
    ctx.restoreGState()
    let face = CGRect(x: tile.minX, y: tile.minY + 120, width: tile.width, height: tile.height - 120)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: tile, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.clip()
    ctx.setFillColor(color(p.face))
    ctx.fill(face)
    ctx.setFillColor(color(0x000000, 0.12))
    ctx.fill(CGRect(x: tile.minX, y: face.minY - 4, width: tile.width, height: 8))
    ctx.restoreGState()
    // 東 in a heavy Mincho, centred on the face.
    let font = CTFontCreateWithName("HiraMinProN-W6" as CFString, 330, nil)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(cgColor: color(p.glyph))!]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "東", attributes: attrs))
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    ctx.textPosition = CGPoint(x: face.midX - bounds.midX, y: face.midY - bounds.midY)
    CTLineDraw(line, ctx)

    let url = URL(fileURLWithPath: "MajiangApp/Resources/Assets.xcassets/AppIcon.appiconset/\(name).png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}

draw(Palette(felt: [0x3A8763, 0x215A40, 0x153A2A], face: 0xF9F6EC, back: 0xE7A33A, glyph: 0x1B1F1D), to: "AppIcon")
draw(Palette(felt: [0x1F4D38, 0x123224, 0x0A1D15], face: 0xEDE8DA, back: 0xC9852A, glyph: 0x1B1F1D), to: "AppIcon-dark")
draw(Palette(felt: [0x3A3A3A, 0x1E1E1E, 0x0A0A0A], face: 0xFFFFFF, back: 0x9A9A9A, glyph: 0x000000), to: "AppIcon-tinted")
