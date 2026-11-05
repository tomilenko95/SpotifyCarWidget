#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate
SCHEME=SpotifyCarWidget
CONFIGURATION=Release
if [[ "${PERSONAL_DEMO:-0}" == "1" ]]; then SCHEME=SpotifyCarWidgetPersonal; CONFIGURATION=Personal; fi
xcodebuild build -project SpotifyCarWidget.xcodeproj -scheme "$SCHEME" -configuration "$CONFIGURATION" \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/Device CODE_SIGNING_ALLOWED=NO
mkdir -p build/unsigned/Payload
ditto "build/Device/Build/Products/$CONFIGURATION-iphoneos/SpotifyCarWidget.app" build/unsigned/Payload/SpotifyCarWidget.app
(cd build/unsigned && zip -qr ../UNSIGNED-requires-signing.ipa Payload)
