#!/bin/sh
# Builds build/JamTap.app from the Swift package. With "install" as argument, also copies it to /Applications.
set -eu
cd "$(dirname "$0")/.."
swift build -c release
app=build/JamTap.app
mkdir -p "$app/Contents/MacOS"
cp .build/release/JamTap "$app/Contents/MacOS/JamTap"
cp Resources/Info.plist "$app/Contents/Info.plist"
# Ad-hoc signature ("-"): no developer certificate needed. macOS ties the audio-capture permission
# to this signature, so it asks again after each rebuild.
# Finder adds extended attributes to an app it has opened, and codesign refuses to sign over them.
xattr -cr "$app"
codesign --force --sign - "$app"
echo "Built $app"
if [ "${1:-}" = install ]; then
  pkill -x JamTap 2>/dev/null || true
  ditto "$app" /Applications/JamTap.app
  echo "Installed /Applications/JamTap.app"
fi
