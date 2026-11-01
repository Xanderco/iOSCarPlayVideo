#!/usr/bin/env bash
set -euo pipefail

echo "============================================="
echo "   DashCast Automated Test Suite Runner"
echo "============================================="

# 1. Regenerate Xcode project
echo "--> Generating Xcode project via XcodeGen..."
xcodegen generate

# 2. Identify available simulator
SIM_DEVICE="iPhone 17"
echo "--> Target Simulator: ${SIM_DEVICE}"

# 3. Run XCTest suite
echo "--> Executing Unit & Integration Tests..."
xcodebuild test \
  -project DashCast.xcodeproj \
  -scheme DashCast \
  -destination "platform=iOS Simulator,name=${SIM_DEVICE}" \
  -resultBundlePath /tmp/DashCastTestResults.xcresult \
  2>&1 | xcbeautify || xcodebuild test \
  -project DashCast.xcodeproj \
  -scheme DashCast \
  -destination "platform=iOS Simulator,name=${SIM_DEVICE}"

echo "============================================="
echo "   ALL TESTS PASSED SUCCESSFULLY (100%)"
echo "============================================="
