#!/usr/bin/env swift
// Draws the app icon — a friendly AI bot on a graphite tile — and packs it as design/icon/AppIcon.icns.
//
//   swift scripts/make-app-icon.swift [design/icon]
//
// Also writes AppIcon-1024.png next to it as a preview. scripts/build-app.sh copies the .icns into the bundle, so
// run this only after changing the drawing below. Every size is drawn at its own resolution (not scaled down), and
// the 16 and 32 px images use a simpler drawing: just the face, so it stays readable.
import CoreGraphics
import Foundation
import ImageIO

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "design/icon")

// MARK: Palette (the socket hues are the app's data-type colours, MGTokens.swift)

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let tileTop = rgb(0x2C2C35), tileBottom = rgb(0x16161B), tileMid = rgb(0x202027)
let headTop = rgb(0xFFFFFF), headBottom = rgb(0xE2E6F0)
let imageBlue: UInt32 = 0x0A84FF, conditioningOrange: UInt32 = 0xFF9F0A
let ink = rgb(0x1E1E24)

// MARK: Drawing helpers. Geometry is in a 1024-unit space with the origin at the top left.

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

extension CGContext {
    /// Fills `path` with a top-to-bottom gradient over the path's own height.
    func fill(_ path: CGPath, from top: CGColor, to bottom: CGColor) {
        let box = path.boundingBoxOfPath
        let gradient = CGGradient(colorsSpace: sRGB, colors: [top, bottom] as CFArray, locations: [0, 1])!
        saveGState()
        addPath(path)
        clip()
        drawLinearGradient(
            gradient, start: CGPoint(x: box.midX, y: box.minY), end: CGPoint(x: box.midX, y: box.maxY), options: [])
        restoreGState()
    }

    func fill(_ path: CGPath, _ color: CGColor) {
        addPath(path)
        setFillColor(color)
        fillPath()
    }

    /// Runs `body` with a shadow. Shadow offsets and blur ignore the transform, hence `scale`; `dy` points down.
    func shadowed(_ color: CGColor, blur: CGFloat, dy: CGFloat = 0, scale: CGFloat, _ body: () -> Void) {
        saveGState()
        setShadow(offset: CGSize(width: 0, height: -dy * scale), blur: blur * scale, color: color)
        body()
        restoreGState()
    }
}

func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r), transform: nil)
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// A four-point spark: tips on the axes, sides pulled in to the centre.
func spark(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> CGPath {
    let k = r * 0.13
    let path = CGMutablePath()
    path.move(to: CGPoint(x: x, y: y - r))
    path.addQuadCurve(to: CGPoint(x: x + r, y: y), control: CGPoint(x: x + k, y: y - k))
    path.addQuadCurve(to: CGPoint(x: x, y: y + r), control: CGPoint(x: x + k, y: y + k))
    path.addQuadCurve(to: CGPoint(x: x - r, y: y), control: CGPoint(x: x - k, y: y + k))
    path.addQuadCurve(to: CGPoint(x: x, y: y - r), control: CGPoint(x: x - k, y: y - k))
    path.closeSubpath()
    return path
}

// MARK: The icon

enum Detail { case full, small }

func drawIcon(pixels: Int, detail: Detail) -> CGImage {
    let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let scale = CGFloat(pixels) / 1024
    context.translateBy(x: 0, y: CGFloat(pixels))
    context.scaleBy(x: scale, y: -scale)
    context.setAllowsAntialiasing(true)
    context.interpolationQuality = .high

    // Tile: the macOS icon grid's 824 pt rounded square with its soft drop shadow.
    let tile = roundedRect(CGRect(x: 100, y: 100, width: 824, height: 824), 185)
    context.shadowed(rgb(0x000000, 0.35), blur: 24, dy: 12, scale: scale) { context.fill(tile, tileMid) }
    context.fill(tile, from: tileTop, to: tileBottom)
    // A hairline of light along the top edge.
    context.saveGState()
    context.addPath(tile)
    context.clip()
    context.addPath(tile)
    context.setLineWidth(detail == .full ? 6 : 16)
    context.replacePathWithStrokedPath()
    context.clip()
    let rim = CGGradient(
        colorsSpace: sRGB, colors: [rgb(0xFFFFFF, 0.22), rgb(0xFFFFFF, 0.0)] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(rim, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 600), options: [])
    context.restoreGState()

    switch detail {
    case .full:
        let head = CGRect(x: 256, y: 408, width: 512, height: 390)
        // Antenna and its AI spark.
        context.fill(roundedRect(CGRect(x: 498, y: 336, width: 28, height: 90), 14), headTop)
        context.shadowed(rgb(0xFFFFFF, 0.55), blur: 34, scale: scale) { context.fill(spark(512, 274, 74), headTop) }
        // Head.
        let headPath = roundedRect(head, 136)
        context.shadowed(rgb(0x000000, 0.45), blur: 30, dy: 14, scale: scale) { context.fill(headPath, headTop) }
        context.fill(headPath, from: headTop, to: headBottom)
        // Ears: the graph's sockets, image blue and conditioning orange.
        for (x, hue) in [(head.minX, imageBlue), (head.maxX, conditioningOrange)] {
            context.fill(circle(x, 612, 62), tileMid)
            context.shadowed(rgb(hue, 0.7), blur: 26, scale: scale) { context.fill(circle(x, 612, 45), rgb(hue)) }
        }
        // Eyes with a highlight, and the smile.
        for x in [418.0, 606.0] as [CGFloat] {
            context.fill(circle(x, 570, 50), rgb(imageBlue))
            context.fill(circle(x - 16, 554, 15), rgb(0xFFFFFF, 0.95))
        }
        strokeSmile(context, from: CGPoint(x: 438, y: 672), to: CGPoint(x: 586, y: 672), depth: 62, width: 24)
    case .small:
        let head = roundedRect(CGRect(x: 208, y: 280, width: 608, height: 464), 160)
        context.fill(head, from: headTop, to: headBottom)
        for x in [404.0, 620.0] as [CGFloat] { context.fill(circle(x, 470, 62), rgb(imageBlue)) }
        strokeSmile(context, from: CGPoint(x: 420, y: 600), to: CGPoint(x: 604, y: 600), depth: 70, width: 44)
    }
    return context.makeImage()!
}

func strokeSmile(_ context: CGContext, from: CGPoint, to: CGPoint, depth: CGFloat, width: CGFloat) {
    context.move(to: from)
    context.addQuadCurve(to: to, control: CGPoint(x: (from.x + to.x) / 2, y: from.y + depth))
    context.setStrokeColor(ink)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.strokePath()
}

// MARK: Output

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
}

let files = FileManager.default
try files.createDirectory(at: outDir, withIntermediateDirectories: true)
// The iconset is only iconutil's input: built next to the output, removed afterwards.
let iconset = outDir.appendingPathComponent("AppIcon.iconset")
try? files.removeItem(at: iconset)
try files.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? files.removeItem(at: iconset) }

for points in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let pixels = points * factor
        let name = "icon_\(points)x\(points)\(factor == 2 ? "@2x" : "").png"
        try writePNG(drawIcon(pixels: pixels, detail: pixels <= 32 ? .small : .full), to: iconset.appendingPathComponent(name))
    }
}
try writePNG(drawIcon(pixels: 1024, detail: .full), to: outDir.appendingPathComponent("AppIcon-1024.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", outDir.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed (\(iconutil.terminationStatus))") }
print("wrote \(outDir.path)/AppIcon.icns and AppIcon-1024.png")
