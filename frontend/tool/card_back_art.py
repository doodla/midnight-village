"""Make the five card back masters from the raw generated pictures.

    uv run --with pillow --with numpy --with scipy python tool/card_back_art.py

(`just card-back-art`, from frontend/.) Reads docs/design/art/card-backs/raw/<name>.webp
(what the image model gave, 1200 x 1600, lossless WebP) and writes docs/design/art/card-backs/<name>.jpg
(the masters `just skin-art` shrinks to the app's WebP). Deterministic: run it twice and the
files do not change. How each picture was made, and the prompts: docs/design/art/card-backs/PROVENANCE.md.

Two stages, the same for every card (what differs is in CARDS):

1. Clean-up. Mirror the left half (and the top half) over the rest, for exact symmetry; grade
   the colours toward the app's palette (blues toward the violet-leaning indigo, bone lifted and
   warmed); lift the dark tones where asked; even the frame (the bone rim, measured to the red
   line on all four sides, trimmed to the narrowest, scaled back to 1200 x 1600).
2. Finishing, so the card sits in the cut-paper world of the rest of the art: the red frame's own
   cast shadow laid on what lies inside it (a deeper lip), a little paper grain, and the two
   local touches (the eye's amber toned to dusty gold, a warm halo round the window).
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "docs" / "design" / "art" / "card-backs"
QUALITY = 88  # of the master JPEG


@dataclass(frozen=True)
class Card:
    name: str
    # Mirror the left half over the right ("lr"), and the top over the bottom too ("lrtb").
    sym: str = "none"
    # Lift the dark tones (gamma below 1), or leave them (None).
    lift: float | None = None
    # Tone the amber to dusty gold (the eye: the primary button's hue, ten of them on a board).
    tone_amber: bool = False
    # A warm halo round the lit window, and the window a little brighter.
    window_glow: bool = False
    # The grain's seed: one per card, fixed.
    seed: int = 0


CARDS = (
    Card("moon", seed=20261187),
    Card("window", sym="lr", lift=0.78, window_glow=True, seed=20261188),
    Card("teeth", sym="lrtb", seed=20261189),
    Card("eye", sym="lrtb", tone_amber=True, seed=20261190),
    Card("quilt", sym="lrtb", seed=20261191),
)


# --- 1. Clean-up -------------------------------------------------------------


def _mirror(im: Image.Image, sym: str) -> Image.Image:
    w, h = im.size
    if sym in ("lr", "lrtb"):
        left = im.crop((0, 0, w // 2, h))
        im.paste(left, (0, 0))
        im.paste(ImageOps.mirror(left), (w // 2, 0))
    if sym == "lrtb":
        top = im.crop((0, 0, w, h // 2))
        im.paste(top, (0, 0))
        im.paste(ImageOps.flip(top), (0, h // 2))
    return im


def _grade(img: Image.Image) -> Image.Image:
    hsv = np.array(img.convert("HSV")).astype(np.float32)  # H, S, V in 0..255
    hue = hsv[..., 0] * 360 / 255
    sat = hsv[..., 1] / 255
    val = hsv[..., 2] / 255
    # Blues (180 to 270 degrees): toward the app's violet-leaning indigo, a little less saturated.
    blue = np.clip(1 - np.abs(hue - 225) / 55, 0, 1)
    hue = hue + 14 * blue
    sat = sat * (1 - 0.18 * blue)
    val = val * (1 - 0.10 * blue * (1 - val))
    # Bone: pull the dull tan toward the app's lighter warm bone.
    boneish = (
        np.clip(1 - np.abs(hue - 40) / 30, 0, 1)
        * np.clip((val - 0.55) / 0.2, 0, 1)
        * (sat < 0.35)
    )
    val = np.clip(val * (1 + 0.14 * boneish), 0, 1)
    sat = sat * (1 - 0.10 * boneish)
    out = np.stack([hue * 255 / 360 % 255, sat * 255, val * 255], -1)
    return Image.fromarray(out.clip(0, 255).astype(np.uint8), "HSV").convert("RGB")


def _lift(img: Image.Image, gamma: float) -> Image.Image:
    a = np.asarray(img).astype(np.float32) / 255
    lum = a.mean(-1, keepdims=True)
    weight = np.clip((0.45 - lum) / 0.2, 0, 1)
    out = a * (1 - weight) + (a**gamma) * weight
    return Image.fromarray((out * 255).clip(0, 255).astype(np.uint8))


def _even_frame(img: Image.Image) -> Image.Image:
    """Trim each side so the bone rim is the same width on all four sides (measured to the red
    line), then rescale back to the picture's size."""
    a = np.asarray(img).astype(int)

    def red(p):
        return p[0] > p[1] + 45 and p[0] > p[2] + 45

    def first(line):
        for i, p in enumerate(line):
            if red(p):
                return i
        return 0

    height, width, _ = a.shape
    left = int(np.median([first(a[y, :]) for y in (500, 800, 1100)]))
    right = int(np.median([first(a[y, ::-1]) for y in (500, 800, 1100)]))
    top = int(np.median([first(a[:, x]) for x in (400, 600, 800)]))
    bottom = int(np.median([first(a[::-1, x]) for x in (400, 600, 800)]))
    m = min(left, right, top, bottom)
    box = (left - m, top - m, width - (right - m), height - (bottom - m))
    return img.crop(box).resize((width, height), Image.LANCZOS)


def clean(card: Card, raw: Image.Image) -> Image.Image:
    im = _mirror(raw.convert("RGB"), card.sym)
    im = _grade(im)
    if card.lift is not None:
        im = _lift(im, card.lift)
    return _even_frame(im)


# --- 2. Finishing ------------------------------------------------------------


def _hsv(a: np.ndarray) -> np.ndarray:
    return np.array(Image.fromarray((a * 255).astype(np.uint8)).convert("HSV")).astype(
        np.float32
    )


def _amber(a: np.ndarray) -> np.ndarray:
    """How amber each pixel is (0 to 1): the eye's almond, the lit window."""
    hsv = _hsv(a) / 255
    hue = hsv[..., 0] * 360
    return (
        np.clip(1 - np.abs(hue - 38) / 22, 0, 1)
        * np.clip((hsv[..., 1] - 0.35) / 0.25, 0, 1)
        * np.clip((hsv[..., 2] - 0.25) / 0.25, 0, 1)
    )


def finish(card: Card, im: Image.Image) -> Image.Image:
    a = np.asarray(im.convert("RGB")).astype(np.float32) / 255
    h, w, _ = a.shape

    if card.tone_amber:
        m = _amber(a)
        hsv = _hsv(a)
        hsv[..., 1] = hsv[..., 1] * (1 - 0.38 * m)
        hsv[..., 2] = hsv[..., 2] * (1 - 0.20 * m)
        rgb = Image.fromarray(hsv.clip(0, 255).astype(np.uint8), "HSV").convert("RGB")
        a = np.asarray(rgb).astype(np.float32) / 255
    if card.window_glow:
        m = _amber(a)
        glow = ndi.gaussian_filter(m, 55)
        glow = glow / glow.max()
        warm = np.array([0.89, 0.63, 0.23], dtype=np.float32)
        a = np.clip(
            a + 0.62 * glow[..., None] * warm * (1 - a.mean(-1, keepdims=True)), 0, 1
        )
        a = np.clip(a * (1 + 0.12 * m[..., None]), 0, 1)

    # The red frame line, within 150 px of the edge: the one ring, not a corner diamond.
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    red = (r > g + 0.14) & (r > b + 0.14)
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.minimum.reduce([xx, yy, w - 1 - xx, h - 1 - yy])
    frame = red & (edge < 150)
    labels, count = ndi.label(frame)
    sizes = ndi.sum(frame, labels, range(1, count + 1))
    frame = labels == (1 + int(np.argmax(sizes)))
    # Its cast shadow, light from the top left: down and to the right, softened, on what lies
    # inside the frame (never on the frame or the rim outside it).
    cast = ndi.shift(frame.astype(np.float32), (9, 7), order=1)
    cast = np.clip(ndi.gaussian_filter(cast, 9) * 1.5, 0, 1)
    ring_outer = ndi.binary_fill_holes(ndi.binary_dilation(frame, iterations=4))
    inner = ring_outer & ~ndi.binary_dilation(frame, iterations=2)
    a = a * (1 - 0.62 * cast * inner)[..., None]

    # Paper grain: fine, slightly soft, strongest in the mid tones.
    noise = np.random.default_rng(card.seed).normal(0, 1, (h, w)).astype(np.float32)
    noise = ndi.gaussian_filter(noise, 1.1)
    noise = noise / noise.std()
    amplitude = 0.030 * (0.55 + 0.9 * np.clip(a.mean(-1), 0, 0.6))
    a = np.clip(a + (noise * amplitude)[..., None], 0, 1)
    return Image.fromarray((a * 255 + 0.5).astype(np.uint8))


def main() -> None:
    for card in CARDS:
        with Image.open(DIR / "raw" / f"{card.name}.webp") as raw:
            master = finish(card, clean(card, raw))
        master.save(DIR / f"{card.name}.jpg", "JPEG", quality=QUALITY, optimize=True)
        print(f"{card.name}.jpg  {master.width}x{master.height}")


if __name__ == "__main__":
    main()
