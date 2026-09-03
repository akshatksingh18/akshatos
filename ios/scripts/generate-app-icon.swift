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

let backgroundColors = [
    CGColor(red: 0.04, green: 0.07, blue: 0.13, alpha: 1),
    CGColor(red: 0.12, green: 0.20, blue: 0.36, alpha: 1)
] as CFArray
guard let background = CGGradient(
    colorsSpace: colorSpace,
    colors: backgroundColors,
    locations: [0, 1]
) else {
    fputs("Unable to create the app-icon gradient.\n", stderr)
    exit(1)
}
context.drawLinearGradient(
    background,
    start: CGPoint(x: 0, y: sideLength),
    end: CGPoint(x: sideLength, y: 0),
    options: []
)

context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.08))
context.fillEllipse(in: CGRect(x: 164, y: 164, width: 696, height: 696))

let accentColor = CGColor(red: 0.70, green: 0.96, blue: 0.38, alpha: 1)
context.setStrokeColor(accentColor)
context.setLineWidth(36)
context.strokeEllipse(in: CGRect(x: 218, y: 218, width: 588, height: 588))

context.setLineWidth(28)
context.setLineCap(.round)
context.move(to: CGPoint(x: 350, y: 308))
context.addLine(to: CGPoint(x: 674, y: 308))
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
print("Generated placeholder app icon at \(outputURL.path)")
