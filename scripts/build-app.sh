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

# The bundle is assembled and signed in a temporary directory, then moved into
# place. On a folder synced by iCloud Drive or similar, the sync agent stamps
# com.apple.FinderInfo onto a newly appearing app bundle, and codesign refuses
# to sign anything carrying that attribute. Staging outside the synced tree
# avoids the race rather than trying to win it.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
STAGED_APP="$STAGE/Pomacdoro.app"

mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources" build

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
lipo -create $slices -output "$STAGED_APP/Contents/MacOS/Pomacdoro"
lipo -info "$STAGED_APP/Contents/MacOS/Pomacdoro"

cp Resources/Info.plist "$STAGED_APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$STAGED_APP/Contents/Resources/AppIcon.icns"

# Copied files can still carry extended attributes that codesign rejects.
xattr -cr "$STAGED_APP"

# An ad-hoc signature is what lets the bundle hold a stable identity, which
# UserNotifications requires before it will deliver a banner.
echo "Signing..."
codesign --force --deep --sign - --identifier com.local.pomacdoro "$STAGED_APP"
codesign --verify --strict --verbose=1 "$STAGED_APP"

rm -rf "$APP"
mkdir -p "$(dirname "$APP")"
ditto "$STAGED_APP" "$APP"
codesign --verify --verbose=1 "$APP"

echo
echo "Built $APP"
echo "Run it with:      open $APP"
echo "Install it with:  cp -R $APP ~/Applications/"
