import Foundation

/// The three kinds of interval the timer cycles through.
enum Phase: String, Equatable, Sendable {
    case focus
    case shortRest
    case longRest

    var isRest: Bool { self != .focus }

    var label: String {
        switch self {
        case .focus: return "Focus"
        case .shortRest: return "Rest"
        case .longRest: return "Long Rest"
        }
    }
}

/// How long each phase lasts, and how often a long rest replaces a short one.
struct Durations: Equatable, Sendable {
    var focusMinutes: Int
    var shortRestMinutes: Int
    var longRestMinutes: Int
    var longRestEvery: Int

    static let `default` = Durations(
        focusMinutes: 25,
        shortRestMinutes: 5,
        longRestMinutes: 15,
        longRestEvery: 4
    )

    func seconds(for phase: Phase) -> TimeInterval {
        switch phase {
        case .focus: return TimeInterval(focusMinutes) * 60
        case .shortRest: return TimeInterval(shortRestMinutes) * 60
        case .longRest: return TimeInterval(longRestMinutes) * 60
        }
    }
}

enum RunState: Equatable, Sendable {
    case idle
    case running
    case paused
}

/// What a call to `tick` observed.
enum TickEvent: Equatable, Sendable {
    case nothing
    /// The phase ran out. `finished` is the phase that ended, `next` is the one now running.
    case phaseCompleted(finished: Phase, next: Phase)
}

/// The timer state machine.
///
/// Time is tracked as an absolute deadline rather than a decrementing counter, so
/// the remaining time is always recomputed from the wall clock. That keeps the
/// countdown honest across timer coalescing and system sleep: a phase that ran out
/// while the machine was asleep is detected on the next tick.
final class PomodoroCore {
    private(set) var phase: Phase = .focus
    private(set) var state: RunState = .idle
    /// Focus intervals completed since the last session reset. Drives the long-rest cadence.
    private(set) var completedFocusSessions: Int = 0

    var durations: Durations {
        didSet {
            guard durations != oldValue else { return }
            // A length change applies to the current phase only when nothing is
            // counting down; interrupting a running phase would be surprising.
            if state == .idle { pausedRemaining = nil }
        }
    }

    private var endDate: Date?
    private var pausedRemaining: TimeInterval?

    init(durations: Durations = .default, completedFocusSessions: Int = 0) {
        self.durations = durations
        self.completedFocusSessions = completedFocusSessions
    }

    /// Seconds left in the current phase as of `now`, never negative.
    func remaining(at now: Date) -> TimeInterval {
        switch state {
        case .idle:
            return durations.seconds(for: phase)
        case .paused:
            return pausedRemaining ?? durations.seconds(for: phase)
        case .running:
            guard let endDate else { return 0 }
            return max(0, endDate.timeIntervalSince(now))
        }
    }

    /// Start from idle, or resume from paused. No effect while already running.
    func start(at now: Date) {
        guard state != .running else { return }
        let seconds = remaining(at: now)
        endDate = now.addingTimeInterval(seconds)
        pausedRemaining = nil
        state = .running
    }

    /// Freeze the countdown, keeping whatever is left for the next start.
    func pause(at now: Date) {
        guard state == .running else { return }
        pausedRemaining = remaining(at: now)
        endDate = nil
        state = .paused
    }

    func toggle(at now: Date) {
        if state == .running {
            pause(at: now)
        } else {
            start(at: now)
        }
    }

    /// Back to an idle focus phase. The session count is left alone.
    func reset(at now: Date) {
        phase = .focus
        state = .idle
        endDate = nil
        pausedRemaining = nil
    }

    func resetSessions() {
        completedFocusSessions = 0
    }

    /// Advance the clock. Returns whether the phase ran out, and the cycle continues
    /// straight into the next phase when it did.
    func tick(at now: Date) -> TickEvent {
        guard state == .running, remaining(at: now) <= 0 else { return .nothing }

        let finished = phase
        if finished == .focus {
            completedFocusSessions += 1
        }
        let next = nextPhase(after: finished)

        phase = next
        // Carry over any overshoot so a long sleep does not hand back a full extra phase.
        let overshoot = endDate.map { max(0, now.timeIntervalSince($0)) } ?? 0
        let nextLength = durations.seconds(for: next)
        endDate = now.addingTimeInterval(max(0, nextLength - overshoot))
        pausedRemaining = nil
        state = .running

        return .phaseCompleted(finished: finished, next: next)
    }

    private func nextPhase(after finished: Phase) -> Phase {
        guard finished == .focus else { return .focus }
        let every = max(1, durations.longRestEvery)
        return completedFocusSessions % every == 0 ? .longRest : .shortRest
    }
}

/// Formats seconds as MM:SS, rounding up so the display shows 25:00 the instant a
/// 25 minute phase begins rather than 24:59.
func formatCountdown(_ seconds: TimeInterval) -> String {
    let total = Int(ceil(max(0, seconds)))
    return String(format: "%02d:%02d", total / 60, total % 60)
}
