import Foundation

/// A minimal test harness.
///
/// The Command Line Tools on this machine ship a stale PackageDescription interface
/// that stops SwiftPM from compiling any manifest, so `swift test` is unavailable and
/// the suite is a plain executable instead. Everything here is standard Swift.
final class TestRunner {
    private var failures: [String] = []
    private var checks = 0
    private var currentTest = ""

    func test(_ name: String, _ body: () throws -> Void) {
        currentTest = name
        do {
            try body()
        } catch {
            failures.append("\(name): threw \(error)")
        }
    }

    func expect(
        _ condition: Bool,
        _ message: @autoclosure () -> String,
        line: Int = #line
    ) {
        checks += 1
        guard !condition else { return }
        failures.append("\(currentTest) (line \(line)): \(message())")
    }

    func expectEqual<T: Equatable>(
        _ actual: T,
        _ expected: T,
        _ label: String = "",
        line: Int = #line
    ) {
        checks += 1
        guard actual != expected else { return }
        let prefix = label.isEmpty ? "" : "\(label): "
        failures.append("\(currentTest) (line \(line)): \(prefix)expected \(expected), got \(actual)")
    }

    /// Prints the result and returns the process exit code.
    func finish() -> Int32 {
        if failures.isEmpty {
            print("PASSED \(checks) checks")
            return 0
        }
        print("FAILED \(failures.count) of \(checks) checks")
        for failure in failures {
            print("  - \(failure)")
        }
        return 1
    }
}
