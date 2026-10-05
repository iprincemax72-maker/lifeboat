#!/bin/sh
# builds build/Lifeboat.app as a universal binary.
# set SIGN_ID to a Developer ID to sign it properly, otherwise it's ad-hoc signed.
set -eu
cd "$(dirname "$0")/.."

bins=""
for arch in arm64 x86_64; do
  # separate scratch dirs, newer swiftpm puts every triple in the same output folder
  opts="-c release --triple $arch-apple-macosx13.0 --scratch-path .build/$arch"
  swift build $opts
  bins="$bins $(swift build $opts --show-bin-path)/Lifeboat"
done

app=build/Lifeboat.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
lipo -create -output "$app/Contents/MacOS/Lifeboat" $bins
cp Resources/Info.plist "$app/Contents/"
cp Resources/AppIcon.icns "$app/Contents/Resources/"

if [ -n "${SIGN_ID:-}" ]; then
  codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$app"
else
  codesign --force --sign - "$app"
fi
echo "built $app"
