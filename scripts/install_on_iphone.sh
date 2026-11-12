#!/bin/zsh
# Builds Baroque, signs it with your team, and installs and opens it on your iPhone, without clicking through Xcode.
# Needs: your Apple ID signed in under Xcode > Settings > Accounts, your team in Config/Local.xcconfig (see
# Config/Local.example.xcconfig), and the phone unlocked and either plugged in or on the same Wi-Fi.
# Run: scripts/install_on_iphone.sh            PHONE="My iPhone" picks a phone when several are paired (its name as
#                                              xcrun devicectl list devices shows it, or its UDID).
# It builds Release (optimised; SwiftUI is much smoother than in Debug). CONFIGURATION=Debug keeps the debug launch
# arguments (-scrollTo, -saveIcons, …) that scripts/mirror_setup.py uses.
# It builds for the phone itself first, so Xcode can register a phone that's new to your team. When xcodebuild can't
# reach the phone (locked, asleep, still preparing), it builds for any iPhone instead and installs that.
# Check which phone it would pick, with no phone and no build: scripts/install_on_iphone.sh --pick LISTING.json [NAME]
# (LISTING.json from xcrun devicectl list devices --json-output LISTING.json).
set -euo pipefail
cd "$(dirname "$0")/.."

# pick_phone LISTING [NAME]: prints "UDID<tab>name" of the iPhone to install on, from devicectl's JSON listing: the one
# named NAME (or with that UDID), otherwise the first paired iPhone that can be reached, one with a connection open
# first. Says why and fails when there's none.
pick_phone() {
    /usr/bin/python3 -I - "$1" "${2:-}" <<'PY'
import json, sys

listing, wanted = sys.argv[1], sys.argv[2]
try:
    with open(listing) as f:
        devices = json.load(f)["result"]["devices"]
except (OSError, ValueError, KeyError, TypeError) as e:
    sys.exit(f"Couldn't read the list of devices ({e}).")
phones = []
for d in devices:
    hw, conn = d.get("hardwareProperties", {}), d.get("connectionProperties", {})
    if hw.get("deviceType") != "iPhone" or hw.get("reality", "physical") != "physical":
        continue
    phones.append({"name": d.get("deviceProperties", {}).get("name", ""), "udid": hw.get("udid") or d.get("identifier", ""),
                   "id": d.get("identifier", ""), "paired": conn.get("pairingState") == "paired",
                   # "unavailable" (or no state at all): not reachable now; "disconnected" is reachable, no tunnel yet.
                   "reachable": conn.get("tunnelState", "unavailable") != "unavailable",
                   "connected": conn.get("tunnelState") == "connected"})
if wanted:
    phones = [p for p in phones if wanted in (p["name"], p["udid"], p["id"])]
    if not phones:
        sys.exit(f"No iPhone called {wanted!r} is known to this Mac (see xcrun devicectl list devices).")
reachable = [p for p in phones if p["reachable"]]
paired = sorted((p for p in reachable if p["paired"]), key=lambda p: not p["connected"])
if paired:
    print(f"{paired[0]['udid']}\t{paired[0]['name']}")
elif reachable:
    sys.exit(f"{reachable[0]['name']} isn't paired with this Mac yet: unlock it, tap Trust (Trust This Computer), "
             "enter the passcode, and run this again.")
elif wanted:
    sys.exit(f"{phones[0]['name']} can't be reached: unlock it and plug it in, or put it on this Mac's Wi-Fi.")
else:
    sys.exit("No iPhone connected: unlock it and plug it in (or set PHONE to its name in xcrun devicectl list devices).")
PY
}

if [[ "${1:-}" == "--pick" ]]; then
    pick_phone "${2:?usage: install_on_iphone.sh --pick LISTING.json [NAME]}" "${3:-}"
    exit
fi

# The team: ten capitals and digits, and not the example's placeholder.
TEAM=$(sed -n 's/^DEVELOPMENT_TEAM *= *\([A-Z0-9]*\).*/\1/p' Config/Local.xcconfig 2>/dev/null | head -n 1 || true)
if [[ -z "$TEAM" ]]; then
    echo "Put your team ID in Config/Local.xcconfig first (copy Config/Local.example.xcconfig)."
    exit 1
elif [[ "$TEAM" == ABCDE12345 || ${#TEAM} -ne 10 ]]; then
    echo "Config/Local.xcconfig has $TEAM, which isn't your team ID: put yours in (Xcode > Settings > Accounts)."
    exit 1
fi

mkdir -p build
xcrun devicectl list devices --json-output build/devices.json > /dev/null 2>&1 || true
PICKED=$(pick_phone build/devices.json "${PHONE:-}") || exit 1
UDID=${PICKED%%$'\t'*}
NAME=${PICKED#*$'\t'}
CONFIGURATION=${CONFIGURATION:-Release}
APP=build/device/Build/Products/$CONFIGURATION-iphoneos/Baroque.app
LOG=build/device-build.log

build_for() {   # build_for DESTINATION [FLAGS…]: the log goes to $LOG
    xcodebuild -project Baroque.xcodeproj -scheme Baroque -configuration "$CONFIGURATION" \
        -destination "$1" -derivedDataPath build/device -allowProvisioningUpdates "${@:2}" build > "$LOG" 2>&1
}

build_failed() {
    grep -E "error:" "$LOG" | sort -u || true
    echo "Build failed; the full log is $LOG."
    if grep -q "pairing is in progress" "$LOG"; then
        echo "Tap Trust on the phone (Trust This Computer), enter the passcode, and run this again."
    elif grep -q "application-groups" "$LOG"; then
        echo "The App Group isn't in the profile yet: in Xcode, open Signing & Capabilities for Baroque and"
        echo "BaroqueWidgetExtension and tick the App Group once (Xcode registers it; the command line can't)."
    elif grep -qE "doesn.t include the currently selected device|[Nn]o devices (are )?registered" "$LOG"; then
        echo "$REGISTER_HINT"
    fi
    exit 1
}

REGISTER_HINT="If this phone is new to your team, open Xcode once and press Run on it to register it."
FELL_BACK=0
echo "Building for $NAME…"
# For the phone itself first: that's how a phone new to the team gets registered and added to the profile.
if ! build_for "id=$UDID" -allowProvisioningDeviceRegistration; then
    if grep -q "pairing is in progress" "$LOG"; then
        build_failed
    elif grep -qE "Unable to find a (destination|device) matching|Timed out waiting for .*destination|is not connected|Device is busy|Failed to prepare (the )?device" "$LOG"; then
        echo "xcodebuild couldn't reach $NAME, so this builds for any iPhone instead."
        echo "$REGISTER_HINT"
        FELL_BACK=1
        build_for "generic/platform=iOS" || build_failed
    else
        build_failed
    fi
fi

echo "Installing…"
xcrun devicectl device install app --device "$UDID" "$APP" || {
    (( FELL_BACK )) && echo "$REGISTER_HINT"
    exit 1
}
echo "Opening… (the first time, trust the developer on the phone: Settings > General > VPN & Device Management)"
xcrun devicectl device process launch --device "$UDID" "$(defaults read "$PWD/$APP/Info" CFBundleIdentifier)" || true
