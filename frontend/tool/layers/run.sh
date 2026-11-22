#!/usr/bin/env bash
# Cut the two flat pictures into the layer masters, from scratch.
#
#   frontend/tool/layers/run.sh [work-folder]     (a temp folder if none is given)
#
# Reads docs/design/art/layers/{night-village,dawn-gallows}/flat.jpg, runs the stages in order
# (numpy, OpenCV, Pillow, scipy: `uv run --with ...` fetches them) and leaves the layers as
# PNG and WebP in <work-folder>/out/ (names 04_* and 08_*). The masters in docs/design/art/layers/
# are those PNGs: `compare.py <work-folder>/out` shows a run reproduces them exactly. Not part of
# `just`: the layers are made once, here.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
art="$here/../../../docs/design/art/layers"
work="${1:-$(mktemp -d)}"
mkdir -p "$work/out"
cp "$art/night-village/flat.jpg" "$work/night-village.jpg"
cp "$art/dawn-gallows/flat.jpg" "$work/dawn-gallows.jpg"
export LAYERS_WORK="$work"
run() { (cd "$here" && uv run --quiet --with numpy --with opencv-python-headless --with pillow --with scipy python "$@"); }
# 04: the moon's circle, the sky model, the cuts, the layers (the plate, the moon, the clouds and their shadows).
run s04_masks.py
run s04_sky.py
run s04_seg.py
run s04_export2.py
# 08: the classes, the plate and the band, the roofs and gallows, the split along the seams, the layers; then the
# sun, cut from 04's moon paper.
run s08_a.py
run s08_b.py
run s08_c.py
run s08_export.py
run s08_sun.py
echo "layers in $work/out"
