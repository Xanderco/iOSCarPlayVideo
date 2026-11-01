#!/usr/bin/env bash
set -euo pipefail

echo "== Generating App Store Media (1290x2796) =="
mkdir -p AppStoreMedia

# Switch tabs and capture screenshots
echo "-> Capturing Tab 1: Cast"
orca emulator tap 0.10 0.95 --json >/dev/null 2>&1 || true
sleep 1
xcrun simctl io booted screenshot AppStoreMedia/Raw_1_Cast.png

echo "-> Capturing Tab 2: Drive"
orca emulator tap 0.30 0.95 --json >/dev/null 2>&1 || true
sleep 1
xcrun simctl io booted screenshot AppStoreMedia/Raw_2_Drive.png

echo "-> Capturing Tab 3: Territory"
orca emulator tap 0.50 0.95 --json >/dev/null 2>&1 || true
sleep 1
xcrun simctl io booted screenshot AppStoreMedia/Raw_3_Territory.png

echo "-> Capturing Tab 4: Widgets"
orca emulator tap 0.70 0.95 --json >/dev/null 2>&1 || true
sleep 1
xcrun simctl io booted screenshot AppStoreMedia/Raw_4_Widgets.png

echo "-> Capturing Tab 5: Sounds"
orca emulator tap 0.90 0.95 --json >/dev/null 2>&1 || true
sleep 1
xcrun simctl io booted screenshot AppStoreMedia/Raw_5_Sounds.png

# Format each to App Store 1290x2796 using sips
for f in AppStoreMedia/Raw_*.png; do
  out="${f/Raw_/Screenshot_}"
  sips -z 2796 1290 "$f" --out "$out" >/dev/null 2>&1
done

echo "== App Store Media Generated Successfully =="
ls -lh AppStoreMedia/Screenshot_*.png
