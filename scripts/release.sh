#!/bin/sh
# makes dist/Lifeboat-<version>.dmg. with SIGN_ID (a Developer ID) and NOTARY_PROFILE
# (saved with `xcrun notarytool store-credentials`) set, it's signed and notarized too.
set -eu
cd "$(dirname "$0")/.."

./scripts/build.sh
version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
app=build/Lifeboat.app
mkdir -p dist

if [ -n "${NOTARY_PROFILE:-}" ]; then
  ditto -c -k --keepParent "$app" dist/notarize.zip
  xcrun notarytool submit dist/notarize.zip --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$app"
  rm dist/notarize.zip
fi

dmg="dist/Lifeboat-$version.dmg"
stage=$(mktemp -d)
ditto "$app" "$stage/Lifeboat.app"
ln -s /Applications "$stage/Applications"
rm -f "$dmg"
hdiutil create -quiet -volname Lifeboat -srcfolder "$stage" -format UDZO "$dmg"
rm -rf "$stage"

if [ -n "${NOTARY_PROFILE:-}" ]; then
  codesign --sign "$SIGN_ID" --timestamp "$dmg"
  xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$dmg"
fi
echo "$dmg"
