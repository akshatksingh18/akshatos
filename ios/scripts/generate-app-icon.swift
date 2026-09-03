import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift generate-app-icon.swift <output.png>\n", stderr)
    exit(64)
}

let side = 1024
let canvas = NSRect(x: 0, y: 0, width: side, height: side)

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: side,
    pixelsHigh: side,
    bitsPerSample: 8,
    samplesPerPixel: 3,
    hasAlpha: false,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: side * 3,
    bitsPerPixel: 24
), let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Unable to create the app-icon drawing context.\n", stderr)
    exit(1)
}

bitmap.size = NSSize(width: side, height: side)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext

let background = NSGradient(
    starting: NSColor(calibratedRed: 0.04, green: 0.07, blue: 0.13, alpha: 1),
    ending: NSColor(calibratedRed: 0.12, green: 0.20, blue: 0.36, alpha: 1)
)
background?.draw(in: canvas, angle: -55)

let haloRect = NSRect(x: 164, y: 164, width: 696, height: 696)
let halo = NSBezierPath(ovalIn: haloRect)
NSColor(calibratedWhite: 1, alpha: 0.08).setFill()
halo.fill()

let ringRect = NSRect(x: 218, y: 218, width: 588, height: 588)
let ring = NSBezierPath(ovalIn: ringRect)
ring.lineWidth = 36
NSColor(calibratedRed: 0.70, green: 0.96, blue: 0.38, alpha: 1).setStroke()
ring.stroke()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let text = NSString(string: "45")
let textAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 300, weight: .heavy),
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph
]
text.draw(
    in: NSRect(x: 212, y: 342, width: 600, height: 350),
    withAttributes: textAttributes
)

let accent = NSBezierPath()
accent.move(to: NSPoint(x: 350, y: 308))
accent.line(to: NSPoint(x: 674, y: 308))
accent.lineWidth = 28
accent.lineCapStyle = .round
NSColor(calibratedRed: 0.70, green: 0.96, blue: 0.38, alpha: 1).setStroke()
accent.stroke()

graphicsContext.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode the app icon as PNG.\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL, options: .atomic)
print("Generated placeholder app icon at \(outputURL.path)")
