#!/bin/zsh

set -euo pipefail

ROOT_DIR="${0:A:h:h}"
RESOURCES_DIR="$ROOT_DIR/Passst/Resources"
APPICON_DIR="$RESOURCES_DIR/Assets.xcassets/AppIcon.appiconset"
TEMP_DIR="$(mktemp -d)"
ICONSET_DIR="$TEMP_DIR/Passst.iconset"
COLOR_PNG="$TEMP_DIR/Passst-1024.png"
MONO_PNG="$TEMP_DIR/PassstMenuBarTemplate-1024.png"

trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "$ICONSET_DIR"
sips -s format png "$RESOURCES_DIR/PassstIcon.svg" --out "$COLOR_PNG" >/dev/null
sips -s format png "$RESOURCES_DIR/PassstMarkMono.svg" --out "$MONO_PNG" >/dev/null

sips -z 16 16 "$COLOR_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$COLOR_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$COLOR_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$COLOR_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$COLOR_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$COLOR_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$COLOR_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$COLOR_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$COLOR_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$COLOR_PNG" "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/Passst.icns"

for icon_file in "$ICONSET_DIR"/*.png; do
    cp "$icon_file" "$APPICON_DIR/${icon_file:t}"
done

sips -z 36 36 "$MONO_PNG" --out "$RESOURCES_DIR/PassstMenuBarTemplate.png" >/dev/null
