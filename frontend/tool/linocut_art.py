"""Turn a cut-paper picture into a five-ink linocut print (Night print's art).

    uv run --with pillow --with numpy python tool/linocut_art.py IN OUT [--kind KIND]

KIND picks the recipe (role, token, card_back, scene); `tool/skin_art.py` runs
it over the whole set. The print is deterministic: the paper texture comes
from a fixed seed, so the same picture always gives the same bytes.

How a picture is printed:
1. Smooth the paper grain away, keeping the shapes (median filter).
2. Stretch the contrast so mid-tones commit to an ink.
3. Give every pixel the nearest of the five inks, weighting hue so reds and
   ambers survive; faces get extra weight on light so skin stays cream.
4. Tidy the ink map (majority filter), so no speckle of one ink sits alone.
5. Carve: an ink line where two inks meet.
6. Print: a few specks where the ink missed the paper, in flat areas.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass, replace

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

# The five inks (lib/design_system/skin/skins/night_print.dart).
INK = (0x17, 0x13, 0x0F)
INDIGO = (0x14, 0x18, 0x3A)
CREAM = (0xF3, 0xE8, 0xD3)
RED = (0xC8, 0x45, 0x2F)
AMBER = (0xE3, 0xA1, 0x3A)
INKS = np.array([INK, INDIGO, CREAM, RED, AMBER], float)
_INK, _INDIGO, _CREAM, _RED, _AMBER = range(5)

SEED = 7


@dataclass(frozen=True)
class Recipe:
    """How hard each step works on one kind of picture."""

    median: int = 7  # grain smoothing kernel (odd)
    median_passes: int = 3
    modes: tuple[int, ...] = (9, 5)  # majority filters, in order (odd sizes)
    edge: int = 3  # carved line width (odd; 1 is a hairline)
    channel_weights: tuple[float, float, float] = (1.0, 1.2, 0.9)
    # Extra cost of each ink, so a picture leans away from it (e.g. amber on
    # faces).
    ink_bias: tuple[float, float, float, float, float] = (0, 0, 0, 0, 0)
    contrast: tuple[float, float] = (2, 98)  # percentiles stretched to 0-255
    specks: float = 168  # higher is fewer specks (0-255)


RECIPES = {
    # Faces must stay readable: less smoothing, finer lines, and amber kept
    # off the skin (it reads as a rash in five inks).
    "role": Recipe(
        median=5,
        median_passes=2,
        modes=(7, 3),
        edge=3,
        ink_bias=(0, 0, -900, 600, 2600),
        contrast=(2, 92),
        specks=176,
    ),
    # A medallion: bold, flat, few specks.
    "token": Recipe(median=7, median_passes=2, modes=(7, 5), edge=3, specks=190),
    # The card back is fine filigree: barely smoothed, hairline carving, so it
    # stays ornate rather than turning to mud.
    "card_back": Recipe(
        median=3,
        median_passes=1,
        modes=(3,),
        edge=1,
        contrast=(4, 99),
        specks=200,
    ),
    "scene": Recipe(),
}


# Pictures that need more than their kind's recipe: faces cut from grey paper
# go to ink without a push towards cream.
PICTURES = {
    "hunter": {"contrast": (1, 88), "ink_bias": (0, 0, -1500, 900, 2600)},
    "tanner": {"contrast": (1, 88), "ink_bias": (0, 0, -1500, 900, 2600)},
}


def recipe_for(kind: str, name: str) -> Recipe:
    """The recipe for one picture: its kind's, with its own changes."""
    return replace(RECIPES[kind], **PICTURES.get(name, {}))


def flatten_token(im: Image.Image) -> Image.Image:
    """A token for a square frame: the medallion's emblem on a flat indigo
    square, with the round rim and the corners outside it painted over, so a
    square frame shows no second (round) frame and no darker corners."""
    w, h = im.size
    disc = np.asarray(im.convert("RGB"), float)
    # The disc's own colour, sampled in a ring just inside the rim.
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.hypot(xx - w / 2, yy - h / 2) / (min(w, h) / 2)
    ring = (r > 0.78) & (r < 0.84)
    colour = tuple(int(c) for c in np.median(disc[ring], axis=0))
    out = Image.new("RGB", (w, h), colour)
    mask = Image.new("L", (w, h), 0)
    inner = 0.82 * min(w, h) / 2
    ImageDraw.Draw(mask).ellipse(
        (w / 2 - inner, h / 2 - inner, w / 2 + inner, h / 2 + inner), fill=255
    )
    out.paste(im.convert("RGB"), mask=mask)
    # Scale up a little so the emblem fills the square.
    margin = int(min(w, h) * 0.06)
    return out.crop((margin, margin, w - margin, h - margin)).resize(
        (w, h), Image.LANCZOS
    )


def lino(im: Image.Image, recipe: Recipe = Recipe(), seed: int = SEED) -> Image.Image:
    """Prints [im] in the five inks."""
    im = im.convert("RGB")
    for _ in range(recipe.median_passes):
        im = im.filter(ImageFilter.MedianFilter(recipe.median))
    a = np.asarray(im, float)

    lo, hi = np.percentile(a, recipe.contrast[0]), np.percentile(a, recipe.contrast[1])
    a = np.clip((a - lo) / max(hi - lo, 1), 0, 1) * 255

    weights = np.array(recipe.channel_weights)
    d = ((a[:, :, None, :] - INKS[None, None]) ** 2 * weights).sum(-1)
    d += np.array(recipe.ink_bias)[None, None]
    idx = d.argmin(-1).astype("uint8")

    m = Image.fromarray(idx)
    for size in recipe.modes:
        m = m.filter(ImageFilter.ModeFilter(size))
    idx = np.asarray(m)
    out = INKS[idx]

    edges = np.zeros(idx.shape, bool)
    edges[1:, :] |= idx[1:, :] != idx[:-1, :]
    edges[:, 1:] |= idx[:, 1:] != idx[:, :-1]
    if recipe.edge > 1:
        edges = (
            np.asarray(
                Image.fromarray((edges * 255).astype("uint8")).filter(
                    ImageFilter.MaxFilter(recipe.edge)
                )
            )
            > 0
        )
    out[edges] = INKS[_INK]

    rng = np.random.default_rng(seed)
    noise = np.asarray(
        Image.fromarray((rng.random(idx.shape) * 255).astype("uint8")).filter(
            ImageFilter.GaussianBlur(1.2)
        ),
        float,
    )
    speck = (noise > recipe.specks) & ~edges & (idx != _CREAM)
    out[speck] = out[speck] * 0.55 + INKS[_CREAM] * 0.45
    return Image.fromarray(out.astype("uint8"))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source")
    parser.add_argument("target")
    parser.add_argument("--kind", choices=sorted(RECIPES), default="scene")
    args = parser.parse_args()
    im = Image.open(args.source)
    if args.kind == "token":
        im = flatten_token(im)
    name = args.source.rsplit("/", 1)[-1].split(".")[0]
    lino(im, recipe_for(args.kind, name)).save(args.target)


if __name__ == "__main__":
    main()
