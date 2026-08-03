#!/usr/bin/env bash
#
# build.sh — one command to generate, build, and (optionally) run AQE Field
# in the iOS Simulator. Run from the AQEField/ directory on a Mac with Xcode.
#
#   ./build.sh              generate project + build for the Simulator
#   ./build.sh run          …then boot a simulator, install, and launch it
#
# Prereqs (see README for install steps):
#   - Xcode (full app, from the Mac App Store) + one-time: sudo xcodebuild -license accept
#   - XcodeGen:  brew install xcodegen

set -euo pipefail

SCHEME="AQEField"
BUNDLE_ID="com.aqe.field"
SIM_DEVICE="${SIM_DEVICE:-iPhone 16}"   # override: SIM_DEVICE="iPhone 15 Pro" ./build.sh

cd "$(dirname "$0")"

echo "==> Generating Xcode project from project.yml"
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen not found. Install it with:  brew install xcodegen" >&2
  exit 1
fi
xcodegen generate

echo "==> Building $SCHEME for the Simulator"
xcodebuild \
  -project "AQEField.xcodeproj" \
  -scheme "$SCHEME" \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,name=$SIM_DEVICE" \
  -configuration Debug \
  build | tail -25

echo "==> Build succeeded."

if [ "${1:-}" != "run" ]; then
  echo "Open it in Xcode with:  open AQEField.xcodeproj   (then press ▶ with your iPhone plugged in)"
  exit 0
fi

echo "==> Booting Simulator: $SIM_DEVICE"
xcrun simctl boot "$SIM_DEVICE" 2>/dev/null || true
open -a Simulator

APP_PATH=$(xcodebuild -project AQEField.xcodeproj -scheme "$SCHEME" -sdk iphonesimulator \
  -configuration Debug -showBuildSettings 2>/dev/null \
  | awk '/ BUILT_PRODUCTS_DIR /{d=$3} / FULL_PRODUCT_NAME /{n=$3} END{print d"/"n}')

echo "==> Installing $APP_PATH"
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted "$BUNDLE_ID"
echo "==> Launched. Screenshot with:  xcrun simctl io booted screenshot aqe.png"
