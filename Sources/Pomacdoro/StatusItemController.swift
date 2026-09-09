import AppKit

/// Owns the menu bar item and keeps its icon and countdown in sync.
@MainActor
final class StatusItemController {
    let statusItem: NSStatusItem

    init(action: @escaping () -> Void) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            let target = ButtonTarget(action: action)
            button.target = target
            button.action = #selector(ButtonTarget.fire)
            self.buttonTarget = target
        }
    }

    private var buttonTarget: ButtonTarget?
    /// Drawing the clock is the expensive part of an update, and it only depends
    /// on the phase and the appearance, not on the countdown that drives updates.
    private var cachedIcon: (phase: Phase, appearance: NSAppearance.Name, image: NSImage)?

    func update(phase: Phase, countdown: String, isPaused: Bool) {
        guard let button = statusItem.button else { return }

        // Monospaced digits keep the item from twitching as the numbers change width.
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        button.attributedTitle = NSAttributedString(
            string: " " + countdown,
            attributes: [.font: font]
        )

        let image = icon(for: phase, appearance: button.effectiveAppearance)
        image.accessibilityDescription = "\(phase.label) \(countdown)"
        button.image = image

        // A paused timer is dimmed so a stalled countdown is obvious at a glance.
        button.appearsDisabled = isPaused
        button.toolTip = "Pomacdoro: \(phase.label) \(countdown)"
    }

    /// Redraws only when the phase changes, or when the menu bar switches
    /// between light and dark and the colour has to be resolved again.
    private func icon(for phase: Phase, appearance: NSAppearance) -> NSImage {
        let name = appearance.bestMatch(from: [.aqua, .darkAqua]) ?? .aqua
        if let cached = cachedIcon, cached.phase == phase, cached.appearance == name {
            return cached.image
        }
        let image = clockIcon(for: phase)
        cachedIcon = (phase, name, image)
        return image
    }

    private final class ButtonTarget: NSObject {
        private let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func fire() { action() }
    }
}
