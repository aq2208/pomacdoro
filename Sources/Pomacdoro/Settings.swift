import Foundation

/// Durations and the session count, persisted in UserDefaults so they survive a relaunch.
enum Settings {
    private enum Key {
        static let focus = "focusMinutes"
        static let shortRest = "shortRestMinutes"
        static let longRest = "longRestMinutes"
        static let longRestEvery = "longRestEvery"
        static let sessions = "completedFocusSessions"
        static let sessionsDate = "completedFocusSessionsDate"
    }

    /// Clamped so a stepper or a hand-edited defaults entry cannot produce a zero-length phase.
    static let minutesRange = 1...180

    private static var defaults: UserDefaults { .standard }

    static func loadDurations() -> Durations {
        let fallback = Durations.default
        return Durations(
            focusMinutes: minutes(Key.focus, fallback.focusMinutes),
            shortRestMinutes: minutes(Key.shortRest, fallback.shortRestMinutes),
            longRestMinutes: minutes(Key.longRest, fallback.longRestMinutes),
            longRestEvery: {
                let stored = defaults.integer(forKey: Key.longRestEvery)
                return stored > 0 ? stored : fallback.longRestEvery
            }()
        )
    }

    static func save(_ durations: Durations) {
        defaults.set(durations.focusMinutes, forKey: Key.focus)
        defaults.set(durations.shortRestMinutes, forKey: Key.shortRest)
        defaults.set(durations.longRestMinutes, forKey: Key.longRest)
        defaults.set(durations.longRestEvery, forKey: Key.longRestEvery)
    }

    /// The count is scoped to a calendar day, so "sessions" in the popover means today.
    static func loadSessions(now: Date = Date()) -> Int {
        guard let stored = defaults.object(forKey: Key.sessionsDate) as? Date,
              Calendar.current.isDate(stored, inSameDayAs: now) else { return 0 }
        return defaults.integer(forKey: Key.sessions)
    }

    static func saveSessions(_ count: Int, now: Date = Date()) {
        defaults.set(count, forKey: Key.sessions)
        defaults.set(now, forKey: Key.sessionsDate)
    }

    private static func minutes(_ key: String, _ fallback: Int) -> Int {
        let stored = defaults.integer(forKey: key)
        guard stored > 0 else { return fallback }
        return min(max(stored, minutesRange.lowerBound), minutesRange.upperBound)
    }
}
