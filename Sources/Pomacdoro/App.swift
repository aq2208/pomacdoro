import AppKit

@main
enum PomacdoroApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Accessory: menu bar only, no Dock icon and no application menu.
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
