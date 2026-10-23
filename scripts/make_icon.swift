import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Renders the Danish Vocab app icon: a fanned stack of flashcards, the front one
// printed with the Dannebrog, a gold star for the game side, on a Nordic night sky.

let size = 1024
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
// No alpha channel: App Store icons must be opaque.
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// Work in top-left origin coordinates.
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)

let s = CGFloat(size)

// MARK: Background
let bg = CGGradient(colorsSpace: space, colors: [rgb(0x1E3F73), rgb(0x0B1A33)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: 0), end: CGPoint(x: s, y: s), options: [])
let glow = CGGradient(colorsSpace: space, colors: [rgb(0x5B8BD9, 0.45), rgb(0x5B8BD9, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: s * 0.5, y: s * 0.45), startRadius: 0,
                       endCenter: CGPoint(x: s * 0.5, y: s * 0.45), endRadius: s * 0.62, options: [])

// A few stars in the night sky.
for (x, y, r, a) in [(0.14, 0.13, 7.0, 0.9), (0.27, 0.07, 4.0, 0.6), (0.09, 0.34, 4.5, 0.5),
                     (0.88, 0.86, 6.0, 0.7), (0.72, 0.93, 4.0, 0.5), (0.93, 0.62, 4.0, 0.45),
                     (0.06, 0.82, 5.0, 0.55), (0.36, 0.92, 3.5, 0.4)] {
    ctx.setFillColor(rgb(0xFFFFFF, a))
    ctx.fillEllipse(in: CGRect(x: s * x - r, y: s * y - r, width: r * 2, height: r * 2))
}

// MARK: Cards
let cardSize = CGSize(width: 600, height: 440)
let cardCenter = CGPoint(x: s * 0.49, y: s * 0.55)

func withCard(rotation degrees: CGFloat, offset: CGPoint, _ draw: (CGRect) -> Void) {
    ctx.saveGState()
    ctx.translateBy(x: cardCenter.x + offset.x, y: cardCenter.y + offset.y)
    ctx.rotate(by: degrees * .pi / 180)
    draw(CGRect(x: -cardSize.width / 2, y: -cardSize.height / 2, width: cardSize.width, height: cardSize.height))
    ctx.restoreGState()
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func paperCard(_ rect: CGRect, color: CGColor) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 22), blur: 46, color: rgb(0x000000, 0.45))
    ctx.addPath(roundedRect(rect, 52))
    ctx.setFillColor(color)
    ctx.fillPath()
    ctx.restoreGState()
}

// Two cards fanned out behind.
withCard(rotation: 16, offset: CGPoint(x: 58, y: -52)) { paperCard($0, color: rgb(0xC9D6EA)) }
withCard(rotation: 6, offset: CGPoint(x: 28, y: -26)) { paperCard($0, color: rgb(0xE6EDF7)) }

// Front card with the Dannebrog printed on it.
withCard(rotation: -7, offset: .zero) { rect in
    paperCard(rect, color: rgb(0xFFFFFF))

    let inset: CGFloat = 30
    let flag = rect.insetBy(dx: inset, dy: inset)
    ctx.saveGState()
    ctx.addPath(roundedRect(flag, 30))
    ctx.clip()

    // Red field with a subtle sheen.
    let red = CGGradient(colorsSpace: space, colors: [rgb(0xE0213F), rgb(0xB30C27)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(red, start: CGPoint(x: flag.minX, y: flag.minY), end: CGPoint(x: flag.maxX, y: flag.maxY), options: [])

    // Official proportions: 12-4-21 across, 12-4-12 down.
    let unitX = flag.width / 37, unitY = flag.height / 28
    ctx.setFillColor(rgb(0xFFFFFF))
    // Bars overshoot the clip so no red hairline shows at their ends.
    ctx.fill(CGRect(x: flag.minX + 12 * unitX, y: flag.minY - 10, width: 4 * unitX, height: flag.height + 20))
    ctx.fill(CGRect(x: flag.minX - 10, y: flag.minY + 12 * unitY, width: flag.width + 20, height: 4 * unitY))

    // Soft fabric-like highlight across the flag.
    let sheen = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 0.0), rgb(0xFFFFFF, 0.18), rgb(0xFFFFFF, 0.0)] as CFArray,
                           locations: [0.25, 0.5, 0.75])!
    ctx.drawLinearGradient(sheen, start: CGPoint(x: flag.minX, y: flag.maxY), end: CGPoint(x: flag.maxX, y: flag.minY), options: [])
    ctx.restoreGState()
}

// MARK: Gold star
func starPath(center: CGPoint, outer: CGFloat, inner: CGFloat, points: Int, rotation: CGFloat) -> CGPath {
    let path = CGMutablePath()
    for i in 0..<(points * 2) {
        let radius = i.isMultiple(of: 2) ? outer : inner
        let angle = rotation + CGFloat(i) * .pi / CGFloat(points) - .pi / 2
        let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
        i == 0 ? path.move(to: point) : path.addLine(to: point)
    }
    path.closeSubpath()
    return path
}

let starCenter = CGPoint(x: s * 0.79, y: s * 0.27)
let star = starPath(center: starCenter, outer: 128, inner: 58, points: 5, rotation: 0.22)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 14), blur: 30, color: rgb(0x000000, 0.45))
ctx.addPath(star)
ctx.setFillColor(rgb(0xFFC21A))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(star)
ctx.clip()
let gold = CGGradient(colorsSpace: space, colors: [rgb(0xFFE680), rgb(0xFFB300)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gold, start: CGPoint(x: starCenter.x, y: starCenter.y - 128),
                       end: CGPoint(x: starCenter.x, y: starCenter.y + 128), options: [])
ctx.restoreGState()

ctx.addPath(star)
ctx.setStrokeColor(rgb(0xFFFFFF))
ctx.setLineWidth(12)
ctx.setLineJoin(.round)
ctx.strokePath()

// Little sparkles next to the star.
ctx.setFillColor(rgb(0xFFFFFF))
for (point, radius) in [(CGPoint(x: s * 0.94, y: s * 0.12), 34.0), (CGPoint(x: s * 0.62, y: s * 0.11), 22.0)] {
    ctx.addPath(starPath(center: point, outer: radius, inner: radius * 0.28, points: 4, rotation: 0))
    ctx.fillPath()
}

// MARK: Write PNG
let image = ctx.makeImage()!
let url = URL(fileURLWithPath: outPath)
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("Could not write \(outPath)") }
print("Wrote \(outPath)")
