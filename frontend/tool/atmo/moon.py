"""Cut the night sky's moon into phases: a piece of the sky's own paper laid over it.

    uv run --with numpy --with pillow --with opencv-python-headless \
        python tool/atmo/moon.py

(from frontend/). Writes docs/design/art/atmo/moon/<phase>.png: full-canvas RGBA
masters on the night village's canvas (768 x 1024, like the layers in
docs/design/art/layers/night-village/), each the dark part of one phase. Laid
above the moon and the clouds' shadows on it (`moon_shadow_*`) and under the
clouds, moving with the moon, a phase turns the full moon into itself; the full
moon is the moon as it is (no file). `just skin-art` cuts each to its box and
prints its size and anchor (assets/skins/shadow_paper/atmo/moon/).

How: the moon's disc is read from the moon layer (its paint where it is bone,
not its cast shadow) and its circle fitted. The dark part is cut along an arc
(a disc laid over the moon for a crescent, a crescent laid on the limb for a
gibbous moon), turned by one small angle for the whole set, with a scissor
wobble. Its paper is the sky exactly as it lies there without the moon (the
plate with the clouds' shadows on it, at rest), and it also covers the moon's
own cast shadow beside the dark limb, so the dark part goes into the sky. What
shows is the cut: a thin lit lip on the piece's edge, and on the bone a hard
contact line and a short stepped shadow falling away from the light (upper
left, as in the village); no blur. Deterministic.
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
# The whole set's terminators are turned by this much (clockwise on screen):
# a waning moon's lit side faces the light (upper left), as if laid by hand.
TURN = np.radians(20)
RING, FADE = 28.0, 14.0  # how far the moon's own shadow is covered, px

# (name, kind, centre offset in moon radii, radius in moon radii), measured
# along the lit direction. kind "disc": the dark part is the moon inside that
# disc (a crescent); "hole": the moon outside it (a gibbous moon). Waxing: lit
# toward +x (turned), waning mirrored. Every cut passes through the moon's two
# poles (radius = hypot(1, offset)), so the dark part ends in fine horns there
# as a real terminator does: lit widths 0.27 and 0.6 (crescents), 1.35 and
# 1.75 (gibbous) of the radius.
PHASES = [
    ("crescent_thin_waxing", "disc", -0.32, 1.05),
    ("crescent_fat_waxing", "disc", -1.05, 1.45),
    ("gibbous_thin_waxing", "hole", 1.25, 1.60),
    ("gibbous_fat_waxing", "hole", 0.29, 1.04),
    # the full moon: no file
    ("gibbous_fat_waning", "hole", -0.29, 1.04),
    ("gibbous_thin_waning", "hole", -1.25, 1.60),
    ("crescent_fat_waning", "disc", 1.05, 1.45),
    ("crescent_thin_waning", "disc", 0.32, 1.05),
]


def moon_disc():
    """The moon layer's alpha, its bone (coverage, 0..1) and its fitted circle."""
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
    return m[..., 3] / 255, cov, (float(cx), float(cy), float(r))


def sky_at_rest() -> np.ndarray:
    """What lies under the moon: the plate with the clouds' shadows on the sky."""
    sky = Image.open(LAYERS / "village_plate.png").convert("RGBA")
    for name in ("clouds_dark_shadow_bleed16.png", "clouds_cream_shadow_bleed16.png"):
        sky.alpha_composite(Image.open(LAYERS / name).crop((16, 0, 784, 1024)))
    return np.asarray(sky.convert("RGB")).astype(np.float32)


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


def cut(px, py, kind, ox, rr, circle, seed):
    """For points (px, py): how far inside the dark piece each lies across the
    cut (px, + inside), and the facing of the cut there (+1 toward the light)."""
    cx, cy, r = circle
    c, s = np.cos(TURN), np.sin(TURN)
    kx, ky = cx + ox * r * c, cy + ox * r * s
    d = np.hypot(px - kx, py - ky) + 1e-6
    rad = rr * r + wobble(np.arctan2(py - ky, px - kx), seed)
    sign = 1 if kind == "disc" else -1
    e = sign * (rad - d)
    nx, ny = sign * (px - kx) / d, sign * (py - ky) / d  # outward of the piece
    return e, nx * LIGHT[0] + ny * LIGHT[1]


def shift(a, dx, dy):
    m = np.float32([[1, 0, dx], [0, 1, dy]])
    return cv2.warpAffine(a, m, (a.shape[1], a.shape[0]), flags=cv2.INTER_LINEAR)


def phase(kind, ox, rr, alpha_m, cov, circle, sky, seed):
    cx, cy, r = circle
    h, w = cov.shape
    # the cut, sharp: an SS grid over the moon's box, brought down by area
    y0, y1, x0, x1 = int(cy - r - 6), int(cy + r + 7), int(cx - r - 6), int(cx + r + 7)
    yy, xx = np.mgrid[y0 * SS : y1 * SS, x0 * SS : x1 * SS].astype(np.float32)
    e_ss, f_ss = cut((xx + 0.5) / SS, (yy + 0.5) / SS, kind, ox, rr, circle, seed)
    box = (x1 - x0, y1 - y0)
    dark = np.zeros((h, w), np.float32)
    e = np.full((h, w), -1e3, np.float32)
    facing = np.zeros((h, w), np.float32)
    dark[y0:y1, x0:x1] = cv2.resize(
        np.clip(e_ss * SS + 0.5, 0, 1), box, interpolation=cv2.INTER_AREA
    )
    e[y0:y1, x0:x1] = cv2.resize(e_ss, box, interpolation=cv2.INTER_AREA)
    facing[y0:y1, x0:x1] = cv2.resize(f_ss, box, interpolation=cv2.INTER_AREA)
    # the moon's own shadow on the sky beside the dark limb goes too: a point
    # off the disc is covered when the limb nearest it is dark
    gy, gx = np.mgrid[0:h, 0:w].astype(np.float32)
    dd = np.hypot(gx - cx, gy - cy) + 1e-6
    k = (r - 1.5) / dd
    e_limb, _ = cut(cx + (gx - cx) * k, cy + (gy - cy) * k, kind, ox, rr, circle, seed)
    outside = np.clip(dd - r + 1, 0, 1)
    cover = dark * (1 - outside) + np.clip(e_limb / 3 + 0.5, 0, 1) * outside
    # out to RING px beyond the limb, fading over the last FADE px (the moon's
    # shadow there is a faint haze; a round fading edge keeps the file small)
    cover *= np.clip((r + RING - dd) / FADE, 0, 1)
    inside = np.clip((r - dd) / 2 + 0.5, 0, 1)  # the cut shows on the disc only
    # the lit lip of the piece's cut edge
    lip = ((e > 0) & (e < 1.6)) * (0.75 + 0.25 * np.clip(facing, -1, 1)) * inside
    paper = sky + (34 * lip)[..., None]
    # on the bone: a hard contact line all along the cut, and a short stepped
    # shadow falling down and right (it shows where the bone lies that way)
    contact = ((e <= 0) & (e > -1.3)).astype(np.float32)
    sh = 0.5 * contact
    for i in range(1, 4):
        sh = 1 - (1 - sh) * (
            1 - (0.55 if i == 1 else 0.1) * shift(dark, 0.7 * i, 1.0 * i)
        )
    sh = sh * (1 - dark) * np.clip(cov * 1.6, 0, 1) * inside
    a_dark = np.clip(cover, 0, 1)
    a_sh = sh * (1 - a_dark)
    alpha = a_dark + a_sh
    rgb = (paper * a_dark[..., None] + INK * a_sh[..., None]) / np.maximum(alpha, 1e-4)[
        ..., None
    ]
    rgba = np.dstack([np.clip(rgb + 0.5, 0, 255), np.clip(alpha * 255 + 0.5, 0, 255)])
    rgba = rgba.astype(np.uint8)
    rgba[rgba[..., 3] == 0, :3] = 0
    return Image.fromarray(rgba, "RGBA")


def main() -> None:
    alpha_m, cov, circle = moon_disc()
    print("moon circle", tuple(round(v, 2) for v in circle))
    sky = sky_at_rest()
    OUT.mkdir(parents=True, exist_ok=True)
    for i, (name, kind, ox, rr) in enumerate(PHASES):
        im = phase(kind, ox, rr, alpha_m, cov, circle, sky, seed=1000 + i)
        im.save(OUT / f"{name}.png", optimize=True)
        print(f"{name}.png", im.getchannel("A").getbbox())


if __name__ == "__main__":
    main()
