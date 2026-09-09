import SwiftUI

/// The panel shown when the menu bar item is clicked: the countdown, transport
/// controls, the three durations, and today's session count.
struct PopoverView: View {
    @ObservedObject var model: AppModel
    var onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            durations
            Divider()
            footer
        }
        .frame(width: 260)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Text(model.phase.label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(accent)

            Text(model.countdown)
                .font(.system(size: 44, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                Button(model.primaryButtonTitle) { model.toggle() }
                    .keyboardShortcut(.space, modifiers: [])
                    .buttonStyle(.borderedProminent)
                Button("Reset") { model.reset() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    private var durations: some View {
        VStack(spacing: 8) {
            minuteRow("Focus", value: $model.focusMinutes)
            minuteRow("Rest", value: $model.shortRestMinutes)
            minuteRow("Long rest", value: $model.longRestMinutes)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func minuteRow(_ label: String, value: Binding<Int>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
            Spacer()
            // Stepper edits the same value the text field shows, and the range keeps
            // either route from producing a zero-length phase.
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 46)
            Text("min")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Stepper("", value: value, in: Settings.minutesRange)
                .labelsHidden()
        }
    }

    private var footer: some View {
        HStack {
            Button {
                model.resetSessions()
            } label: {
                Text("Sessions today: \(model.sessions)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Click to reset the count")

            Spacer()

            Button("Quit", action: onQuit)
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var accent: Color {
        model.phase.isRest ? .green : .red
    }
}
