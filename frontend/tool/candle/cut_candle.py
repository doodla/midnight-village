"""Cut the night's candle out of docs/design/art/scenes/candle.jpg into three
sprites with a transparent background, so the clock can shorten the wax and
shrink the flame in steps while the paper (its grain, the lit lip, the drips,
the iron holder) stays the art's own.

    uv run --with pillow --with numpy --with scipy --with opencv-python-headless \
        python tool/candle/cut_candle.py

Writes frontend/assets/skins/shadow_paper/candle/{wax,flame,holder}.webp and
prints the sprites' places on the cut's canvas (the numbers in
`shadowPaperArt.candle`, lib/design_system/skin/skins/shadow_paper.dart).
The background of the picture is a dark navy paper, nearly the night's own;
the stick is cut by colour, the holder (black iron on that navy) by GrabCut
with hints, the flame by how much brighter than the background it is.
"""

from pathlib import Path

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "docs/design/art/scenes/candle.jpg"
OUT = ROOT / "frontend/assets/skins/shadow_paper/candle"

# The cut's canvas: where, in the picture, the three sprites live.
X0, X1, Y0, Y1 = 270, 570, 330, 860

im = np.array(Image.open(SRC).convert("RGB")).astype(float)
roi = im[Y0:Y1, X0:X1]
H, W, _ = roi.shape


def smooth(a, k=25):
    out = np.copy(a)
    for c in range(3):
        out[:, c] = np.convolve(
            np.pad(a[:, c], (k, k), mode="edge"),
            np.ones(2 * k + 1) / (2 * k + 1),
            mode="valid",
        )
    return out


# The background, row by row, from its two margins.
left = smooth(roi[:, 4:16].mean(axis=1))
right = smooth(roi[:, W - 16 : W - 4].mean(axis=1))
t = np.linspace(0, 1, W)[None, :, None]
bg = left[:, None, :] * (1 - t) + right[:, None, :] * t
diff = np.abs(roi - bg).max(axis=2)
bgr = cv2.cvtColor(roi.astype(np.uint8), cv2.COLOR_RGB2BGR)


def largest(mask):
    lab, n = ndi.label(mask)
    sizes = ndi.sum(mask, lab, range(1, n + 1))
    return lab == (1 + int(np.argmax(sizes)))


# 1. The stick with its drips (below the flame).
m = np.full((H, W), cv2.GC_PR_BGD, np.uint8)
m[:, :30] = cv2.GC_BGD
m[:, W - 25 :] = cv2.GC_BGD
m[diff > 40] = cv2.GC_PR_FGD
m[diff > 90] = cv2.GC_FGD
m[:120, :] = cv2.GC_BGD
cv2.grabCut(
    bgr, m, None, np.zeros((1, 65)), np.zeros((1, 65)), 6, cv2.GC_INIT_WITH_MASK
)
wax = (m == cv2.GC_FGD) | (m == cv2.GC_PR_FGD)
wax = ndi.binary_fill_holes(ndi.binary_closing(wax, iterations=2))
wax = largest(wax)
# only the stick: not the dish, the stem or the handle that touch it
wax[395:, :] = False
wax[109:150, 113:127] = True  # the wick, dark on dark: cut by hand
wax[:, :60] = False
wax[:, 192:] = False

# 2. The holder: dish, stem and handle (rows 330 to 480 of the cut).
sub = slice(330, 480)
sd = cv2.GaussianBlur(diff.astype(np.float32), (0, 0), 1.0)[sub]
h = sd.shape[0]
m = np.full((h, W), cv2.GC_PR_BGD, np.uint8)
m[:, :28] = cv2.GC_BGD
m[:, W - 22 :] = cv2.GC_BGD
m[sd > 22] = cv2.GC_PR_FGD
m[sd > 45] = cv2.GC_FGD
m[wax[sub]] = cv2.GC_PR_BGD
m[(sd > 45) & ~wax[sub]] = cv2.GC_FGD
m[75:140, 118:148] = cv2.GC_FGD  # the stem
m[60:150, 165:285][sd[60:150, 165:285] > 24] = cv2.GC_FGD  # the handle's iron
m[h - 6 :, :] = cv2.GC_PR_BGD
cv2.grabCut(
    cv2.cvtColor(roi[sub].astype(np.uint8), cv2.COLOR_RGB2BGR),
    m,
    None,
    np.zeros((1, 65)),
    np.zeros((1, 65)),
    8,
    cv2.GC_INIT_WITH_MASK,
)
holder = np.zeros((H, W), bool)
holder[sub] = (m == cv2.GC_FGD) | (m == cv2.GC_PR_FGD)
holder = ndi.binary_closing(holder, iterations=1)
filled = ndi.binary_fill_holes(holder)
holder[:, :188] = filled[:, :188]  # the handle's loop stays open
holder = largest(holder)

# 3. The stick runs a little under the holder (which is drawn over it), so no
# seam shows where they meet.
holder &= ~(wax & (np.arange(H)[:, None] < 372))
down = np.array([[0, 0, 0], [0, 1, 0], [0, 1, 0]], bool)  # only downwards: no dark fringe at the sides
wax_only = ndi.binary_dilation(wax, structure=down, iterations=4) & ~(
    holder & (np.arange(H)[:, None] > 372)
)


def sprite(mask, name, box, erode=1):
    """RGBA of [mask] inside [box] = (x0, y0, x1, y1) of the canvas."""
    x0, y0, x1, y1 = box
    mk = ndi.binary_erosion(mask, iterations=erode) if erode else mask
    alpha = cv2.GaussianBlur(mk.astype(np.float32), (0, 0), 0.8)
    rgba = np.dstack([roi, alpha * 255]).astype(np.uint8)[y0:y1, x0:x1]
    Image.fromarray(rgba, "RGBA").save(OUT / f"{name}.webp", lossless=True, method=6)
    return (x0, y0, x1 - x0, y1 - y0)


OUT.mkdir(parents=True, exist_ok=True)

# 4. The flame: how much brighter than its background each pixel is.
fa = np.clip((cv2.GaussianBlur(diff.astype(np.float32), (0, 0), 1.0) - 8) / 90, 0, 1)
fa[121:, :] = 0
fa[:, :60] = 0
fa[:, 180:] = 0
fa[:15, :] = 0
flame_box = (60, 15, 180, 121)
rgba = np.dstack([roi, fa * 255]).astype(np.uint8)[15:121, 60:180]
Image.fromarray(rgba, "RGBA").save(OUT / "flame.webp", lossless=True, method=6)

ys, xs = np.where(wax_only)
wax_box = (int(xs.min()) - 2, int(ys.min()) - 2, int(xs.max()) + 3, int(ys.max()) + 3)
print("wax", sprite(wax_only, "wax", wax_box))
ys, xs = np.where(holder)
hold_box = (int(xs.min()) - 2, int(ys.min()) - 2, int(xs.max()) + 3, int(ys.max()) + 3)
print("holder", sprite(holder, "holder", hold_box))
print(
    "flame",
    (
        flame_box[0],
        flame_box[1],
        flame_box[2] - flame_box[0],
        flame_box[3] - flame_box[1],
    ),
)
print("canvas", (W, H))
