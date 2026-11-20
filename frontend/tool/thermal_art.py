"""Turn a cut-paper picture into a thermal-camera frame (Warm blood's art).

    uv run --with pillow --with numpy python tool/thermal_art.py IN OUT [--kind KIND]

KIND picks the recipe (role, token, card_back, scene); `tool/skin_art.py` runs
it over the whole set. The frame is deterministic: the sensor noise comes from
a fixed seed, so the same picture always gives the same bytes.

How a picture is filmed:
1. Read its heat. Light paper is warm and whatever is redder than it is blue
   (a flame, a lantern, blood) is warmer still; indigo paper is cold.
2. Read it between two fixed heats (the same for every picture of a kind, so
   the set looks filmed by one camera), bend it (gamma) and place it on the
   part of the scale its kind may use.
3. Let the lens soften it and the sensor read it: one value per sensor cell,
   a few output pixels square.
4. Add the sensor's noise: a little per cell, and a little per column.
5. Sort every cell into one of the scale's twelve isotherms and paint it that
   colour, cold violet to white-hot. No colour sits between two isotherms, so
   the steps show, as they do when a camera runs out of colours.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass, replace

import numpy as np
from PIL import Image

# The heat scale, cold to hot: the only colours a frame has. Its cold end is
# Warm blood's night ground and its `DAY` stop the day ground, so a picture
# runs into the screen it is on
# (lib/design_system/skin/skins/warm_blood.dart).
SCALE = np.array(
    [
        (0x0E, 0x09, 0x20),  # night ground
        (0x1B, 0x10, 0x40),
        (0x34, 0x18, 0x6B),
        (0x5C, 0x1F, 0x8C),
        (0x8F, 0x23, 0x90),
        (0xBC, 0x2A, 0x7C),
        (0xDE, 0x3B, 0x5A),
        (0xF2, 0x5C, 0x33),
        (0xFA, 0x8A, 0x26),
        (0xFD, 0xB9, 0x33),
        (0xFF, 0xD2, 0x3F),  # day ground
        (0xFF, 0xF3, 0xB8),
    ],
    "uint8",
)
STEPS = len(SCALE)

SEED = 11


def step(n: float) -> float:
    """The heat in the middle of the scale's [n]th step (0 is the coldest),
    for a recipe's span."""
    return (n + 0.5) / STEPS


@dataclass(frozen=True)
class Recipe:
    """How one kind of picture is filmed."""

    cell: int = 4  # a sensor cell's side, in output pixels
    light: float = 0.75  # how much of the heat is lightness
    warm: float = 0.6  # how much is red over blue
    # The heats shown as the coldest and the hottest (indigo paper reads about
    # 0.07 and bone paper 0.72 at the default light and warm). Fixed, not
    # taken from each picture, so a face is as warm in one picture as in the
    # next.
    levels: tuple[float, float] = (0.06, 0.93)
    # Take the commonest heat (the median) as the coldest instead: for an
    # emblem on a flat field, so every field comes out the same.
    field_is_cold: bool = False
    gamma: float = 1.0  # above 1 cools the mid-tones, below 1 warms them
    span: tuple[float, float] = (0.0, 1.0)  # the part of the scale used
    soften: float = 0.5  # lens blur, in cells
    noise: float = 0.018  # sensor noise, as a share of the scale


RECIPES = {
    # A face is the warm thing in its picture and whatever burns is hotter;
    # the paper behind is cooled so the night stays dark around it.
    "role": Recipe(levels=(0.045, 0.93)),
    # A warm emblem on a cold field that is the same on every token (the
    # field is one step above the night ground, so a token shows on it);
    # finer cells, since a token is drawn small.
    "token": Recipe(
        cell=3,
        field_is_cold=True,
        levels=(0.0, 0.62),
        gamma=1.5,
        span=(step(1), step(8)),
        noise=0.01,
    ),
    # The card back is fine filigree: the finest cells, and only lukewarm, so
    # a table of face-down cards glows without shouting. The eye is its hot
    # spot.
    "card_back": Recipe(cell=2, gamma=1.2, span=(0.0, step(8))),
    # A night scene is cold: lightness counts for less and flame for more, so
    # moonlit walls stay lukewarm and only a lit window or a lantern is hot.
    "scene": Recipe(light=0.55, warm=0.95, levels=(0.04, 1.0), gamma=0.8),
}

# Pictures that need more than their kind's recipe.
_DAWN = {"light": 0.9, "warm": 0.5, "levels": (0.05, 0.85), "gamma": 0.9}
PICTURES: dict[str, dict] = {
    # The two dawns are day pictures: the sky has warmed up.
    "dawn_gallows": _DAWN,
    "dawn_rooftops": _DAWN,
    # The Hunter's face is cut from grey paper and reads cold beside his fur
    # collar: a lower ceiling warms it to the others' faces.
    "hunter": {"levels": (0.045, 0.82)},
    # The Werewolf runs a step hotter than the people.
    "werewolf": {"levels": (0.045, 0.85)},
}


def recipe_for(kind: str, name: str) -> Recipe:
    """The recipe for one picture: its kind's, with its own changes."""
    return replace(RECIPES[kind], **PICTURES.get(name, {}))


def _heat(im: Image.Image, recipe: Recipe) -> np.ndarray:
    a = np.asarray(im.convert("RGB"), float) / 255
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    light = 0.2126 * r + 0.7152 * g + 0.0722 * b
    warm = np.clip(r - b, 0, 1)
    return recipe.light * light + recipe.warm * warm


def _blur(plane: np.ndarray, sigma: float) -> np.ndarray:
    """A Gaussian blur of a 2-D array, done here so the result does not depend
    on the imaging library's version."""
    if sigma <= 0:
        return plane
    reach = max(1, int(np.ceil(sigma * 3)))
    x = np.arange(-reach, reach + 1)
    kernel = np.exp(-(x**2) / (2 * sigma**2))
    kernel /= kernel.sum()
    for axis in (0, 1):
        pad = [(0, 0), (0, 0)]
        pad[axis] = (reach, reach)
        padded = np.pad(plane, pad, mode="edge")
        plane = np.apply_along_axis(
            lambda line: np.convolve(line, kernel, mode="valid"), axis, padded
        )
    return plane


def thermal(
    im: Image.Image,
    recipe: Recipe = Recipe(),
    size: tuple[int, int] | None = None,
    seed: int = SEED,
) -> Image.Image:
    """Films [im] at [size] (its own when null), which the recipe's cell must
    divide."""
    size = size or im.size
    cell = recipe.cell
    if size[0] % cell or size[1] % cell:
        raise ValueError(f"a {cell} px cell does not divide {size}")
    if im.size != size:
        im = im.convert("RGB").resize(size, Image.LANCZOS)

    heat = _heat(im, recipe)
    lo, hi = recipe.levels
    if recipe.field_is_cold:
        lo = float(np.median(heat))
    heat = np.clip((heat - lo) / (hi - lo), 0, 1) ** recipe.gamma
    heat = recipe.span[0] + heat * (recipe.span[1] - recipe.span[0])

    # The lens, then the sensor: the mean of each cell.
    heat = _blur(heat, recipe.soften * cell)
    h, w = size[1] // cell, size[0] // cell
    cells = heat.reshape(h, cell, w, cell).mean(axis=(1, 3))

    rng = np.random.default_rng(seed)
    cells = cells + rng.normal(0, recipe.noise, (h, w))
    cells = cells + rng.normal(0, recipe.noise / 3, (1, w))

    isotherm = np.clip(np.floor(cells * STEPS), 0, STEPS - 1).astype(int)
    frame = SCALE[isotherm]
    return Image.fromarray(np.repeat(np.repeat(frame, cell, axis=0), cell, axis=1))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source")
    parser.add_argument("target")
    parser.add_argument("--kind", choices=sorted(RECIPES), default="scene")
    args = parser.parse_args()
    name = args.source.rsplit("/", 1)[-1].split(".")[0].replace("-", "_")
    im = Image.open(args.source)
    size = tuple(n - n % RECIPES[args.kind].cell for n in im.size)
    thermal(im, recipe_for(args.kind, name), size).save(args.target)


if __name__ == "__main__":
    main()
