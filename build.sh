#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
if [[ -f .build-local.env ]]; then source .build-local.env; fi
destination="${1:-build}"
mkdir -p "$destination/暮色小院.app/Contents/MacOS" "$destination/暮色小院.app/Contents/Resources"
xcrun swiftc -swift-version 5 -parse-as-library -O -target arm64-apple-macosx14.0 Sources/*.swift -o "$destination/暮色小院.app/Contents/MacOS/Daygarden" -framework SwiftUI -framework AppKit -framework UserNotifications -framework Carbon -framework Charts
cp Resources/Info.plist "$destination/暮色小院.app/Contents/Info.plist"
if [[ -n "${DAYGARDEN_BUNDLE_ID:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $DAYGARDEN_BUNDLE_ID" "$destination/暮色小院.app/Contents/Info.plist"
fi
cp Resources/AppIcon.icns "$destination/暮色小院.app/Contents/Resources/AppIcon.icns"
cp Resources/PotionsProfessor.webp "$destination/暮色小院.app/Contents/Resources/PotionsProfessor.webp"
cp -R Resources/Game "$destination/暮色小院.app/Contents/Resources/"
cp -R Resources/Chibi "$destination/暮色小院.app/Contents/Resources/"
cp -R Resources/ChibiSkins "$destination/暮色小院.app/Contents/Resources/"
cp -R Resources/ChibiWardrobe "$destination/暮色小院.app/Contents/Resources/"
cp -R Resources/Doll "$destination/暮色小院.app/Contents/Resources/"
codesign --force --sign "${DAYGARDEN_SIGNING_IDENTITY:--}" "$destination/暮色小院.app"
codesign --verify --deep --strict "$destination/暮色小院.app"
