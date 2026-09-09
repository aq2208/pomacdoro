import Combine
import Foundation

/// Drives the UI: owns the timer core, ticks it, publishes what the menu bar and
/// popover render, and persists anything the user changes.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var countdown: String = "25:00"
    @Published private(set) var phase: Phase = .focus
    @Published private(set) var runState: RunState = .idle
    @Published private(set) var sessions: Int = 0

    @Published var focusMinutes: Int { didSet { applyDurations() } }
    @Published var shortRestMinutes: Int { didSet { applyDurations() } }
    @Published var longRestMinutes: Int { didSet { applyDurations() } }

    @Published var focusEndSound: String { didSet { applySounds(changed: focusEndSound, was: oldValue) } }
    @Published var restEndSound: String { didSet { applySounds(changed: restEndSound, was: oldValue) } }

    /// Fires on every phase transition so the delegate can alert the user.
    var onPhaseCompleted: ((Phase, Phase) -> Void)?
    /// Plays a sound by name, so picking one in the panel can audition it.
    var onPreviewSound: ((String) -> Void)?

    private let core: PomodoroCore
    private var ticker: Timer?
    /// Guards the clamping writes in `applyDurations` from re-entering their own `didSet`.
    private var isApplyingDurations = false

    init() {
        let durations = Settings.loadDurations()
        let sounds = Settings.loadSounds()
        let sessions = Settings.loadSessions()
        core = PomodoroCore(durations: durations, completedFocusSessions: sessions)
        focusMinutes = durations.focusMinutes
        shortRestMinutes = durations.shortRestMinutes
        longRestMinutes = durations.longRestMinutes
        focusEndSound = sounds.focusEnd
        restEndSound = sounds.restEnd
        self.sessions = sessions
        refresh(now: Date())
    }

    var isRunning: Bool { runState == .running }

    var sounds: SoundChoice {
        SoundChoice(focusEnd: focusEndSound, restEnd: restEndSound)
    }

    var primaryButtonTitle: String {
        switch runState {
        case .running: return "Pause"
        case .paused: return "Resume"
        case .idle: return "Start"
        }
    }

    func toggle() {
        core.toggle(at: Date())
        startTickerIfNeeded()
        refresh(now: Date())
    }

    func reset() {
        core.reset(at: Date())
        stopTicker()
        refresh(now: Date())
    }

    func resetSessions() {
        core.resetSessions()
        Settings.saveSessions(0)
        refresh(now: Date())
    }

    /// Ticks four times a second so the countdown never appears to skip a second.
    private func startTickerIfNeeded() {
        guard ticker == nil else { return }
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        timer.tolerance = 0.1
        // Common mode keeps the countdown moving while a menu or resize tracks events.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        let now = Date()
        if case let .phaseCompleted(finished, next) = core.tick(at: now) {
            Settings.saveSessions(core.completedFocusSessions)
            onPhaseCompleted?(finished, next)
        }
        refresh(now: now)
        if core.state != .running { stopTicker() }
    }

    private func applyDurations() {
        guard !isApplyingDurations else { return }
        isApplyingDurations = true
        defer { isApplyingDurations = false }

        focusMinutes = clamp(focusMinutes)
        shortRestMinutes = clamp(shortRestMinutes)
        longRestMinutes = clamp(longRestMinutes)
        let durations = Durations(
            focusMinutes: focusMinutes,
            shortRestMinutes: shortRestMinutes,
            longRestMinutes: longRestMinutes,
            longRestEvery: core.durations.longRestEvery
        )
        guard durations != core.durations else { return }
        core.durations = durations
        Settings.save(durations)
        refresh(now: Date())
    }

    private func applySounds(changed: String, was previous: String) {
        guard changed != previous else { return }
        Settings.save(sounds)
        // Audition the pick straight away; that is the only way to judge it.
        onPreviewSound?(changed)
    }

    private func clamp(_ minutes: Int) -> Int {
        min(max(minutes, Settings.minutesRange.lowerBound), Settings.minutesRange.upperBound)
    }

    private func refresh(now: Date) {
        countdown = formatCountdown(core.remaining(at: now))
        phase = core.phase
        runState = core.state
        sessions = core.completedFocusSessions
    }
}
