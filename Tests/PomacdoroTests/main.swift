import Foundation

/// A fixed start point so every test reasons about explicit offsets.
let t0 = Date(timeIntervalSince1970: 1_700_000_000)

func makeCore(
    focus: Int = 25,
    shortRest: Int = 5,
    longRest: Int = 15,
    every: Int = 4
) -> PomodoroCore {
    PomodoroCore(durations: Durations(
        focusMinutes: focus,
        shortRestMinutes: shortRest,
        longRestMinutes: longRest,
        longRestEvery: every
    ))
}

/// Runs the current phase to its end and returns the resulting event.
@discardableResult
func runToEnd(_ core: PomodoroCore, from now: inout Date) -> TickEvent {
    now = now.addingTimeInterval(core.remaining(at: now))
    return core.tick(at: now)
}

let t = TestRunner()

t.test("starts idle on a full focus phase") {
    let core = makeCore()
    t.expectEqual(core.phase, .focus, "phase")
    t.expectEqual(core.state, .idle, "state")
    t.expectEqual(core.remaining(at: t0), 25 * 60, "remaining")
}

t.test("running counts down against the wall clock") {
    let core = makeCore()
    core.start(at: t0)
    t.expectEqual(core.state, .running, "state")
    t.expectEqual(core.remaining(at: t0.addingTimeInterval(60)), 24 * 60, "remaining")
    t.expectEqual(core.tick(at: t0.addingTimeInterval(60)), .nothing, "tick")
}

t.test("focus expiring advances into a short rest and counts the session") {
    let core = makeCore()
    core.start(at: t0)
    let end = t0.addingTimeInterval(25 * 60)
    t.expectEqual(core.tick(at: end), .phaseCompleted(finished: .focus, next: .shortRest), "event")
    t.expectEqual(core.phase, .shortRest, "phase")
    t.expectEqual(core.state, .running, "state")
    t.expectEqual(core.completedFocusSessions, 1, "sessions")
    t.expectEqual(core.remaining(at: end), 5 * 60, "remaining")
}

t.test("rest expiring returns to focus without counting a session") {
    let core = makeCore()
    core.start(at: t0)
    var now = t0
    runToEnd(core, from: &now)
    let event = runToEnd(core, from: &now)
    t.expectEqual(event, .phaseCompleted(finished: .shortRest, next: .focus), "event")
    t.expectEqual(core.phase, .focus, "phase")
    t.expectEqual(core.completedFocusSessions, 1, "sessions")
}

t.test("the fourth focus session leads into a long rest") {
    let core = makeCore()
    core.start(at: t0)
    var now = t0
    var rests: [Phase] = []
    for _ in 0..<4 {
        if case let .phaseCompleted(_, next) = runToEnd(core, from: &now) {
            rests.append(next)
        }
        runToEnd(core, from: &now)
    }
    t.expectEqual(rests, [.shortRest, .shortRest, .shortRest, .longRest], "rest sequence")
    t.expectEqual(core.completedFocusSessions, 4, "sessions")
    t.expectEqual(core.phase, .focus, "phase")
}

t.test("the cycle keeps its cadence past the first long rest") {
    let core = makeCore()
    core.start(at: t0)
    var now = t0
    var rests: [Phase] = []
    for _ in 0..<8 {
        if case let .phaseCompleted(_, next) = runToEnd(core, from: &now) {
            rests.append(next)
        }
        runToEnd(core, from: &now)
    }
    t.expectEqual(
        rests,
        [.shortRest, .shortRest, .shortRest, .longRest,
         .shortRest, .shortRest, .shortRest, .longRest],
        "rest sequence"
    )
    t.expectEqual(core.completedFocusSessions, 8, "sessions")
}

t.test("a custom long-rest cadence is honoured") {
    let core = makeCore(every: 2)
    core.start(at: t0)
    var now = t0
    var rests: [Phase] = []
    for _ in 0..<2 {
        if case let .phaseCompleted(_, next) = runToEnd(core, from: &now) {
            rests.append(next)
        }
        runToEnd(core, from: &now)
    }
    t.expectEqual(rests, [.shortRest, .longRest], "rest sequence")
}

t.test("pause holds the remaining time and resume continues from it") {
    let core = makeCore()
    core.start(at: t0)
    let pauseAt = t0.addingTimeInterval(10 * 60)
    core.pause(at: pauseAt)
    t.expectEqual(core.state, .paused, "state")
    t.expectEqual(core.remaining(at: pauseAt), 15 * 60, "remaining at pause")
    // Time passing while paused must not consume the phase.
    t.expectEqual(core.remaining(at: t0.addingTimeInterval(60 * 60)), 15 * 60, "remaining later")

    let resumeAt = t0.addingTimeInterval(60 * 60)
    core.start(at: resumeAt)
    t.expectEqual(core.state, .running, "state after resume")
    t.expectEqual(core.remaining(at: resumeAt.addingTimeInterval(5 * 60)), 10 * 60, "remaining")
}

t.test("a paused phase does not expire") {
    let core = makeCore()
    core.start(at: t0)
    core.pause(at: t0.addingTimeInterval(60))
    t.expectEqual(core.tick(at: t0.addingTimeInterval(10_000)), .nothing, "tick")
    t.expectEqual(core.phase, .focus, "phase")
}

t.test("a phase that expired during sleep is caught on the next tick") {
    let core = makeCore()
    core.start(at: t0)
    // The machine slept through the whole focus phase and 2 minutes of the rest.
    let wake = t0.addingTimeInterval(27 * 60)
    t.expectEqual(core.tick(at: wake), .phaseCompleted(finished: .focus, next: .shortRest), "event")
    // Overshoot is carried over, so 3 of the 5 rest minutes are left.
    t.expectEqual(core.remaining(at: wake), 3 * 60, "remaining")
}

t.test("reset returns to an idle focus phase and keeps the session count") {
    let core = makeCore()
    core.start(at: t0)
    var now = t0
    runToEnd(core, from: &now)
    core.reset(at: now)
    t.expectEqual(core.phase, .focus, "phase")
    t.expectEqual(core.state, .idle, "state")
    t.expectEqual(core.remaining(at: now), 25 * 60, "remaining")
    t.expectEqual(core.completedFocusSessions, 1, "sessions kept")

    core.resetSessions()
    t.expectEqual(core.completedFocusSessions, 0, "sessions cleared")
}

t.test("changing durations while idle changes the displayed phase length") {
    let core = makeCore()
    core.durations = Durations(
        focusMinutes: 50, shortRestMinutes: 10, longRestMinutes: 20, longRestEvery: 4
    )
    t.expectEqual(core.remaining(at: t0), 50 * 60, "remaining")
}

t.test("a running phase is not disturbed by a duration change") {
    let core = makeCore()
    core.start(at: t0)
    core.durations = Durations(
        focusMinutes: 50, shortRestMinutes: 10, longRestMinutes: 20, longRestEvery: 4
    )
    t.expectEqual(core.remaining(at: t0.addingTimeInterval(60)), 24 * 60, "remaining")
    // The new focus length takes effect the next time the phase comes around.
    var now = t0
    runToEnd(core, from: &now)
    runToEnd(core, from: &now)
    t.expectEqual(core.remaining(at: now), 50 * 60, "remaining on next focus")
}

t.test("countdown formats as MM:SS and rounds up") {
    t.expectEqual(formatCountdown(25 * 60), "25:00")
    t.expectEqual(formatCountdown(59.4), "01:00")
    t.expectEqual(formatCountdown(0), "00:00")
    t.expectEqual(formatCountdown(-5), "00:00")
    t.expectEqual(formatCountdown(61), "01:01")
    t.expectEqual(formatCountdown(60 * 60), "60:00")
}

t.test("durations survive a save and load round trip") {
    let saved = Durations(
        focusMinutes: 45, shortRestMinutes: 8, longRestMinutes: 20, longRestEvery: 3
    )
    Settings.save(saved)
    t.expectEqual(Settings.loadDurations(), saved, "round trip")
}

t.test("out of range stored durations fall back to something usable") {
    UserDefaults.standard.set(0, forKey: "focusMinutes")
    UserDefaults.standard.set(9_999, forKey: "shortRestMinutes")
    let loaded = Settings.loadDurations()
    t.expectEqual(loaded.focusMinutes, 25, "zero falls back to the default")
    t.expectEqual(loaded.shortRestMinutes, 180, "an absurd value is clamped")
}

t.test("the session count is scoped to the day it was saved") {
    let today = Date()
    Settings.saveSessions(6, now: today)
    t.expectEqual(Settings.loadSessions(now: today), 6, "same day")
    let tomorrow = today.addingTimeInterval(36 * 60 * 60)
    t.expectEqual(Settings.loadSessions(now: tomorrow), 0, "next day starts at zero")
}

exit(t.finish())
