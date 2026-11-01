#!/usr/bin/env bash
set -euo pipefail

echo "============================================="
echo "   DashCast Application Builder"
echo "============================================="

# 1. Regenerate Xcode project
xcodegen generate

# 2. Build for iOS Simulator
echo "--> Building DashCast for iOS Simulator..."
xcodebuild build \
  -project DashCast.xcodeproj \
  -scheme DashCast \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -configuration Debug

echo "============================================="
echo "   BUILD SUCCEEDED"
echo "============================================="
