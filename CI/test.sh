#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
node CI/validate.cjs
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate --spec project.yml
# Choose an installed iOS 26+ simulator, not a hardcoded model that may be absent on CI.
DEST_ID=$(python3 CI/select-simulator.py)
xcodebuild test -project SpotifyCarWidget.xcodeproj -scheme SpotifyCarWidget \
  -destination "platform=iOS Simulator,id=$DEST_ID" \
  -derivedDataPath build/DerivedData -resultBundlePath build/Tests.xcresult \
  CODE_SIGNING_ALLOWED=NO
xcodebuild build -project SpotifyCarWidget.xcodeproj -scheme SpotifyCarWidgetPersonal \
  -configuration Personal -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/Personal CODE_SIGNING_ALLOWED=NO
xcodebuild build -project SpotifyCarWidget.xcodeproj -scheme SpotifyCarWidgetPersonalSpotify \
  -configuration PersonalSpotify -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/PersonalSpotify CODE_SIGNING_ALLOWED=NO
PERSONAL_APP=build/Personal/Build/Products/Personal-iphonesimulator/SpotifyCarWidget.app
APP_ID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$PERSONAL_APP/Info.plist")
xcrun simctl bootstatus "$DEST_ID" -b
xcrun simctl terminate "$DEST_ID" "$APP_ID" >/dev/null 2>&1 || true
xcrun simctl install "$DEST_ID" "$PERSONAL_APP"
xcrun simctl ui "$DEST_ID" appearance dark
xcrun simctl launch "$DEST_ID" "$APP_ID"
# Allow the first SwiftUI frame and its local demo snapshot to settle before capturing.
sleep 3
xcrun simctl io "$DEST_ID" screenshot build/CarWidget-iPhone-Simulator.png
ditto -c -k --sequesterRsrc --keepParent build/DerivedData/Build/Products/Debug-iphonesimulator/SpotifyCarWidget.app build/Simulator.app.zip
