#!/usr/bin/env bash
# Renders Design/AppIcon.svg into the AppIcon asset catalog:
#   AppIcon.png        – default (light) 1024x1024, opaque
#   AppIcon-Dark.png   – dark appearance, transparent background
#   AppIcon-Tinted.png – tinted appearance, grayscale on black
# Requires: rsvg-convert (librsvg) and python3 with Pillow.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=Design/AppIcon.svg
OUT=DashCast/Resources/Assets.xcassets/AppIcon.appiconset
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

rsvg-convert -w 1024 -h 1024 "$SRC" -o "$TMP/light.png"
# Dark variant: drop the background fill + halo so the system's dark backdrop shows.
sed -e '/id="bg-fill"/d' -e '/id="bg-halo"/d' "$SRC" > "$TMP/dark.svg"
rsvg-convert -w 1024 -h 1024 "$TMP/dark.svg" -o "$TMP/dark.png"

python3 - "$TMP" "$OUT" <<'PY'
import sys
from PIL import Image
tmp, out = sys.argv[1], sys.argv[2]
light = Image.open(f"{tmp}/light.png").convert("RGB")      # App Store icon must be opaque
light.save(f"{out}/AppIcon.png", optimize=True)
dark = Image.open(f"{tmp}/dark.png").convert("RGBA")
dark.save(f"{out}/AppIcon-Dark.png", optimize=True)
black = Image.new("RGBA", dark.size, (0, 0, 0, 255))
tinted = Image.alpha_composite(black, dark).convert("L")
# stretch so the play glyph reads as near-white for the system tint
tinted = tinted.point(lambda v: min(255, int(v * 1.35)))
tinted.convert("RGB").save(f"{out}/AppIcon-Tinted.png", optimize=True)
PY

cat > "$OUT/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "filename" : "AppIcon-Dark.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "tinted" } ],
      "filename" : "AppIcon-Tinted.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
echo "Rendered $OUT"
ls -l "$OUT"
