#!/bin/bash
# Makes the file to download: dist/Cube-Hub-<version>.dmg, with "Cube Hub.app" for
# Apple Silicon and Intel Macs, and a shortcut to Applications to drag it onto.
# Usage: Scripts/package.sh   (also run by .github/workflows/release.yml)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(tr -d '[:space:]' < VERSION)"
NAME="Cube-Hub-$VERSION"
APP="build/Cube Hub.app"

./build.sh --no-run --release

# The disk image shows the app next to a shortcut to Applications.
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

mkdir -p dist
rm -f "dist/$NAME.dmg"
hdiutil create -volname "Cube Hub $VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "dist/$NAME.dmg" >/dev/null
# A fingerprint of the file, so anyone can check the download is the one published.
(cd dist && shasum -a 256 "$NAME.dmg" > "$NAME.dmg.sha256")

echo "✓ dist/$NAME.dmg"
cat "dist/$NAME.dmg.sha256"
