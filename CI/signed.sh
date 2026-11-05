#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${APP_BUNDLE_ID:?Set your registered main bundle ID in Codemagic}"
: "${APP_GROUP:?Set the registered App Group}"
: "${OAUTH_HOST:?Set the associated HTTPS host}"
: "${SPOTIFY_CLIENT_ID:?Set the public Spotify Client ID}"
: "${DEVELOPMENT_TEAM:?Set Apple Developer Program team ID}"
python3 CI/configure.py
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate
keychain initialize
keychain add-certificates
xcode-project use-profiles
# use-profiles selects matching profiles for BOTH targets and writes export_options.plist.
xcode-project build-ipa --project SpotifyCarWidget.xcodeproj --scheme SpotifyCarWidget \
  --archive-directory build/archive --ipa-directory build/ipa
