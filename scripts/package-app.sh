#!/bin/zsh

set -euo pipefail

ROOT_DIR="${0:A:h:h}"
CONFIGURATION="${1:-release}"
VERSION="${2:-0.1.0}"
BUILD_NUMBER="${3:-1}"
ARM64_BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/$CONFIGURATION"
X86_64_BUILD_DIR="$ROOT_DIR/.build/x86_64-apple-macosx/$CONFIGURATION"
APP_DIR="$ROOT_DIR/dist/Passst.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ZIP_PATH="$ROOT_DIR/dist/Passst-$VERSION-macos-universal.zip"
DMG_PATH="$ROOT_DIR/dist/Passst-$VERSION-macos-universal.dmg"
CHECKSUM_PATH="$ROOT_DIR/dist/Passst-$VERSION-SHA256SUMS.txt"
DMG_STAGING_DIR="$ROOT_DIR/dist/.dmg-staging"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION" --arch arm64
swift build -c "$CONFIGURATION" --arch x86_64

rm -rf "$APP_DIR" "$DMG_STAGING_DIR"
rm -f "$ZIP_PATH" "$DMG_PATH" "$CHECKSUM_PATH"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
lipo \
    -create \
    "$ARM64_BUILD_DIR/Passst" \
    "$X86_64_BUILD_DIR/Passst" \
    -output "$MACOS_DIR/Passst"
cp "$ROOT_DIR/Passst/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Passst/Resources/Passst.icns" "$RESOURCES_DIR/Passst.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable Passst" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier app.passst.mac" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName Passst" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion 14.0" "$CONTENTS_DIR/Info.plist"

for bundle in "$ARM64_BUILD_DIR"/*.bundle; do
    if [[ -d "$bundle" ]]; then
        ditto "$bundle" "$RESOURCES_DIR/${bundle:t}"
    fi
done

codesign \
    --force \
    --deep \
    --sign - \
    --requirements '=designated => identifier "app.passst.mac"' \
    --entitlements "$ROOT_DIR/Passst/Passst.entitlements" \
    "$APP_DIR"

lipo "$MACOS_DIR/Passst" -verify_arch arm64 x86_64
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_PATH"

mkdir -p "$DMG_STAGING_DIR"
ditto "$APP_DIR" "$DMG_STAGING_DIR/Passst.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"
hdiutil create \
    -quiet \
    -volname "Passst $VERSION" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

(
    cd "$ROOT_DIR/dist"
    shasum -a 256 "${ZIP_PATH:t}" "${DMG_PATH:t}" > "${CHECKSUM_PATH:t}"
)

echo "$APP_DIR"
echo "$DMG_PATH"
echo "$ZIP_PATH"
echo "$CHECKSUM_PATH"
