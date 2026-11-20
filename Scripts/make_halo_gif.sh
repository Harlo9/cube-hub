#!/bin/bash
# Remakes the README's halo GIF (docs/halo.gif) and the design mockup from the widget's
# demo sessions (never real projects): the app records PNG frames (--record-widget),
# then ffmpeg makes the GIF and gifsicle shrinks it.
# Needs ffmpeg and gifsicle (brew install ffmpeg gifsicle) and a built app (./build.sh --no-run).
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Cube Hub.app/Contents/MacOS/CubeWidget"
WIDTH=440   # GIF width in pixels, as shown in the README
FPS=25      # one frame every 40 ms, like the recording

for tool in ffmpeg gifsicle; do
    command -v "$tool" >/dev/null || { echo "Missing $tool: brew install $tool" >&2; exit 1; }
done
[ -x "$APP" ] || { echo "Build the app first: ./build.sh --no-run" >&2; exit 1; }

FRAMES="$(mktemp -d)"
trap 'rm -rf "$FRAMES"' EXIT

echo "Recording the demo widget…"
"$APP" --record-widget "$FRAMES"

echo "Making the GIF…"
ffmpeg -y -loglevel error -framerate "$FPS" -i "$FRAMES/frame-%04d.png" \
    -vf "scale=$WIDTH:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" \
    -loop 0 "$FRAMES/halo.gif"
gifsicle -O3 --lossy=30 "$FRAMES/halo.gif" -o docs/halo.gif
cp docs/halo.gif docs/design/apercu_halo.gif

# The mockup: a frame while the blue light runs around the card.
cp "$FRAMES/frame-0030.png" docs/design/maquette_pile.png

echo "Done: docs/halo.gif ($(du -k docs/halo.gif | cut -f1) KB), docs/design/maquette_pile.png"
