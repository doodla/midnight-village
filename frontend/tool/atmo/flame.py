"""Draw the candle's flame as cut paper, in eight frames, from the flame that ships.

    uv run --with numpy --with pillow --with opencv-python-headless \
        python tool/atmo/flame.py

(from frontend/). Writes docs/design/art/atmo/flame/flame_1..8.png: RGBA masters
at twice the size of the flame sprite (240 x 212 for its 120 x 106), the foot of
the flame on the wick at the bottom middle (the sprite's (60, 106), the candle
canvas's wick at (120, 121); `CandleArt` in lib/design_system/skin/skins/
shadow_paper.dart). `just skin-art` makes the phone's WebP from them
(assets/skins/shadow_paper/atmo/flame/).

How: the outline of today's flame (assets/skins/shadow_paper/candle/flame.webp,
cut from the candle picture) and its orange heart are traced and smoothed into
scissor curves; three layers of paper are laid at rest (a pale back sheet, the
amber on it, the orange heart round the wick) with a notch cut for the wick, a lit lip on the edge
toward the light, a cut line on the far edge, the hard shadow of each layer on
the one under it, and a seeded grain. Every frame is that one rest paper bent
(it leans, squats, stretches; the foot stays on the wick), plus, in two frames,
a tongue cut from its tip that flies off. So the frames are one piece of paper
and match each other exactly; frame 1 is the rest. Deterministic.
"""

from __future__ import annotations

import math
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
TODAY = ROOT / "frontend/assets/skins/shadow_paper/candle/flame.webp"
OUT = ROOT / "docs/design/art/atmo/flame"

W, H = 120, 106  # the sprite (1x), as CandleArt declares it
BASE = (60.0, 106.0)  # the foot of the flame on the wick (1x)
SS = 8  # supersampling while drawing
MASTER = 2  # the master's scale
SEED = 20261125

# Paper (sampled from today's flame: the body, the heart, the lit rim).
AMBER = np.array([233, 174, 108], np.float32)
HEART = np.array([217, 133, 66], np.float32)
AMBER_SHIFT = (1.9, 1.3)  # the amber on the pale sheet: down and right (1x px)
LIP = np.array([255, 221, 170], np.float32)
LIGHT = np.array([-0.6, -0.8])  # toward the light: the upper left

# Frames: height, width, lean of the tip, bow of the middle (1x px), and a
# tongue cut off the tip: (dx, dy, turn in degrees, scale) or None.
FRAMES = [
    dict(h=1.00, w=1.00, lean=0, bow=0),  # 1 rest: today's flame
    dict(h=0.90, w=1.06, lean=13, bow=3),  # 2 a draught leans it right
    dict(h=0.64, w=1.20, lean=5, bow=-2),  # 3 it gutters: low and fat
    dict(h=0.58, w=1.10, lean=-5, bow=-1, tongue=(-6, -15, -22, 0.95)),  # 4 split
    dict(h=0.84, w=0.95, lean=-11, bow=-3, tongue=(-9, -21, -34, 0.78)),  # 5
    dict(h=1.10, w=0.90, lean=6, bow=2),  # 6 recovers, stretched
    dict(h=0.96, w=1.03, lean=-3, bow=-1),  # 7
    dict(h=1.01, w=0.99, lean=1, bow=0),  # 8 back toward the rest
]


# ---------------------------------------------------------------- tracing


def _smooth_contour(mask: np.ndarray, harmonics: int) -> np.ndarray:
    """The largest outline of [mask] as a closed curve kept to its first
    [harmonics] Fourier terms (a scissor curve, not a pixel stair)."""
    cs, _ = cv2.findContours(
        mask.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE
    )
    c = max(cs, key=cv2.contourArea)[:, 0, :].astype(np.float64)
    # resample evenly along its length
    seg = np.hypot(*np.diff(np.vstack([c, c[:1]]), axis=0).T)
    s = np.r_[0, np.cumsum(seg)]
    n = 1024
    u = np.linspace(0, s[-1], n, endpoint=False)
    cc = np.vstack([c, c[:1]])
    z = np.interp(u, s, cc[:, 0]) + 1j * np.interp(u, s, cc[:, 1])
    f = np.fft.fft(z)
    f[harmonics + 1 : n - harmonics] = 0
    z = np.fft.ifft(f)
    return np.stack([z.real, z.imag], 1)


def trace_today() -> tuple[np.ndarray, np.ndarray]:
    """Today's flame: its outline and its heart, in 1x sprite coordinates."""
    im = np.asarray(Image.open(TODAY).convert("RGBA")).astype(np.float32)
    r, g, a = im[..., 0], im[..., 1], im[..., 3] / 255
    body = np.clip((r - 120) / 70, 0, 1) * a
    heart = np.clip((0.745 - g / np.maximum(r, 1)) / 0.08, 0, 1) * (body > 0.7)
    big = (W * SS, H * SS)
    out = []
    for field, sigma, k in ((body, 0.7, 22), (heart, 1.2, 9)):
        up = cv2.resize(field, big, interpolation=cv2.INTER_CUBIC)
        up = cv2.GaussianBlur(up, (0, 0), sigma * SS)
        out.append(_smooth_contour(up > 0.5, k) / SS)
    outline, heart_line = out
    # the foot: flat on the bottom edge (the sprite's edge cuts it there)
    outline[:, 1] = np.minimum(outline[:, 1], H + 2)
    return outline, heart_line


# Where the wick goes in: a notch cut in the foot (1x), round at its top.
NOTCH = np.array(
    [
        (55.0, 108),
        (55.2, 101.5),
        (56.4, 98.6),
        (58.6, 97.3),
        (61.0, 97.7),
        (62.7, 99.8),
        (63.6, 103.2),
        (64.1, 108),
    ]
)


# ---------------------------------------------------------------- the rest paper


def _fill(poly: np.ndarray) -> np.ndarray:
    """A polygon (1x coordinates) as a mask at SS, anti-aliasing left to the
    final downsampling."""
    m = np.zeros((H * SS, W * SS), np.uint8)
    pts = np.round(poly * SS * 16).astype(np.int32)
    cv2.fillPoly(m, [pts], 1, lineType=cv2.LINE_8, shift=4)
    return m.astype(np.float32)


def _shift(a: np.ndarray, dx: float, dy: float) -> np.ndarray:
    m = np.float32([[1, 0, dx * SS], [0, 1, dy * SS]])
    return cv2.warpAffine(a, m, (a.shape[1], a.shape[0]), flags=cv2.INTER_LINEAR)


def grain(rng: np.random.Generator) -> np.ndarray:
    """The paper's grain at SS, one value per pixel in levels: a fine speck,
    a slow mottle and a few fibres, as measured in today's flame (high-pass std
    about 3 levels at 0.8 px, 6 at 2 px)."""
    h, w = H * SS, W * SS
    fine = cv2.GaussianBlur(
        rng.standard_normal((h, w)).astype(np.float32), (0, 0), 0.5 * SS
    )
    fine *= 4.5 / fine.std()
    slow = cv2.GaussianBlur(
        rng.standard_normal((h, w)).astype(np.float32), (0, 0), 2.6 * SS
    )
    slow *= 5.5 / slow.std()
    fib = np.zeros((h, w), np.float32)
    for _ in range(14):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        ang, ln = rng.uniform(0, np.pi), rng.uniform(4, 11) * SS
        bend = rng.uniform(-0.5, 0.5)
        pts = []
        for s in np.linspace(0, 1, 12):
            a = ang + bend * s
            pts.append((x + math.cos(a) * ln * s, y + math.sin(a) * ln * s))
        cv2.polylines(
            fib, [np.int32(pts)], False, float(rng.choice([-1, 1])), max(1, SS // 3)
        )
    fib = cv2.GaussianBlur(fib, (0, 0), 0.3 * SS) * 6
    # specks: the flecks in the paper that catch the light or sit dark in it
    speck = np.zeros((h, w), np.float32)
    n = int(0.05 * W * H)
    xs, ys = rng.integers(0, w, n), rng.integers(0, h, n)
    speck[ys, xs] = rng.choice([-1.0, 1.0], n, p=[0.35, 0.65]) * rng.uniform(0.5, 1, n)
    speck = cv2.GaussianBlur(speck, (0, 0), 0.35 * SS) * (16 / speck_peak(0.35 * SS))
    return fine + slow + fib + speck


def speck_peak(sigma: float) -> float:
    """The height a unit dot keeps after a blur of [sigma]."""
    return 1 / (2 * math.pi * sigma * sigma)


def _edges(
    mask: np.ndarray, lip_px: float, line_px: float
) -> tuple[np.ndarray, np.ndarray]:
    """For a cut piece: its lit lip on the side toward the light and its dark
    cut line on the far side (each 0..1 per pixel)."""
    inside = cv2.distanceTransform((mask > 0.5).astype(np.uint8), cv2.DIST_L2, 5) / SS
    soft = cv2.GaussianBlur(mask, (0, 0), 1.2 * SS)
    gy, gx = np.gradient(soft)
    n = np.hypot(gx, gy) + 1e-6
    # the outward normal is against the gradient (which points inward)
    facing = (-gx / n) * LIGHT[0] + (-gy / n) * LIGHT[1]
    facing = cv2.GaussianBlur(facing.astype(np.float32), (0, 0), 2.0 * SS)
    band = mask * (inside < lip_px)
    lip = band * np.clip(facing * 1.6, 0, 1)
    line = mask * (inside < line_px) * np.clip(-facing * 1.6 + 0.25, 0, 1)
    return lip.astype(np.float32), line.astype(np.float32)


def rest_paper(outline, heart_line) -> np.ndarray:
    """The flame at rest, premultiplied RGBA float at SS: a pale back sheet,
    the amber laid on it a little down and right (so the pale shows as a
    sliver along the edge toward the light, as in today's flame), and the
    orange heart laid on the amber round the wick, each casting its hard
    shadow on the sheet under it."""
    rng = np.random.default_rng(SEED)
    notch = _fill(NOTCH)
    back = _fill(outline) * (1 - notch)
    amber = back * _shift(back, *AMBER_SHIFT)
    heart = _fill(heart_line) * amber
    tex = grain(rng)[..., None]

    rgb = np.zeros((H * SS, W * SS, 3), np.float32)
    rgb[:] = LIP
    _, line = _edges(back, 0, 0.9)
    rgb *= 1 - 0.18 * line[..., None]
    # the amber, its own cut line on the far side
    a_lip, a_line = _edges(amber, 1.0, 0.8)
    a_rgb = AMBER * (1 - 0.35 * a_lip[..., None]) + LIP * 0.35 * a_lip[..., None]
    a_rgb = a_rgb * (1 - 0.16 * a_line[..., None])
    rgb = rgb * (1 - amber[..., None]) + a_rgb * amber[..., None]
    # the heart on the amber, and its hard shadow
    sh = _shift(heart, 0.8, 1.0) * (1 - heart) * amber
    rgb *= 1 - 0.22 * sh[..., None]
    hl, hline = _edges(heart, 1.0, 0.7)
    h_rgb = HEART * (1 - 0.45 * hl[..., None]) + AMBER * 0.45 * hl[..., None]
    h_rgb = h_rgb * (1 - 0.16 * hline[..., None])
    rgb = rgb * (1 - heart[..., None]) + h_rgb * heart[..., None]
    rgb = rgb + tex
    a = back[..., None]
    return np.dstack([np.clip(rgb, 0, 255) * a, a * 255])


# ---------------------------------------------------------------- bending


FOOT = 10.0  # the bottom 10 px of the flame do not bend: they hold the wick
REST_H = 80.0  # how tall the flame stands at rest, foot to tip


def _smooth(t: np.ndarray, lo: float, hi: float) -> np.ndarray:
    s = np.clip((t - lo) / (hi - lo), 0, 1)
    return s * s * (3 - 2 * s)


def bend_forward(x, y, f):
    """Where a point of the rest paper (1x) lands in frame [f]."""
    h = BASE[1] - y
    hh = np.where(h > FOOT, FOOT + (h - FOOT) * f["h"], h)
    t = np.clip(hh / (REST_H * f["h"]), 0, 1.2)
    sw = 1 + (f["w"] - 1) * _smooth(t, 0.0, 0.35)
    off = f["lean"] * t**1.6 + f["bow"] * np.sin(np.pi * np.clip(t, 0, 1))
    return BASE[0] + (x - BASE[0]) * sw + off, BASE[1] - hh


def bend(paper: np.ndarray, f: dict) -> np.ndarray:
    """The rest paper bent into frame [f]: for each pixel, where it came from."""
    yy, xx = np.mgrid[0 : H * SS, 0 : W * SS].astype(np.float32)
    X, Y = (xx + 0.5) / SS, (yy + 0.5) / SS
    hh = BASE[1] - Y
    h = np.where(hh > FOOT, FOOT + (hh - FOOT) / f["h"], hh)
    t = np.clip(hh / (REST_H * f["h"]), 0, 1.2)
    sw = 1 + (f["w"] - 1) * _smooth(t, 0.0, 0.35)
    off = f["lean"] * t**1.6 + f["bow"] * np.sin(np.pi * np.clip(t, 0, 1))
    x = BASE[0] + (X - BASE[0] - off) / sw
    y = BASE[1] - h
    return cv2.remap(
        paper,
        x * SS - 0.5,
        y * SS - 0.5,
        cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=0,
    )


def tongue_mask() -> np.ndarray:
    """The piece of the tip that flies off: the flame above a round cut."""
    yy, xx = np.mgrid[0 : H * SS, 0 : W * SS].astype(np.float32)
    X, Y = (xx + 0.5) / SS, (yy + 0.5) / SS
    return (((X - 61.5) / 9.0) ** 2 + ((Y - 30) / 19.0) ** 2 < 1).astype(np.float32)


def tongue(paper: np.ndarray, f: dict, outline: np.ndarray) -> np.ndarray:
    """The tip piece, cut from the rest paper, carried to where the frame's
    tip is and then off by (dx, dy), turned and shrunk."""
    dx, dy, turn, scale = f["tongue"]
    piece = paper * tongue_mask()[..., None]
    a = piece[..., 3]
    ys, xs = np.nonzero(a > 1)
    cx, cy = xs.mean() / SS, ys.mean() / SS
    tx, ty = bend_forward(np.float32(cx), np.float32(cy), f)
    m = cv2.getRotationMatrix2D((cx * SS, cy * SS), -turn, scale)
    m[0, 2] += (tx + dx - cx) * SS
    m[1, 2] += (ty + dy - cy) * SS
    return cv2.warpAffine(piece, m, (W * SS, H * SS), flags=cv2.INTER_LINEAR)


def frame(paper: np.ndarray, f: dict, outline: np.ndarray) -> Image.Image:
    out = bend(paper, f)
    if f.get("tongue"):
        t = tongue(paper, f, outline)
        out = t + out * (1 - t[..., 3:4] / 255)
    small = cv2.resize(out, (W * MASTER, H * MASTER), interpolation=cv2.INTER_AREA)
    a = small[..., 3:4]
    rgb = np.where(a > 0, small[..., :3] / np.maximum(a, 1e-3) * 255, 0)
    px = np.dstack([rgb, a]).round().clip(0, 255).astype(np.uint8)
    return Image.fromarray(px, "RGBA")


def main() -> None:
    outline, heart_line = trace_today()
    paper = rest_paper(outline, heart_line)
    OUT.mkdir(parents=True, exist_ok=True)
    for i, f in enumerate(FRAMES, 1):
        im = frame(paper, f, outline)
        im.save(OUT / f"flame_{i}.png", optimize=True)
        print(f"flame_{i}.png", im.size)


if __name__ == "__main__":
    main()
