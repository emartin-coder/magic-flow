#!/bin/zsh
# Downloads the official Jitouch v2.82.1 release (GPL-3.0) and extracts its prefpane into build/.
# The build reuses its compiled MainMenu.nib and resources, because compiling .xib files needs Xcode.
set -euo pipefail
cd "${0:A:h}/.."
[[ -d build/Jitouch.prefPane ]] && exit 0
T=$(mktemp -d)
curl -fsSL -o $T/Install-Jitouch.pkg https://github.com/JitouchApp/Jitouch/releases/download/v2.82.1/Install-Jitouch.pkg
# Pin the exact v2.82.1 file, so a swapped download fails even if its signer name matches.
echo "3f5194a4da6fe19d17c843fa8a876131f7878905dcbb2e1d740d34d286d740c4  $T/Install-Jitouch.pkg" | shasum -a 256 -c --quiet ||
  { echo "Release package checksum mismatch" >&2; exit 1; }
# Refuse anything not signed by the Jitouch maintainer's Apple Developer ID (team 5UQY3B3594).
pkgutil --check-signature $T/Install-Jitouch.pkg | grep -q "Developer ID Installer: Aaron Kollasch (5UQY3B3594)" ||
  { echo "Release package signature check failed" >&2; exit 1; }
pkgutil --expand-full $T/Install-Jitouch.pkg $T/x
mkdir -p build
cp -R $T/x/JitouchPrefpane.pkg/Payload/Jitouch.prefPane build/
rm -rf $T
echo "Fetched official Jitouch v2.82.1 bundle into build/Jitouch.prefPane"
