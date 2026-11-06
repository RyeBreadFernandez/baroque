#!/usr/bin/env bash
# Builds Baroque, puts the widgets on a simulator home screen with XCUITest (SpringBoard automation),
# and captures app + widget screenshots in the fresh (-resetData), cached (-seedDemoData) and
# fake-token (401) states into screenshots/.
#
# Usage:
#   scripts/capture_screenshots.sh [SIM_UDID] [DERIVED_DATA_PATH]
#
# Environment (all optional):
#   SIM_UDID      simulator to use        (default: the iPhone 17 below; arg 1 wins)
#   DERIVED_DATA  derived data folder     (default: <repo>/build; arg 2 wins)
#   SHOT_DIR      where PNGs are written  (default: <repo>/screenshots)
#   ERASE=0       keep the simulator as is (default 1: erase it first for a clean home screen)
#   SKIP_BUILD=1  reuse the existing build-for-testing products
#   REGEN=1       run `xcodegen generate` first (needed after adding files to BaroqueUITests/)
#   ONLY=name     run one test, e.g. ONLY=test30_cachedState (default: the whole BaroqueScreenshotTests class)
#   WIDGET_WAIT   seconds to let widgets refresh before a home screen shot (default 15)
#
# Example for another simulator and derived data folder:
#   scripts/capture_screenshots.sh 1234ABCD-... /tmp/baroque-dd
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UDID="${1:-${SIM_UDID:-8FF748F6-7085-4B3E-967C-39582EFD1EB2}}"
DD="${2:-${DERIVED_DATA:-$ROOT/build}}"
SHOT_DIR="${SHOT_DIR:-$ROOT/screenshots}"
ERASE="${ERASE:-1}"
WIDGET_WAIT="${WIDGET_WAIT:-15}"
DEST="platform=iOS Simulator,id=$UDID"
TESTS="BaroqueUITests/BaroqueScreenshotTests${ONLY:+/$ONLY}"
LOG_DIR="$DD/capture-logs"

cd "$ROOT"
mkdir -p "$SHOT_DIR" "$LOG_DIR"
# The test runner does not share this working directory, so hand it an absolute path.
SHOT_DIR="$(cd "$SHOT_DIR" && pwd)"
echo "==> Simulator $UDID, derived data $DD, screenshots -> $SHOT_DIR"

if ! xcrun simctl list devices | grep -q "$UDID"; then
  echo "error: no simulator with UDID $UDID (see: xcrun simctl list devices)" >&2
  exit 1
fi

if [[ "${REGEN:-0}" == "1" ]]; then
  echo "==> xcodegen generate"
  xcodegen generate
fi

if [[ "$ERASE" == "1" ]]; then
  echo "==> Erasing simulator for a clean home screen"
  xcrun simctl shutdown "$UDID" 2>/dev/null || true
  xcrun simctl erase "$UDID"
fi

echo "==> Booting"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
open -a Simulator --args -CurrentDeviceUDID "$UDID" 2>/dev/null || true

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  echo "==> Building (log: $LOG_DIR/build.log)"
  if ! xcodebuild -project Baroque.xcodeproj -scheme Baroque -destination "$DEST" -derivedDataPath "$DD" \
       build-for-testing >"$LOG_DIR/build.log" 2>&1; then
    grep -E "error:" "$LOG_DIR/build.log" | head -20 >&2 || true
    echo "error: build failed, see $LOG_DIR/build.log" >&2
    exit 1
  fi
fi

APP="$DD/Build/Products/Debug-iphonesimulator/Baroque.app"
echo "==> Installing $APP"
xcrun simctl install "$UDID" "$APP"

echo "==> Running UI tests: $TESTS (log: $LOG_DIR/test.log, takes ~10-12 min for the full class)"
set +e
TEST_RUNNER_TERRA_SCREENSHOT_DIR="$SHOT_DIR" TEST_RUNNER_TERRA_WIDGET_WAIT="$WIDGET_WAIT" \
  xcodebuild -project Baroque.xcodeproj -scheme Baroque -destination "$DEST" -derivedDataPath "$DD" \
  test-without-building -only-testing:"$TESTS" >"$LOG_DIR/test.log" 2>&1
STATUS=$?
set -e

grep -E "Test Case .*(passed|failed)|error: |TERRA-TEXTS|TERRA-ARROW|TERRA-PAGES" "$LOG_DIR/test.log" || true
echo "==> Screenshots:"
ls -1 "$SHOT_DIR"/*.png 2>/dev/null || echo "(none)"
if [[ $STATUS -ne 0 ]]; then
  echo "Some UI tests failed (exit $STATUS); see $LOG_DIR/test.log and the .xcresult under $DD/Logs/Test" >&2
fi
exit $STATUS
