#!/usr/bin/env bash
# Builds Consta.app and wraps it in a drag-to-Applications disk image in dist/.
#
#     scripts/make-dmg.sh
#
# Takes the same environment as build-app.sh, plus notarization credentials. When CONSTA_SIGN_IDENTITY
# and either of these are set, the DMG is notarized by Apple and the ticket is stapled to it:
#   CONSTA_NOTARY_PROFILE                       A profile saved with `xcrun notarytool store-credentials`.
#   APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD  An Apple ID with an app-specific password.
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/build-app.sh

version="$(plutil -extract CFBundleShortVersionString raw dist/Consta.app/Contents/Info.plist)"
identity="${CONSTA_SIGN_IDENTITY:--}"
dmg="dist/Consta-$version.dmg"

echo "==> Creating $dmg"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
cp -R dist/Consta.app "$staging/"
ln -s /Applications "$staging/Applications"
rm -f "$dmg"
hdiutil create -volname "Consta" -srcfolder "$staging" -fs APFS -format ULFO -ov "$dmg" >/dev/null

if [[ "$identity" == "-" ]]; then
    echo "==> Done: $dmg (unsigned; people will need to allow it in System Settings › Privacy & Security)"
    exit 0
fi

codesign --force --timestamp --sign "$identity" "$dmg"

if [[ -n "${CONSTA_NOTARY_PROFILE:-}" ]]; then
    notary_auth=(--keychain-profile "$CONSTA_NOTARY_PROFILE")
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
    notary_auth=(--apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD")
else
    echo "==> Done: $dmg (signed but not notarized; set CONSTA_NOTARY_PROFILE or APPLE_ID/APPLE_TEAM_ID/APPLE_APP_PASSWORD)"
    exit 0
fi

echo "==> Notarizing (this usually takes a few minutes)"
xcrun notarytool submit "$dmg" "${notary_auth[@]}" --wait
xcrun stapler staple "$dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
echo "==> Done: $dmg (signed and notarized)"
