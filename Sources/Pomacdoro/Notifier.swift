import AppKit
import UserNotifications

/// Announces the end of a phase with a sound and a banner.
///
/// The sound path uses a built-in system sound and needs no permission, so it always
/// works. The banner goes through UserNotifications when the app is running from a
/// signed bundle and the user has granted permission; otherwise it falls back to
/// `osascript`, which routes through Script Editor's own notification permission.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private var useUserNotifications = false

    /// UNUserNotificationCenter traps when the process has no bundle identifier, which
    /// is the case under `swift run`, so it is only touched from inside a real bundle.
    private var isBundled: Bool { Bundle.main.bundleIdentifier != nil }

    func requestAuthorization() {
        guard isBundled else { return }
        let center = UNUserNotificationCenter.current()
        // Without a delegate the banner is swallowed whenever the app happens to be
        // frontmost, which it is while the popover has focus.
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            Task { @MainActor in self?.useUserNotifications = granted }
        }
    }

    func announce(finished: Phase, next: Phase, sounds: SoundChoice) {
        play(sounds.name(forEndOf: finished))
        let title = finished == .focus ? "Focus finished" : "Break over"
        let body = next == .focus
            ? "Back to work. Focus session starting now."
            : "Time for a \(next == .longRest ? "long break" : "break")."
        postBanner(title: title, body: body)
    }

    /// Also used to audition a sound as it is picked. An empty name is silence.
    func play(_ name: String) {
        guard !name.isEmpty else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    private func postBanner(title: String, body: String) {
        guard isBundled, useUserNotifications else {
            postViaAppleScript(title: title, body: body)
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            guard error != nil else { return }
            Task { @MainActor in self?.postViaAppleScript(title: title, body: body) }
        }
    }

    private func postViaAppleScript(title: String, body: String) {
        let script = "display notification \(quoted(body)) with title \(quoted(title))"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    private func quoted(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
