import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private let notifier = Notifier()
    private var statusItemController: StatusItemController?
    private let popover = NSPopover()
    private var panel: NSHostingController<PopoverView>?
    private var observation: AnyObject?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = StatusItemController { [weak self] in self?.togglePopover() }
        statusItemController = controller

        let panel = NSHostingController(
            rootView: PopoverView(model: model, onQuit: { NSApp.terminate(nil) })
        )
        self.panel = panel
        popover.behavior = .transient  // closes when you click elsewhere
        popover.contentViewController = panel

        model.onPhaseCompleted = { [weak self] finished, next in
            guard let self else { return }
            self.notifier.announce(finished: finished, next: next, sounds: self.model.sounds)
        }
        model.onPreviewSound = { [weak self] name in
            self?.notifier.play(name)
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
            // Size to the content rather than a hardcoded height, so adding a row
            // to the panel cannot leave the popover the wrong size.
            if let panel {
                popover.contentSize = panel.view.fittingSize
            }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // An accessory app is not active by default, so the panel needs focus
            // handed to it for the text fields and keyboard shortcuts to work.
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
