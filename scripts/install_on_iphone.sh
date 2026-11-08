#!/bin/zsh
# Builds Baroque, signs it with your team, and installs and opens it on your iPhone, without clicking through Xcode.
# Needs: your Apple ID signed in under Xcode > Settings > Accounts, your team in Config/Local.xcconfig (see
# Config/Local.example.xcconfig), and the phone unlocked and either plugged in or on the same Wi-Fi.
# Run: scripts/install_on_iphone.sh            PHONE="My iPhone" picks a phone when several are paired.
# It builds Release (optimised; SwiftUI is much smoother than in Debug). CONFIGURATION=Debug keeps the debug launch
# arguments (-scrollTo, -saveIcons, …) that scripts/mirror_setup.py uses.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! grep -qs "^DEVELOPMENT_TEAM *= *[A-Z0-9]" Config/Local.xcconfig; then
    echo "Put your team ID in Config/Local.xcconfig first (copy Config/Local.example.xcconfig)."
    exit 1
fi
# The phone: as named, or the first paired iPhone that's connected.
PHONE=${PHONE:-$(xcrun devicectl list devices 2>/dev/null | awk '/iPhone/ && /available/ {print $1; exit}')}
if [[ -z "$PHONE" ]]; then
    echo "No iPhone connected: unlock it and plug it in (or set PHONE to its name in xcrun devicectl list devices)."
    exit 1
fi
CONFIGURATION=${CONFIGURATION:-Release}
APP=build/device/Build/Products/$CONFIGURATION-iphoneos/Baroque.app
mkdir -p build

echo "Building for $PHONE…"
xcodebuild -project Baroque.xcodeproj -scheme Baroque -configuration "$CONFIGURATION" \
    -destination "platform=iOS,name=$PHONE" -derivedDataPath build/device \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration build > build/device-build.log 2>&1 || {
    grep -E "error:" build/device-build.log | sort -u
    echo "Build failed; the full log is build/device-build.log."
    if grep -q "pairing is in progress" build/device-build.log; then
        echo "Tap Trust on the phone (Trust This Computer), enter the passcode, and run this again."
    elif grep -q "application-groups" build/device-build.log; then
        echo "The App Group isn't in the profile yet: in Xcode, open Signing & Capabilities for Baroque and"
        echo "BaroqueWidgetExtension and tick the App Group once (Xcode registers it; the command line can't)."
    fi
    exit 1
}

echo "Installing…"
xcrun devicectl device install app --device "$PHONE" "$APP"
echo "Opening… (the first time, trust the developer on the phone: Settings > General > VPN & Device Management)"
xcrun devicectl device process launch --device "$PHONE" "$(defaults read "$PWD/$APP/Info" CFBundleIdentifier)" || true
