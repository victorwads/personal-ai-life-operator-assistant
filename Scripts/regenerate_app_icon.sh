#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${0}")/.." && pwd)"
SOURCE_SVG="$ROOT_DIR/Resources/Assets.xcassets/BrandIcon.imageset/assistant-app-icon.svg"
APP_ICON_DIR="$ROOT_DIR/Resources/Assets.xcassets/AppIcon.appiconset"

if [[ ! -f "$SOURCE_SVG" ]]; then
  echo "Missing source SVG: $SOURCE_SVG" >&2
  exit 1
fi

if command -v rsvg-convert >/dev/null 2>&1; then
  RENDERER="rsvg-convert"
elif command -v magick >/dev/null 2>&1; then
  RENDERER="magick"
else
  echo "No SVG renderer available. Install rsvg-convert or ImageMagick." >&2
  exit 1
fi

mkdir -p "$APP_ICON_DIR"

render_png() {
  local size="$1"
  local output="$2"

  if [[ "$RENDERER" == "rsvg-convert" ]]; then
    rsvg-convert -w "$size" -h "$size" "$SOURCE_SVG" -o "$output"
  else
    magick "$SOURCE_SVG" -resize "${size}x${size}" "$output"
  fi
}

render_png 16  "$APP_ICON_DIR/icon_16x16.png"
render_png 32  "$APP_ICON_DIR/icon_16x16@2x.png"
render_png 32  "$APP_ICON_DIR/icon_32x32.png"
render_png 64  "$APP_ICON_DIR/icon_32x32@2x.png"
render_png 128 "$APP_ICON_DIR/icon_128x128.png"
render_png 256 "$APP_ICON_DIR/icon_128x128@2x.png"
render_png 256 "$APP_ICON_DIR/icon_256x256.png"
render_png 512 "$APP_ICON_DIR/icon_256x256@2x.png"
render_png 512 "$APP_ICON_DIR/icon_512x512.png"
render_png 1024 "$APP_ICON_DIR/icon_512x512@2x.png"
