#!/bin/bash
ICON_SRC="app_icon.png"
ICONSET="DarkwareZapret.iconset"

if [ ! -f "$ICON_SRC" ]; then
    echo "Error: app_icon.png not found!"
    exit 1
fi

mkdir -p "$ICONSET"

echo "Generating icon sizes..."
sips -z 16 16     "$ICON_SRC" --out "$ICONSET/icon_16x16.png" > /dev/null
sips -z 32 32     "$ICON_SRC" --out "$ICONSET/icon_16x16@2x.png" > /dev/null
sips -z 32 32     "$ICON_SRC" --out "$ICONSET/icon_32x32.png" > /dev/null
sips -z 64 64     "$ICON_SRC" --out "$ICONSET/icon_32x32@2x.png" > /dev/null
sips -z 128 128   "$ICON_SRC" --out "$ICONSET/icon_128x128.png" > /dev/null
sips -z 256 256   "$ICON_SRC" --out "$ICONSET/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "$ICON_SRC" --out "$ICONSET/icon_256x256.png" > /dev/null
sips -z 512 512   "$ICON_SRC" --out "$ICONSET/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "$ICON_SRC" --out "$ICONSET/icon_512x512.png" > /dev/null
sips -z 1024 1024 "$ICON_SRC" --out "$ICONSET/icon_512x512@2x.png" > /dev/null

echo "Packing icns..."
iconutil -c icns "$ICONSET" -o DarkwareZapret.icns

rm -rf "$ICONSET"
echo "DarkwareZapret.icns generated successfully!"
