"""Cuts the night village's dark windows into lit ones (prototype `atmosphere-proto`).

No image model: each window's panes are found in `village_plate.webp` itself (the panes
are darker than the paper frames round them) and filled with the warm light of the one
window the art already lit, keeping the plate's own grain. Writes an atlas,
`assets/skins/shadow_paper/atmo/windows_lit.webp`, and prints each window's rect on the
canvas and in the atlas for `atmo_village.dart`.

    uv run --with numpy --with pillow python frontend/tool/atmo/windows_lit.py
"""

import pathlib

import numpy as np
from PIL import Image

HERE = pathlib.Path(__file__).resolve().parents[2]
PLATE = HERE / "assets/skins/shadow_paper/layers/night_village/village_plate.webp"
OUT = HERE / "assets/skins/shadow_paper/atmo/windows_lit.webp"

# Canvas rects (left, top, right, bottom) of the dark windows, read off the plate.
WINDOWS = [
    (59, 420, 83, 477),
    (47, 520, 99, 585),
    (63, 659, 110, 725),
    (199, 593, 222, 645),
    (272, 680, 304, 713),
    (345, 625, 363, 670),
    (392, 623, 418, 680),
    (449, 577, 470, 617),
    (451, 647, 476, 691),
    (518, 647, 535, 698),
    (613, 622, 633, 665),
    (620, 688, 643, 733),
    (705, 487, 732, 543),
    (697, 587, 733, 677),
    (337, 550, 355, 573),
]
HOT = np.array([255, 222, 140], float)
EDGE = np.array([206, 138, 58], float)


def lit(crop):
    rgb = np.asarray(crop, float)
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    lo, hi = np.percentile(lum, 15), np.percentile(lum, 85)
    thr = (lo + hi) / 2
    alpha = np.clip((thr + 5 - lum) / 10, 0, 1)
    h, w = lum.shape
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2)
    t = np.clip(r / 1.2, 0, 1)[..., None]
    colour = HOT * (1 - t) + EDGE * t
    grain = (lum - lum.mean())[..., None] * 0.9
    colour = np.clip(colour + grain, 0, 255)
    out = np.dstack([colour, alpha * 255]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def main():
    plate = Image.open(PLATE).convert("RGB")
    sprites = [lit(plate.crop(r)) for r in WINDOWS]
    width = sum(s.width for s in sprites) + 2 * len(sprites)
    height = max(s.height for s in sprites)
    atlas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    x = 0
    print("// canvas rect -> atlas left")
    for r, s in zip(WINDOWS, sprites):
        atlas.paste(s, (x, 0))
        print(f"  (Rect.fromLTRB{r}, {x}),")
        x += s.width + 2
    atlas.save(OUT, "WEBP", quality=88, method=6)
    print(OUT, OUT.stat().st_size, "bytes", atlas.size)


if __name__ == "__main__":
    main()
