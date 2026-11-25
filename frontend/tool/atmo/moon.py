"""Cut the night sky's moon into phases: a piece of the sky's own paper laid over it.

    uv run --with numpy --with pillow --with opencv-python-headless \
        python tool/atmo/moon.py

(from frontend/). Writes docs/design/art/atmo/moon/<phase>.png: full-canvas RGBA
masters on the night village's canvas (768 x 1024, like the layers in
docs/design/art/layers/night-village/), each the dark part of one phase. Laid
over the `moon` layer, moving with it, under the clouds' shadows on the moon,
they turn the full moon into that phase; the full moon is the moon as it is (no
file). `just skin-art` cuts each to its box and prints its size and anchor
(assets/skins/shadow_paper/atmo/moon/).

How: the moon's disc is read from the moon layer (its paint where it is bone,
not its cast shadow), its circle fitted. The dark part is cut along an arc
(a disc of the sky laid over the moon for a crescent or a quarter, a crescent of
the sky for a gibbous moon) with a scissor wobble; its paper is the plate's own
sky where it lies (village_plate.png, the sky that was under the moon); its cut
edge has a lit lip toward the light (upper left) and a dark cut line on the far
side; it casts the look's hard paper shadow (a contact copy and a few stepped
flat copies, no blur) on the bone. Light from the upper left, as in the
village. Deterministic.
"""

from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
LAYERS = ROOT / "docs/design/art/layers/night-village"
OUT = ROOT / "docs/design/art/atmo/moon"

INK = np.array([0x07, 0x09, 0x1A], np.float32)  # the night's shadow ink
LIGHT = np.array([-0.6, -0.8])  # toward the light
SS = 4  # supersampling of the cut edge

# (name, kind, centre offset in moon radii (x), radius in moon radii).
# kind "disc": the dark part is the moon inside that disc;
# kind "hole": the dark part is the moon outside it (a gibbous moon).
# Waxing: lit on the right; waning: mirrored.
PHASES = [
    ("crescent_young", "disc", -0.20, 1.02),
    ("crescent_waxing", "disc", -0.52, 1.04),
    ("quarter_first", "disc", -40.0, 40.0),
    ("gibbous_waxing", "hole", 0.62, 1.20),
    # the full moon: no file
    ("gibbous_waning", "hole", -0.62, 1.20),
    ("quarter_last", "disc", 40.0, 40.0),
    ("crescent_waning", "disc", 0.52, 1.04),
]


def moon_disc():
    """The moon layer's bone (its coverage, 0..1) and its fitted circle."""
    m = np.asarray(Image.open(LAYERS / "moon.png")).astype(np.float32)
    lum = m[..., :3].mean(2)
    cov = m[..., 3] / 255 * np.clip((lum - 40) / 160, 0, 1)
    edge = cv2.Canny((cov > 0.5).astype(np.uint8) * 255, 50, 150)
    ys, xs = np.nonzero(edge)
    # algebraic circle fit, then drop the points off it (a cloud's rebuilt bit)
    keep = np.ones(len(xs), bool)
    for _ in range(4):
        a = np.c_[2 * xs[keep], 2 * ys[keep], np.ones(keep.sum())]
        b = xs[keep] ** 2 + ys[keep] ** 2
        cx, cy, c = np.linalg.lstsq(a, b, rcond=None)[0]
        r = np.sqrt(c + cx**2 + cy**2)
        keep = np.abs(np.hypot(xs - cx, ys - cy) - r) < 2.5
    return cov, (float(cx), float(cy), float(r))


def wobble(theta: np.ndarray, seed: int) -> np.ndarray:
    """A scissor cut's wobble along an arc, in px, by angle."""
    rng = np.random.default_rng(seed)
    n = 1440
    out = np.zeros(n, np.float32)
    for sigma, amp in ((40, 0.45), (12, 0.3), (3, 0.15)):
        z = rng.standard_normal(n * 3).astype(np.float32)
        z = cv2.GaussianBlur(z.reshape(1, -1), (0, 0), sigma).ravel()[n : 2 * n]
        out += amp * z / z.std()
    ang = np.linspace(-np.pi, np.pi, n, endpoint=False)
    return np.interp(theta, np.r_[ang, np.pi], np.r_[out, out[0]])


def dark_part(kind, ox, rr, circle, shape, seed):
    """Coverage of the dark piece (before the moon's own edge) and the facing
    of its cut edge (+1 toward the light), at 1x, from an SS grid."""
    cx, cy, r = circle
    h, w = shape
    y0, y1 = int(cy - r - 8), int(cy + r + 9)
    x0, x1 = int(cx - r - 8), int(cx + r + 9)
    yy, xx = np.mgrid[y0 * SS : y1 * SS, x0 * SS : x1 * SS].astype(np.float32)
    px, py = (xx + 0.5) / SS, (yy + 0.5) / SS
    kx, ky = cx + ox * r, cy
    d = np.hypot(px - kx, py - ky)
    th = np.arctan2(py - ky, px - kx)
    rad = rr * r + wobble(th, seed)
    if kind == "disc":
        e = rad - d  # inside the disc is dark
        nx, ny = (px - kx) / d, (py - ky) / d
    else:
        e = d - rad
        nx, ny = -(px - kx) / d, -(py - ky) / d
    dark = np.clip(e * SS + 0.5, 0, 1)
    facing = nx * LIGHT[0] + ny * LIGHT[1]
    full = np.zeros((h, w), np.float32)
    full_e = np.full((h, w), 1e3, np.float32)
    full_f = np.zeros((h, w), np.float32)
    small = (y1 - y0, x1 - x0)
    full[y0:y1, x0:x1] = cv2.resize(dark, small[::-1], interpolation=cv2.INTER_AREA)
    full_e[y0:y1, x0:x1] = cv2.resize(e, small[::-1], interpolation=cv2.INTER_AREA)
    full_f[y0:y1, x0:x1] = cv2.resize(facing, small[::-1], interpolation=cv2.INTER_AREA)
    return full, full_e, full_f


def shift(a, dx, dy):
    m = np.float32([[1, 0, dx], [0, 1, dy]])
    return cv2.warpAffine(a, m, (a.shape[1], a.shape[0]), flags=cv2.INTER_LINEAR)


def phase(kind, ox, rr, cov, circle, plate, seed):
    dark, e, facing = dark_part(kind, ox, rr, circle, cov.shape, seed)
    # the sky's paper, a touch lifted (it lies nearer than the sky)
    paper = plate + 3.0
    edge = (e > 0) & (e < 2.2)
    lip = edge * np.clip(facing * 1.5, 0, 1)
    line = ((e > 0) & (e < 1.4)) * np.clip(-facing * 1.5 + 0.3, 0, 1)
    paper = paper + (20 * lip - 9 * line)[..., None]
    # its shadow on the bone: a hard contact copy and four stepped flat copies
    # falling away from the light (no blur)
    sh = 0.55 * shift(dark, 1.0, 1.5)
    for k in range(1, 5):
        sh = 1 - (1 - sh) * (1 - 0.09 * shift(dark, 0.6 + 0.6 * k, 1.2 + 1.2 * k))
    sh = sh * (1 - dark)
    # a hair generous at the rim, so no bone shows round the dark part
    rim = np.clip(cov * 1.6, 0, 1)
    a_dark = dark * rim
    a_sh = sh * cov
    alpha = a_dark + a_sh
    rgb = (paper * a_dark[..., None] + INK * a_sh[..., None]) / np.maximum(alpha, 1e-4)[
        ..., None
    ]
    rgba = np.dstack([np.clip(rgb + 0.5, 0, 255), np.clip(alpha * 255 + 0.5, 0, 255)])
    rgba = rgba.astype(np.uint8)
    rgba[rgba[..., 3] == 0, :3] = 0
    return Image.fromarray(rgba, "RGBA")


def main() -> None:
    cov, circle = moon_disc()
    print("moon circle", tuple(round(v, 2) for v in circle))
    plate = np.asarray(Image.open(LAYERS / "village_plate.png").convert("RGB")).astype(
        np.float32
    )
    OUT.mkdir(parents=True, exist_ok=True)
    for i, (name, kind, ox, rr) in enumerate(PHASES):
        im = phase(kind, ox, rr, cov, circle, plate, seed=1000 + i)
        im.save(OUT / f"{name}.png", optimize=True)
        print(f"{name}.png", im.getchannel("A").getbbox())


if __name__ == "__main__":
    main()
