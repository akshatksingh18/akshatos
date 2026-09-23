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
    CGColor(red: 0.02, green: 0.03, blue: 0.09, alpha: 1),
    CGColor(red: 0.25, green: 0.12, blue: 0.48, alpha: 1),
    CGColor(red: 0.04, green: 0.28, blue: 0.36, alpha: 1)
] as CFArray
guard let background = CGGradient(
    colorsSpace: colorSpace,
    colors: backgroundColors,
    locations: [0, 0.58, 1]
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

context.setFillColor(CGColor(red: 0.67, green: 0.49, blue: 1, alpha: 0.18))
context.fillEllipse(in: CGRect(x: 520, y: 70, width: 520, height: 520))
context.setFillColor(CGColor(red: 0.30, green: 0.91, blue: 0.93, alpha: 0.13))
context.fillEllipse(in: CGRect(x: -110, y: 510, width: 560, height: 560))

// Three orbiting nodes represent the current modules without turning the icon into a tiny menu.
context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.13))
context.setLineWidth(18)
context.strokeEllipse(in: CGRect(x: 140, y: 140, width: 744, height: 744))
context.strokeEllipse(in: CGRect(x: 220, y: 220, width: 584, height: 584))

let nodes: [(CGRect, CGColor)] = [
    (CGRect(x: 168, y: 318, width: 96, height: 96), CGColor(red: 1.00, green: 0.43, blue: 0.55, alpha: 1)),
    (CGRect(x: 744, y: 284, width: 96, height: 96), CGColor(red: 0.30, green: 0.91, blue: 0.93, alpha: 1)),
    (CGRect(x: 586, y: 760, width: 96, height: 96), CGColor(red: 0.76, green: 0.97, blue: 0.43, alpha: 1))
]
for (frame, color) in nodes {
    context.setFillColor(CGColor(red: 0.02, green: 0.03, blue: 0.09, alpha: 0.9))
    context.fillEllipse(in: frame.insetBy(dx: -18, dy: -18))
    context.setFillColor(color)
    context.fillEllipse(in: frame)
}

let accentColor = CGColor(red: 0.76, green: 0.97, blue: 0.43, alpha: 1)
context.setStrokeColor(accentColor)
context.setLineWidth(30)
context.strokeEllipse(in: CGRect(x: 292, y: 292, width: 440, height: 440))

// The familiar A stays central, now sitting inside the playful homebase orbit.
context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.96))
context.setLineWidth(48)
context.setLineCap(.round)
context.setLineJoin(.round)
context.move(to: CGPoint(x: 354, y: 690))
context.addLine(to: CGPoint(x: 512, y: 342))
context.addLine(to: CGPoint(x: 670, y: 690))
context.move(to: CGPoint(x: 424, y: 544))
context.addLine(to: CGPoint(x: 600, y: 544))
context.strokePath()

context.setFillColor(CGColor(red: 1.00, green: 0.78, blue: 0.32, alpha: 1))
context.fillEllipse(in: CGRect(x: 478, y: 470, width: 68, height: 68))

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
print("Generated AkshatOS homebase icon at \(outputURL.path)")
