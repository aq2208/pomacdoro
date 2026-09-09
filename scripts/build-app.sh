#!/bin/bash
# Compiles the app and assembles dist/Pomacdoro.app.
#
# It calls swiftc directly rather than going through Swift Package Manager, so
# the Command Line Tools are the only requirement. Full Xcode is not needed.
set -euo pipefail

cd "$(dirname "$0")/.."

APP="dist/Pomacdoro.app"
MACOS_MIN="13.0"
ARCHS="arm64 x86_64"   # universal, so the app runs on Apple silicon and Intel

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build

# The logo is drawn from the same clock the menu bar uses, so it is re-rendered
# whenever that drawing changes.
if [ ! -f Resources/AppIcon.icns ] \
   || [ Sources/Pomacdoro/ClockIcon.swift -nt Resources/AppIcon.icns ] \
   || [ scripts/make-icon.swift -nt Resources/AppIcon.icns ]; then
    echo "Rendering app icon..."
    swiftc -O -parse-as-library \
        -target "arm64-apple-macos$MACOS_MIN" \
        -o build/make-icon \
        Sources/Pomacdoro/PomodoroCore.swift \
        Sources/Pomacdoro/ClockIcon.swift \
        scripts/make-icon.swift
    ./build/make-icon Resources/AppIcon.icns
fi

echo "Compiling..."
slices=""
for arch in $ARCHS; do
    swiftc -O \
        -target "$arch-apple-macos$MACOS_MIN" \
        -o "build/Pomacdoro-$arch" \
        Sources/Pomacdoro/*.swift
    slices="$slices build/Pomacdoro-$arch"
done

# shellcheck disable=SC2086
lipo -create $slices -output "$APP/Contents/MacOS/Pomacdoro"
lipo -info "$APP/Contents/MacOS/Pomacdoro"

cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Copied files can carry extended attributes that codesign rejects outright.
xattr -cr "$APP"
# On a synced folder, xattr -c leaves com.apple.FinderInfo on the bundle
# directory itself, and codesign refuses to sign anything carrying it.
xattr -d com.apple.FinderInfo "$APP" 2>/dev/null || true

# An ad-hoc signature is what lets the bundle hold a stable identity, which
# UserNotifications requires before it will deliver a banner.
echo "Signing..."
codesign --force --deep --sign - --identifier com.local.pomacdoro "$APP"
codesign --verify --strict --verbose=1 "$APP"

echo
echo "Built $APP"
echo "Run it with:      open $APP"
echo "Install it with:  cp -R $APP ~/Applications/"
