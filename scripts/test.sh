#!/bin/bash
# Compiles the timer core together with the test suite and runs it.
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p build

swiftc -O \
    -target arm64-apple-macos13.0 \
    -o build/PomacdoroTests \
    Sources/Pomacdoro/PomodoroCore.swift \
    Sources/Pomacdoro/Settings.swift \
    Tests/PomacdoroTests/TestHarness.swift \
    Tests/PomacdoroTests/main.swift

set +e
./build/PomacdoroTests
status=$?
set -e

# The suite exercises the real UserDefaults API, which lands in its own domain.
defaults delete PomacdoroTests >/dev/null 2>&1 || true
exit $status
