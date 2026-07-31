#!/bin/bash
SRC="app_icon.jpg"
ICONSET="app_icon.iconset"

rm -rf "$ICONSET" app_icon.icns
mkdir -p "$ICONSET"

# Convert to PNG and resize for macOS iconset
sips -s format png -z 16 16 "$SRC" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -s format png -z 32 32 "$SRC" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -s format png -z 32 32 "$SRC" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -s format png -z 64 64 "$SRC" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -s format png -z 128 128 "$SRC" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -s format png -z 256 256 "$SRC" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -s format png -z 256 256 "$SRC" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -s format png -z 512 512 "$SRC" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -s format png -z 512 512 "$SRC" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -s format png -z 1024 1024 "$SRC" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET" -o app_icon.icns
rm -rf "$ICONSET"

if [ -f app_icon.icns ]; then
  echo "SUCCESS: Created app_icon.icns"
else
  echo "FAILED to create app_icon.icns"
fi
