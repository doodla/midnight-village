"""Make the skins' phone-sized art from the originals in docs/design/art/.

    uv run --with pillow --with numpy python tool/skin_art.py [shadow_paper|night_print ...]

(`just skin-art`, from frontend/.) With no skin named, makes both. Writes
assets/skins/<skin>/{roles,tokens,scenes}/<name>.webp at the sizes the skins'
ArtSets declare (lib/design_system/skin/skins/). The output is deterministic:
run it twice and the files do not change.

- shadow_paper: the originals, resized and encoded as WebP.
- night_print: each original printed in five inks by linocut_art.py, with the
  recipe for its kind (role, token, card back, scene), then encoded.
"""

from __future__ import annotations

import sys
from pathlib import Path

from linocut_art import flatten_token, lino, recipe_for
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "docs" / "design" / "art"
ASSETS = ROOT / "frontend" / "assets" / "skins"

# Sizes in pixels, as the ArtSets declare them.
ROLE = (576, 768)
TOKEN = (192, 192)
CARD_BACK = (600, 800)  # drawn at most 250 wide (S07): sharp at 2.4x
QUALITY = {"shadow_paper": 75, "night_print": 80}


def _fit(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    return im if im.size == size else im.resize(size, Image.LANCZOS)


def _save(im: Image.Image, path: Path, quality: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.convert("RGB").save(path, "WEBP", quality=quality, method=6)


def _jobs():
    """(kind, source, folder, file name, size) for every picture."""
    for src in sorted((ART / "roles").glob("*.jpg")):
        yield "role", src, "roles", src.stem, ROLE
    for src in sorted((ART / "tokens").glob("*.jpg")):
        yield "token", src, "tokens", src.stem, TOKEN
    for src in sorted((ART / "scenes").glob("*.jpg")):
        name = src.stem.replace("-", "_")
        if name == "card_back":
            yield "card_back", src, "scenes", name, CARD_BACK
        else:
            with Image.open(src) as im:
                size = im.size
            yield "scene", src, "scenes", name, size


def make(skin: str) -> None:
    quality = QUALITY[skin]
    for kind, src, folder, name, size in _jobs():
        im = Image.open(src).convert("RGB")
        if skin == "night_print":
            if kind == "token":
                im = flatten_token(im)
            # Print at the source's size (the recipes are tuned for it), then
            # resize.
            im = lino(im, recipe_for(kind, name))
        _save(_fit(im, size), ASSETS / skin / folder / f"{name}.webp", quality)
        print(f"{skin}/{folder}/{name}.webp")


def main(argv: list[str]) -> None:
    skins = argv or ["shadow_paper", "night_print"]
    for skin in skins:
        if skin not in QUALITY:
            sys.exit(f"unknown skin {skin!r}; one of {', '.join(QUALITY)}")
        make(skin)


if __name__ == "__main__":
    main(sys.argv[1:])
