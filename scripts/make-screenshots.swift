import AppKit
import SwiftUI

/// Renders the panel and the menu bar item to PNGs for the README.
///
/// These come from the app's own views, driven by the real model, rather than
/// from a screen capture, so they stay correct when the UI changes.

/// A borderless window refuses key status by default, and without it the
/// prominent button renders grey instead of accented.
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
func writePNG(_ rep: NSBitmapImageRep, to url: URL) {
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: url)
    print("Wrote \(url.lastPathComponent)")
}

/// Captures a view at 2x so the image stays crisp on a Retina display.
@MainActor
func capture(_ view: NSView) -> NSBitmapImageRep? {
    let bounds = view.bounds
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(bounds.width * 2),
        pixelsHigh: Int(bounds.height * 2),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }
    rep.size = bounds.size
    view.cacheDisplay(in: bounds, to: rep)
    return rep
}

@main
enum MakeScreenshots {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.activate(ignoringOtherApps: true)

        let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.count > 1
            ? CommandLine.arguments[1]
            : "docs/images")
        try? FileManager.default.createDirectory(
            at: outputDirectory, withIntermediateDirectories: true
        )

        panel(into: outputDirectory)
        menuBar(into: outputDirectory)
    }

    /// The popover panel, mid focus session, in a real key window so the
    /// prominent button renders the way it does in use.
    @MainActor
    private static func panel(into directory: URL) {
        let model = AppModel()
        model.focusMinutes = 25
        model.shortRestMinutes = 5
        model.longRestMinutes = 15
        model.focusEndSound = "Glass"
        model.restEndSound = "Hero"
        model.toggle()

        let hosting = NSHostingController(rootView: PopoverView(model: model, onQuit: {}))
        let size = hosting.view.fittingSize

        // The popover paints its own background in the app, so supply one here.
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        hosting.view.frame = container.bounds
        hosting.view.autoresizingMask = [.width, .height]
        container.addSubview(hosting.view)

        let window = KeyableWindow(
            contentRect: container.bounds,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = container
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeMain()
        RunLoop.main.run(until: Date().addingTimeInterval(1.5))
        print("panel window key=\(window.isKeyWindow) app active=\(NSApp.isActive) size=\(size)")

        if let rep = capture(container) {
            writePNG(rep, to: directory.appendingPathComponent("panel.png"))
        }
        window.orderOut(nil)
    }

    /// The menu bar item in both phases, on strips standing in for the light and
    /// dark menu bars.
    ///
    /// A status bar button clips its own title when captured outside a real menu
    /// bar, so the strip is drawn from the same pieces the button uses: the icon
    /// from `clockIcon`, the countdown in the same monospaced digit font.
    @MainActor
    private static func menuBar(into directory: URL) {
        let rowHeight: CGFloat = 26
        let width: CGFloat = 148
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)

        for (fileName, appearanceName, background, textColor) in [
            ("menubar-light.png", NSAppearance.Name.aqua,
             NSColor(white: 0.96, alpha: 1), NSColor(white: 0.1, alpha: 1)),
            ("menubar-dark.png", NSAppearance.Name.darkAqua,
             NSColor(white: 0.14, alpha: 1), NSColor(white: 0.95, alpha: 1)),
        ] {
            let appearance = NSAppearance(named: appearanceName)!
            let size = NSSize(width: width, height: rowHeight * 2)
            guard let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(size.width * 2),
                pixelsHigh: Int(size.height * 2),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ) else { continue }
            rep.size = size

            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            appearance.performAsCurrentDrawingAppearance {
                background.setFill()
                NSRect(origin: .zero, size: size).fill()

                for (index, sample) in [(Phase.focus, "24:13"), (Phase.shortRest, "04:41")].enumerated() {
                    let rowBottom = size.height - rowHeight * CGFloat(index + 1)
                    let icon = clockIcon(for: sample.0)
                    icon.draw(in: NSRect(
                        x: 14, y: rowBottom + (rowHeight - 16) / 2, width: 16, height: 16
                    ))
                    let title = NSAttributedString(
                        string: sample.1,
                        attributes: [.font: font, .foregroundColor: textColor]
                    )
                    let textSize = title.size()
                    title.draw(at: NSPoint(
                        x: 36, y: rowBottom + (rowHeight - textSize.height) / 2
                    ))
                }
            }
            NSGraphicsContext.restoreGraphicsState()
            writePNG(rep, to: directory.appendingPathComponent(fileName))
        }
    }
}
