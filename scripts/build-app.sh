#!/bin/sh
# Builds build/JamTap.app from the Swift package. With "install" as argument, also copies it to /Applications.
set -eu
cd "$(dirname "$0")/.."
swift build -c release
app=build/JamTap.app
mkdir -p "$app/Contents/MacOS"
cp .build/release/JamTap "$app/Contents/MacOS/JamTap"
cp Resources/Info.plist "$app/Contents/Info.plist"

# App icon (shown in notifications and Finder): the app draws it, sips scales it, iconutil packs it.
iconset=build/AppIcon.iconset
mkdir -p "$iconset" "$app/Contents/Resources"
.build/release/JamTap --render-app-icon build/AppIcon-1024.png
for points in 16 32 128 256 512; do
  sips -z $points $points build/AppIcon-1024.png --out "$iconset/icon_${points}x${points}.png" >/dev/null
  sips -z $((points * 2)) $((points * 2)) build/AppIcon-1024.png --out "$iconset/icon_${points}x${points}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"

# Ad-hoc signature ("-"): no developer certificate needed. macOS ties the audio-capture permission
# to this signature, so it asks again after each rebuild.
# Finder adds extended attributes to an app it has opened, and codesign refuses to sign over them.
xattr -cr "$app"
codesign --force --sign - "$app"
echo "Built $app"
if [ "${1:-}" = install ]; then
  # A running JamTap finishes its take before it quits, so wait for it.
  pkill -x JamTap 2>/dev/null || true
  while pgrep -x JamTap >/dev/null; do sleep 0.2; done
  ditto "$app" /Applications/JamTap.app
  echo "Installed /Applications/JamTap.app"
fi
