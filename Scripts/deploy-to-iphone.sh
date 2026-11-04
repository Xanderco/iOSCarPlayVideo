#!/usr/bin/env bash
set -euo pipefail

echo "=================================================="
echo "   DashCast Physical iPhone Deployment & Notify"
echo "=================================================="

REPO_DIR="/Users/xanderco/orca/workspaces/iOSCarPlayVideo/Paperclip-Answers"
cd "${REPO_DIR}"

# 1. Detect Physical Device
DEVICE_ID=$(xcrun devicectl list devices 2>&1 | grep "physical" | awk '{print $3}' | head -n 1 || true)

if [ -z "${DEVICE_ID}" ]; then
  # Fallback to known Xander iPhone UDID
  DEVICE_ID="00008140-001A588624E3C01C"
fi

DEVICE_NAME=$(xcrun devicectl list devices 2>&1 | grep "${DEVICE_ID}" | awk -F'   ' '{print $1}' | head -n 1 || echo "Xander iPhone")

echo "--> Target Physical Device: ${DEVICE_NAME} (${DEVICE_ID})"

# 2. Build for Physical iOS Target
echo "--> Compiling DashCast for physical device..."
xcodebuild -project DashCast.xcodeproj \
  -scheme DashCast \
  -destination "platform=iOS,id=${DEVICE_ID}" \
  -configuration Debug \
  build > /tmp/dashcast_device_build.log 2>&1 || {
    echo "❌ Build failed! Log tail:"
    tail -n 25 /tmp/dashcast_device_build.log
    exit 1
}

APP_PATH="/Users/xanderco/Library/Developer/Xcode/DerivedData/DashCast-awdvbdxlbostxnfvdxbiljsbqgsx/Build/Products/Debug-iphoneos/DashCast.app"

if [ ! -d "${APP_PATH}" ]; then
  echo "❌ Error: App bundle not found at ${APP_PATH}"
  exit 1
fi

echo "✅ Build succeeded: ${APP_PATH}"

# 3. Install App on Physical iPhone
echo "--> Installing DashCast on ${DEVICE_NAME}..."
INSTALL_OUTPUT=$(xcrun devicectl device install app --device "${DEVICE_ID}" "${APP_PATH}" 2>&1)
echo "${INSTALL_OUTPUT}"

echo "✅ DashCast successfully deployed to ${DEVICE_NAME}!"

# 4. Notification Dispatch (Pushover / Home Assistant)
FEATURE_SUMMARY="${1:-"New DashCast build deployed to your iPhone with full CarPlay scene and in-car widgets ready to test."}"
COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "latest")

echo "--> Sending deployment notification..."

# Check for Pushover keys in config
PUSHOVER_TOKEN="${PUSHOVER_API_TOKEN:-""}"
PUSHOVER_USER="${PUSHOVER_USER_KEY:-""}"

if [ -f "${HOME}/.config/opencode/pushover.json" ]; then
  PUSHOVER_TOKEN=$(python3 -c "import json; print(json.load(open('${HOME}/.config/opencode/pushover.json')).get('token', ''))" 2>/dev/null || true)
  PUSHOVER_USER=$(python3 -c "import json; print(json.load(open('${HOME}/.config/opencode/pushover.json')).get('user', ''))" 2>/dev/null || true)
fi

if [ -n "${PUSHOVER_TOKEN}" ] && [ -n "${PUSHOVER_USER}" ]; then
  echo "--> Dispatching notification via Pushover..."
  curl -s \
    --form-string "token=${PUSHOVER_TOKEN}" \
    --form-string "user=${PUSHOVER_USER}" \
    --form-string "title=🚗 DashCast Build Deployed (commit ${COMMIT_HASH})" \
    --form-string "message=${FEATURE_SUMMARY}" \
    --form-string "url=http://100.66.253.3:3100/CARAA/dashboard" \
    --form-string "url_title=Open Paperclip Dashboard" \
    --form-string "priority=1" \
    https://api.pushover.net/1/messages.json > /dev/null || true
  echo "✅ Pushover notification sent."
else
  echo "ℹ️ Note: To send direct Pushover alerts, save your keys in ~/.config/opencode/pushover.json or set PUSHOVER_API_TOKEN and PUSHOVER_USER_KEY."
fi

echo "=================================================="
echo "   DEPLOYMENT CYCLE COMPLETED"
echo "=================================================="
