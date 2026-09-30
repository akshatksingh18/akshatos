import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift generate-app-icon.swift <output.png>\n", stderr)
    exit(64)
}

let side = 1024
let sideLength = CGFloat(side)
let colorSpace = CGColorSpaceCreateDeviceRGB()

guard let context = CGContext(
    data: nil,
    width: side,
    height: side,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fputs("Unable to create the app-icon drawing context.\n", stderr)
    exit(1)
}

// Minimal: the app's flat background colour and a single white A with an accent crossbar, matching
// the plain in-app design. The earlier gradient, glow and orbit rings were retired with the quest theme.
context.setFillColor(CGColor(red: 0.043, green: 0.043, blue: 0.051, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: sideLength, height: sideLength))

context.setLineCap(.round)
context.setLineJoin(.round)
context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
context.setLineWidth(56)
context.move(to: CGPoint(x: 332, y: 256))
context.addLine(to: CGPoint(x: 512, y: 736))
context.addLine(to: CGPoint(x: 692, y: 256))
context.strokePath()

context.setStrokeColor(CGColor(red: 0.52, green: 0.82, blue: 0.70, alpha: 1))
context.move(to: CGPoint(x: 410, y: 432))
context.addLine(to: CGPoint(x: 614, y: 432))
context.strokePath()

guard let image = context.makeImage() else {
    fputs("Unable to render the app icon.\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
guard let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    fputs("Unable to create the app-icon PNG destination.\n", stderr)
    exit(1)
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fputs("Unable to encode the app icon as PNG.\n", stderr)
    exit(1)
}
print("Generated AkshatOS icon at \(outputURL.path)")
