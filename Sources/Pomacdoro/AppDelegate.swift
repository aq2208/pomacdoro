import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private let notifier = Notifier()
    private var statusItemController: StatusItemController?
    private let popover = NSPopover()
    private var observation: AnyObject?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = StatusItemController { [weak self] in self?.togglePopover() }
        statusItemController = controller

        popover.behavior = .transient  // closes when you click elsewhere
        popover.contentSize = NSSize(width: 260, height: 300)
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(model: model, onQuit: { NSApp.terminate(nil) })
        )

        model.onPhaseCompleted = { [weak self] finished, next in
            self?.notifier.announce(finished: finished, next: next)
        }
        notifier.requestAuthorization()

        // Repaint the menu bar item on every published change from the model.
        observation = model.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.syncStatusItem() }
        }
        syncStatusItem()
    }

    private func syncStatusItem() {
        statusItemController?.update(
            phase: model.phase,
            countdown: model.countdown,
            isPaused: model.runState == .paused
        )
    }

    private func togglePopover() {
        guard let button = statusItemController?.statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // An accessory app is not active by default, so the panel needs focus
            // handed to it for the text fields and keyboard shortcuts to work.
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
