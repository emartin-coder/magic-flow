#!/bin/zsh
# Builds Jitouch (fingertip-drawing fork) without Xcode and installs it as /Applications/Magic Flow.app (Magic Flow is this fork's name).
# Needs: Xcode Command Line Tools (xcode-select --install). Apple Silicon only.
# Usage: ./build.sh             test, build, install to /Applications and the user's PreferencePanes
#        ./build.sh --no-install test and build into build/ only
set -euo pipefail
cd "${0:A:h}"
B=build
SRC=jitouch/Jitouch
TEMPLATE=$B/Jitouch.prefPane/Contents/Resources/Jitouch.app

# 0. Official release bundle (for its compiled nib), then the tests, which must pass before anything is built.
tools/fetch-template.sh
tests/run.sh

# Signing: a stable local identity keeps the Accessibility permission across rebuilds; ad-hoc ("-") loses it every rebuild.
SIGN_ID=-
security find-identity -p codesigning 2>/dev/null | grep -q '"Jitouch Local Signing"' && SIGN_ID="Jitouch Local Signing"
echo "Signing with: $SIGN_ID"

# 1. Compile the app executable (Apple Silicon).
clang -fno-objc-arc -fobjc-exceptions -O2 -arch arm64 -mmacosx-version-min=11.0 \
  -include $SRC/Jitouch_Prefix.pch -I$SRC $SRC/*.m support/MultitouchSupport.tbd \
  -framework Cocoa -framework Carbon -framework IOKit -framework ScriptingBridge -framework ApplicationServices \
  -framework CoreAudio -framework AudioToolbox -o $B/Jitouch

# 2. Icon: render 1024px PNG, scale to every size macOS wants, pack into .icns.
#    AppIcon for Jitouch, SettingsIcon (edge sliders instead of a letter) for Jitouch Settings.
for icon in AppIcon SettingsIcon; do
  swift support/make_icon.swift $B/$icon.png $([[ $icon == SettingsIcon ]] && echo settings)
  rm -rf $B/$icon.iconset && mkdir $B/$icon.iconset
  for s in 16 32 128 256 512; do
    sips -z $s $s $B/$icon.png --out $B/$icon.iconset/icon_${s}x${s}.png >/dev/null
    sips -z $((s*2)) $((s*2)) $B/$icon.png --out $B/$icon.iconset/icon_${s}x${s}@2x.png >/dev/null
  done
  iconutil -c icns $B/$icon.iconset -o $B/$icon.icns
done

# 3. Assemble the app from the official bundle: swap in our executable and icon, sign for this Mac.
A="$B/Magic Flow.app" # bundle id stays com.jitouch.Jitouch, so settings and the Accessibility permission carry over
rm -rf "$A"
cp -R $TEMPLATE "$A"
cp $B/Jitouch "$A/Contents/MacOS/Jitouch"
cp $B/AppIcon.icns "$A/Contents/Resources/jitouchicon.icns"
plutil -replace CFBundleShortVersionString -string "2.82.1-fingerdraw" "$A/Contents/Info.plist"
plutil -replace CFBundleName -string "Magic Flow" "$A/Contents/Info.plist"
plutil -replace CFBundleDisplayName -string "Magic Flow" "$A/Contents/Info.plist"
codesign --force --deep --sign "$SIGN_ID" "$A"
codesign --verify --deep --strict "$A"

# 3b. Magic Flow Settings: the letters and edge-slider window (settings/JitouchSettings.swift).
S="$B/Magic Flow Settings.app"
rm -rf "$S" && mkdir -p "$S/Contents/MacOS" "$S/Contents/Resources"
swiftc -parse-as-library -O -target arm64-apple-macos13.0 settings/JitouchSettings.swift -o "$S/Contents/MacOS/Magic Flow Settings"
cp $B/SettingsIcon.icns "$S/Contents/Resources/AppIcon.icns"
plutil -create xml1 "$S/Contents/Info.plist"
for kv in CFBundleIdentifier:com.jitouch.Settings CFBundleName:"Magic Flow Settings" CFBundleExecutable:"Magic Flow Settings" \
          CFBundleIconFile:AppIcon CFBundlePackageType:APPL LSMinimumSystemVersion:13.0 CFBundleShortVersionString:1.0; do
  plutil -insert "${kv%%:*}" -string "${kv#*:}" "$S/Contents/Info.plist"
done
codesign --force --sign "$SIGN_ID" "$S"

[[ "${1:-}" == "--no-install" ]] && { echo "Built $A"; exit 0; }

# 4. Install the app and Jitouch Settings in /Applications. The official settings panel isn't used: Jitouch Settings
#    replaces it, and a login item (added once) starts Jitouch at login instead of the panel's launch agent.
pkill -x Jitouch || true
rm -rf "/Applications/Magic Flow.app"
cp -R "$A" "/Applications/Magic Flow.app"
osascript -e 'tell application "System Events" to if not (exists login item "Magic Flow") then make login item at end with properties {path:"/Applications/Magic Flow.app", hidden:true}' >/dev/null
rm -rf "/Applications/Magic Flow Settings.app"
cp -R "$S" "/Applications/Magic Flow Settings.app"
touch "/Applications/Magic Flow.app"   # nudge Finder/Dock to pick up the new icon
open "/Applications/Magic Flow.app"
echo "Installed /Applications/Magic Flow.app"
