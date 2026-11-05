#!/usr/bin/env bash
# Captures App Store screenshots from the iOS Simulator and composes marketing frames.
#
#   Scripts/generate-appstore-media.sh <path/to/DashCast.app> [simulator-udid]
#
# - Boots the simulator (default: newest available "iPhone … Pro Max", which is 6.9" / 1320x2868)
# - Installs the app, cleans the status bar, grants location, sets a demo GPS position
# - Launches the app once per screen with `-seedDemoData` + a screen-selecting launch argument
# - Saves raw captures to AppStoreMedia/raw/ and composes framed images via
#   Scripts/compose-appstore-frames.py into:
#     AppStoreMedia/6.9-inch_1320x2868/        (framed marketing images)
#     AppStoreMedia/6.5-inch_1284x2778/
#     AppStoreMedia/*_plain/                   (unframed, exact store size)
# Runs on macOS with Xcode (used by .github/workflows/appstore-media.yml).
set -euo pipefail
cd "$(dirname "$0")/.."

APP=${1:?usage: $0 <DashCast.app> [udid]}
UDID=${2:-}
BUNDLE_ID=com.xanderco.dashcast
OUT=AppStoreMedia
RAW=$OUT/raw

if [[ -z "$UDID" ]]; then
  UDID=$(xcrun simctl list devices available -j | python3 -c "
import json, sys
d = json.load(sys.stdin)['devices']
c = [(rt, x) for rt, xs in d.items() if 'iOS' in rt for x in xs if 'Pro Max' in x['name']]
c.sort(key=lambda t: (t[0], t[1]['name']))
print(c[-1][1]['udid'])")
fi
echo "== Using simulator $UDID =="
xcrun simctl list devices | grep "$UDID" || true

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl ui "$UDID" appearance dark || true
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 || true
xcrun simctl location "$UDID" set 37.7793,-122.4193 || true

xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
xcrun simctl privacy "$UDID" grant location "$BUNDLE_ID" || true
xcrun simctl privacy "$UDID" grant location-always "$BUNDLE_ID" || true
xcrun simctl privacy "$UDID" grant photos "$BUNDLE_ID" || true

rm -rf "$RAW" "$OUT"/*-inch_*
mkdir -p "$RAW"

# name|launch arguments
# Classic UI. Launch args are read by AppState / ScreenshotLaunch / CastHomeView.
SCREENS=(
  "01_cast|-initialTab cast"
  "02_paywall|-initialTab cast -showPaywall"
  "03_sources|-initialTab cast -showMediaSources"
  "04_player|-initialTab cast -playDemoVideo"
  "05_drive|-initialTab drive"
  "06_widgets|-showWidgetEditor"
  "07_onboarding|-showOnboarding"
)

for entry in "${SCREENS[@]}"; do
  name=${entry%%|*}
  args=${entry#*|}
  echo "-> $name ($args)"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  # shellcheck disable=SC2086
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -seedDemoData $args >/dev/null
  sleep "${SCREENSHOT_DELAY:-8}"
  xcrun simctl io "$UDID" screenshot --type=png "$RAW/$name.png"
done
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true

python3 Scripts/compose-appstore-frames.py "$RAW" "$OUT"

echo "== App Store media generated =="
find "$OUT" -name '*.png' -newer "$0" | sort
