# Pomacdoro

A menu bar Pomodoro timer for macOS. The countdown is always visible in the menu
bar; clicking it opens a panel with the transport controls and the three
durations.

Focus, short rest, focus, short rest, with a long rest replacing every fourth
short one. Each phase rolls into the next on its own.

## Install

Requires macOS 13 or later and the Xcode Command Line Tools, which you can get
with `xcode-select --install`. Full Xcode is not needed.

```sh
git clone https://github.com/aq2208/pomacdoro.git
cd pomacdoro
./scripts/build-app.sh
cp -R dist/Pomacdoro.app ~/Applications/
open ~/Applications/Pomacdoro.app
```

The build produces a universal binary, so it runs on both Apple silicon and
Intel Macs.

Quit from the panel, or with Command-Q while the panel has focus.

### If you downloaded a prebuilt copy

The app is signed ad-hoc rather than with an Apple Developer certificate, so
macOS will refuse to open a copy that arrived over the internet. Building from
source, as above, avoids this entirely. If you would rather use a downloaded
build, clear the quarantine flag first:

```sh
xattr -dr com.apple.quarantine /path/to/Pomacdoro.app
```

## Tests

```sh
./scripts/test.sh
```

The suite covers the timer state machine and the settings store: phase
transitions, the long-rest cadence, pause and resume, expiry across a system
sleep, countdown formatting, and the UserDefaults round trip.

## How it works

The cycle is focus, short rest, focus, short rest, and so on, with a long rest
replacing every fourth short one. Each phase rolls into the next automatically,
announced by a system sound and a notification banner.

The menu bar shows a small clock face next to the remaining time. The clock is
yellow during focus and green during a rest, in a deep tone against the light
menu bar and a brighter one against the dark. A paused timer is dimmed.

The app icon, which is also what the notification banner carries, is the same
clock in white on a tomato red plate. Both come from a single drawing routine in
`ClockIcon.swift`, so the logo and the menu bar can never drift apart. The build
re-renders `Resources/AppIcon.icns` whenever that drawing changes.

Durations are set in the panel, from 1 to 180 minutes each, and are saved
immediately. A change takes effect the next time that phase comes around, so it
never cuts a running phase short. The session count under the panel covers today
only; click it to clear it.

Time is tracked as an absolute deadline rather than a decrementing counter, so
the countdown stays honest across system sleep. A phase that ran out while the
machine was asleep is detected on the next tick, and the overshoot carries into
the following phase.

## Layout

| Path | What it holds |
| --- | --- |
| `Sources/Pomacdoro/PomodoroCore.swift` | The state machine and deadline math. No AppKit, so it is directly testable. |
| `Sources/Pomacdoro/AppModel.swift` | Publishes what the UI renders, owns the tick timer, persists changes. |
| `Sources/Pomacdoro/StatusItemController.swift` | The menu bar item. |
| `Sources/Pomacdoro/PopoverView.swift` | The SwiftUI panel. |
| `Sources/Pomacdoro/Notifier.swift` | Sound and notification banner. |
| `Sources/Pomacdoro/ClockIcon.swift` | The clock drawing and the phase colours, shared by the menu bar and the logo. |
| `Sources/Pomacdoro/Settings.swift` | The UserDefaults store, under `com.local.pomacdoro`. |
| `scripts/make-icon.swift` | Renders the logo at every size and packs it into an .icns. |

## Notes on the build

The build calls `swiftc` directly rather than going through Swift Package
Manager, which keeps the Command Line Tools the only requirement. That choice
was forced rather than chosen: some Command Line Tools installations ship a
stale `PackageDescription.private.swiftinterface` that the compiler prefers over
the current one, and no package manifest will link against it. Building the two
architecture slices and joining them with `lipo` sidesteps the problem and costs
very little.

For the same reason the test suite is a plain executable with a small assertion
harness rather than XCTest or swift-testing, neither of which is reachable
without a working package manifest.

The app is signed ad-hoc. That gives the bundle the stable identity
UserNotifications wants before it will deliver a banner. macOS asks for
notification permission the first time the app launches; if it is refused or
unavailable, the app falls back to posting the banner through `osascript`, and
the sound plays either way.

## License

MIT. See [LICENSE](LICENSE).
