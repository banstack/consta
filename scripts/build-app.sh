#!/usr/bin/env bash
# Builds a release Consta.app in dist/.
#
#     scripts/build-app.sh
#
# Environment:
#   CONSTA_VERSION        Marketing version, e.g. 1.2.0. Defaults to the latest v* git tag, or 0.1.0.
#   CONSTA_BUILD          Build number. Defaults to the git commit count.
#   CONSTA_SIGN_IDENTITY  A "Developer ID Application: …" identity in the keychain. Without it the app
#                         is ad-hoc signed: it runs, but Gatekeeper asks before the first launch.
set -euo pipefail
cd "$(dirname "$0")/.."

version="${CONSTA_VERSION:-$(git describe --tags --match 'v*' --abbrev=0 2>/dev/null | sed 's/^v//' || true)}"
version="${version:-0.1.0}"
build="${CONSTA_BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
identity="${CONSTA_SIGN_IDENTITY:--}"

app="dist/Consta.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

echo "==> Building Consta $version ($build)"
swift build -c release --product Consta
cp "$(swift build -c release --show-bin-path)/Consta" "$app/Contents/MacOS/Consta"

cp Packaging/Info.plist "$app/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$version" "$app/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$build" "$app/Contents/Info.plist"

echo "==> Drawing the app icon"
swift scripts/make-icon.swift "$app/Contents/Resources/AppIcon.icns"

if [[ "$identity" == "-" ]]; then
    echo "==> Ad-hoc signing (set CONSTA_SIGN_IDENTITY to sign with a Developer ID)"
    codesign --force --sign - "$app"
else
    echo "==> Signing with $identity"
    # Hardened runtime and a secure timestamp are both required for notarization.
    codesign --force --options runtime --timestamp --sign "$identity" "$app"
fi
codesign --verify --strict --verbose=2 "$app"

echo "==> Built $app"
