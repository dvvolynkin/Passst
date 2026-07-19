#!/bin/zsh

set -euo pipefail

ROOT_DIR="${0:A:h:h}"
CONFIGURATION="${1:-release}"
VERSION="${2:-0.1.3}"
BUILD_NUMBER="${3:-4}"
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
KEYBOARD_SHORTCUTS_CHECKOUT="$ROOT_DIR/.build/checkouts/KeyboardShortcuts"
KEYBOARD_SHORTCUTS_UTILITIES="$KEYBOARD_SHORTCUTS_CHECKOUT/Sources/KeyboardShortcuts/Utilities.swift"
KEYBOARD_SHORTCUTS_PATCH="$ROOT_DIR/scripts/keyboard-shortcuts-resource-bundle.patch"

cd "$ROOT_DIR"
swift package resolve

# SwiftPM's generated Bundle.module accessor assumes resource bundles live at
# the root of Bundle.main. That is valid for a command-line executable but not
# for a strictly signed macOS .app, where resources belong in
# Contents/Resources. Teach KeyboardShortcuts to load its localization bundle
# from the standard app resource directory.
if grep -Fq 'bundle: .module' "$KEYBOARD_SHORTCUTS_UTILITIES"; then
    patch -s -d "$KEYBOARD_SHORTCUTS_CHECKOUT" -p1 < "$KEYBOARD_SHORTCUTS_PATCH"
elif ! grep -q 'keyboardShortcutsResources' "$KEYBOARD_SHORTCUTS_UTILITIES"; then
    echo "KeyboardShortcuts resource patch does not match the resolved source." >&2
    exit 1
fi

rm -rf \
    "$ARM64_BUILD_DIR/Passst_Passst.bundle" \
    "$X86_64_BUILD_DIR/Passst_Passst.bundle"

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
cp "$ROOT_DIR/Passst/Resources/PassstMenuBarTemplate.png" "$RESOURCES_DIR/PassstMenuBarTemplate.png"

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

for required_bundle in \
    GRDB_GRDB.bundle \
    KeyboardShortcuts_KeyboardShortcuts.bundle
do
    if [[ ! -d "$RESOURCES_DIR/$required_bundle" ]]; then
        echo "Missing required SwiftPM resource bundle: $required_bundle" >&2
        exit 1
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
