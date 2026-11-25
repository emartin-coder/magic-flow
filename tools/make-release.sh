#!/bin/zsh
# Builds the downloadable installer: build/release/Magic-Flow-<version>.pkg
# It installs Magic Flow.app and Magic Flow Settings.app in /Applications, the same two apps build.sh installs.
# Unsigned (no Developer ID), Apple silicon only. No install scripts: the user opens the app and adds the login item.
# Usage: tools/make-release.sh 0.3.0
set -euo pipefail
cd "${0:A:h}/.."
VERSION=${1:?usage: tools/make-release.sh <version>}
R=build/release
./build.sh --no-install

rm -rf $R && mkdir -p $R/root
cp -R "build/Magic Flow.app" "build/Magic Flow Settings.app" $R/root/
xattr -cr $R/root   # drop this Mac's local file attributes (com.apple.provenance) so they don't ship
# Ad-hoc signatures, never a personal local certificate.
for app in $R/root/*.app; do codesign --force --deep --sign - "$app" && codesign --verify --deep --strict "$app"; done

# Always install exactly to /Applications, even if another Jitouch copy exists elsewhere or claims the same version.
pkgbuild --analyze --root $R/root $R/components.plist >/dev/null
for i in 0 1; do
  plutil -replace $i.BundleIsRelocatable -bool NO $R/components.plist
  plutil -replace $i.BundleIsVersionChecked -bool NO $R/components.plist
done
PKG=$R/Magic-Flow-$VERSION.pkg
pkgbuild --root $R/root --component-plist $R/components.plist --install-location /Applications \
  --identifier io.github.emartin-coder.magic-flow --version $VERSION $PKG
(cd $R && shasum -a 256 ${PKG:t} | tee ${PKG:t}.sha256)   # bare filename, so `shasum -c` works after download
