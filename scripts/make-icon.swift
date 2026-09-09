import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Renders the app icon and writes an .icns.
///
/// The clock face comes from the same `drawClockFace` the menu bar uses, so the
/// logo and the status item can never drift apart. Around it goes the rounded
/// square macOS expects, in tomato red.

/// Big Sur proportions: the rounded square fills about 80% of the canvas, with a
/// corner radius of about 18% of it.
private let contentRatio: CGFloat = 0.8047
private let cornerRatio: CGFloat = 0.1810

func renderIcon(side: CGFloat) -> CGImage? {
    let pixels = Int(side)
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let canvas = CGRect(x: 0, y: 0, width: side, height: side)
    let inset = side * (1 - contentRatio) / 2
    let plate = canvas.insetBy(dx: inset, dy: inset)
    let platePath = CGPath(
        roundedRect: plate,
        cornerWidth: side * cornerRatio,
        cornerHeight: side * cornerRatio,
        transform: nil
    )

    // Tomato red, lighter at the top so the plate reads as slightly lit.
    context.saveGState()
    context.addPath(platePath)
    context.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
        colors: [
            CGColor(srgbRed: 0.93, green: 0.36, blue: 0.27, alpha: 1),
            CGColor(srgbRed: 0.76, green: 0.18, blue: 0.14, alpha: 1),
        ] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: plate.midX, y: plate.maxY),
        end: CGPoint(x: plate.midX, y: plate.minY),
        options: []
    )
    context.restoreGState()

    let face = plate.insetBy(dx: plate.width * 0.21, dy: plate.width * 0.21)
    drawClockFace(in: context, rect: face, color: CGColor(gray: 1, alpha: 1))

    return context.makeImage()
}

func write(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else {
        throw NSError(domain: "make-icon", code: 1)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "make-icon", code: 2)
    }
}

@main
enum MakeIcon {
    static func main() throws {
        let output = CommandLine.arguments.count > 1
            ? URL(fileURLWithPath: CommandLine.arguments[1])
            : URL(fileURLWithPath: "AppIcon.icns")

        let iconset = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

        // The set of sizes .icns requires, each at 1x and 2x.
        for base in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                guard let image = renderIcon(side: CGFloat(base * scale)) else {
                    fatalError("could not render \(base)@\(scale)x")
                }
                let suffix = scale == 1 ? "" : "@2x"
                try write(image, to: iconset.appendingPathComponent("icon_\(base)x\(base)\(suffix).png"))
            }
        }

        let convert = Process()
        convert.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        convert.arguments = ["--convert", "icns", "--output", output.path, iconset.path]
        try convert.run()
        convert.waitUntilExit()
        try? FileManager.default.removeItem(at: iconset)

        guard convert.terminationStatus == 0 else {
            FileHandle.standardError.write(Data("iconutil failed\n".utf8))
            exit(1)
        }
        print("Wrote \(output.path)")
    }
}
