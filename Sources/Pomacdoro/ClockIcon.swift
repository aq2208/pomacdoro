import AppKit
import CoreGraphics

/// The colour that says which phase is running.
///
/// Each is defined twice so the icon stays legible in both menu bar appearances:
/// a deep, saturated tone against the light menu bar, a brighter one against dark.
enum PhaseColor {
    static let focus = NSColor(name: "focusYellow") { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 1.00, green: 0.83, blue: 0.15, alpha: 1)
            : NSColor(srgbRed: 0.78, green: 0.56, blue: 0.00, alpha: 1)
    }

    static let rest = NSColor(name: "restGreen") { appearance in
        appearance.isDark
            ? NSColor(srgbRed: 0.30, green: 0.85, blue: 0.40, alpha: 1)
            : NSColor(srgbRed: 0.11, green: 0.54, blue: 0.20, alpha: 1)
    }

    static func forPhase(_ phase: Phase) -> NSColor {
        phase.isRest ? rest : focus
    }
}

private extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}

/// Draws a clock face: a ring with an hour and a minute hand.
///
/// The hands sit at ten past ten, the arrangement that reads as a clock at the
/// smallest sizes, and every measurement is a fraction of `rect` so the same
/// drawing serves both the 16 point menu bar icon and the 1024 pixel app icon.
func drawClockFace(in context: CGContext, rect: CGRect, color: CGColor) {
    let side = min(rect.width, rect.height)
    let ringWidth = side * 0.105
    let handWidth = side * 0.085
    let radius = (side - ringWidth) / 2
    let center = CGPoint(x: rect.midX, y: rect.midY)

    context.saveGState()
    context.setStrokeColor(color)
    context.setLineCap(.round)

    context.setLineWidth(ringWidth)
    context.addArc(
        center: center,
        radius: radius,
        startAngle: 0,
        endAngle: 2 * .pi,
        clockwise: false
    )
    context.strokePath()

    // Angles run clockwise from twelve o'clock.
    func hand(toHour angle: CGFloat, length: CGFloat) {
        let radians = angle * .pi / 180
        context.move(to: center)
        context.addLine(to: CGPoint(
            x: center.x + sin(radians) * radius * length,
            y: center.y + cos(radians) * radius * length
        ))
    }

    context.setLineWidth(handWidth)
    hand(toHour: 60, length: 0.66)    // minute hand, at two
    hand(toHour: 300, length: 0.36)   // hour hand, at ten
    context.strokePath()

    // The pivot is what stops the two hands reading as a plain chevron.
    context.setFillColor(color)
    context.fillEllipse(in: CGRect(
        x: center.x - handWidth,
        y: center.y - handWidth,
        width: handWidth * 2,
        height: handWidth * 2
    ))

    context.restoreGState()
}

/// The menu bar icon for a phase. Not a template image, because the whole point
/// is the colour.
@MainActor
func clockIcon(for phase: Phase, side: CGFloat = 16) -> NSImage {
    let size = NSSize(width: side, height: side)
    let image = NSImage(size: size, flipped: false) { rect in
        guard let context = NSGraphicsContext.current?.cgContext else { return false }
        // Resolved inside the handler so the drawing appearance picks the right tone.
        drawClockFace(in: context, rect: rect, color: PhaseColor.forPhase(phase).cgColor)
        return true
    }
    image.isTemplate = false
    return image
}
