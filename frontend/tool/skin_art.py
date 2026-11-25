"""Make Shadow paper's phone-sized art from the originals in docs/design/art/.

    uv run --with pillow python tool/skin_art.py

(`just skin-art`, from frontend/.) Writes
assets/skins/shadow_paper/{roles,tokens,scenes}/<name>.webp: each original
resized to the size the skin's ArtSet declares
(lib/design_system/skin/skins/shadow_paper.dart) and encoded as WebP (the card
backs, docs/design/art/card-backs/<name>.jpg, go to scenes/card_back_<name>.webp). The
output is deterministic: run it twice and the files do not change.

The layered scenes (docs/design/art/layers/<scene>/*.png, full-canvas alpha
masters, see PROVENANCE.md there) become assets/skins/shadow_paper/layers/
<scene>/<layer>.webp, each cut to the box its paint covers, so a cloud holds a
cloud's pixels, not a whole picture. A master wider than its canvas (named
`<layer>_bleedNN.png`) carries mirrored paper outside it (so a layer that slides
sideways still reaches the picture's edge); its output is `<layer>.webp`. What the skin's
LayeredScene must declare for each file (its size and where its top left sits
on the scene's canvas, bleed counted) is printed, and checked by
test/design_system/skin/layered_scene_test.dart, which also draws the layers at
rest and compares them with the flat pictures they were cut from.
"""

from __future__ import annotations

import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "docs" / "design" / "art"
OUT = ROOT / "frontend" / "assets" / "skins" / "shadow_paper"

# Sizes in pixels, as the ArtSet declares them.
ROLE = (576, 768)
TOKEN = (192, 192)
CARD_BACK = (600, 800)  # drawn at most 250 wide (S07): sharp at 2.4x
QUALITY = 75
LAYER_QUALITY = 80
# The layered scenes' canvases (the flat picture each was cut from), in pixels.
CANVAS = {"night_village": (768, 1024), "dawn_gallows": (1024, 768)}


def _jobs():
    """(source, folder, file name, size) for every picture."""
    for src in sorted((ART / "roles").glob("*.jpg")):
        yield src, "roles", src.stem, ROLE
    for src in sorted((ART / "tokens").glob("*.jpg")):
        yield src, "tokens", src.stem, TOKEN
    for src in sorted((ART / "scenes").glob("*.jpg")):
        name = src.stem.replace("-", "_")
        with Image.open(src) as im:
            size = im.size
        yield src, "scenes", name, size
    # The card backs, one drawn for a whole game (CardBack in
    # lib/design_system/skin/card_back.dart): scenes/card_back_<name>.webp.
    for src in sorted((ART / "card-backs").glob("*.jpg")):
        yield src, "scenes", f"card_back_{src.stem}", CARD_BACK


def _layer_jobs():
    """(source, scene folder, layer name) for every layer master."""
    for scene in sorted((ART / "layers").iterdir()):
        if not scene.is_dir():
            continue
        for src in sorted(scene.glob("*.png")):
            match = re.fullmatch(r"(.+)_bleed\d+", src.stem)
            yield src, scene.name.replace("-", "_"), match[1] if match else src.stem


def _layers() -> None:
    for src, scene, name in _layer_jobs():
        im = Image.open(src)
        canvas = CANVAS[scene]
        if im.width < canvas[0] or im.height < canvas[1]:
            # A sprite (the sun): placed by its own centre, kept whole.
            path = OUT / "layers" / scene / f"{name}.webp"
            im.save(path, "WEBP", method=6, quality=LAYER_QUALITY, alpha_quality=100)
            print(f"layers/{scene}/{name}.webp  size {im.width}x{im.height}  sprite")
            continue
        # A master wider than the canvas carries mirrored paper outside it.
        extra = (im.width - canvas[0], im.height - canvas[1])
        assert min(extra) >= 0 and extra[0] % 2 == 0 and extra[1] % 2 == 0, src
        bleed = (extra[0] // 2, extra[1] // 2)
        if im.mode == "RGBA":
            # The box the layer paints in (alpha above 0), nothing around it.
            box = im.getchannel("A").getbbox()
        else:
            box = (0, 0) + im.size
        assert box is not None, f"{src} is empty"
        im = im.crop(box)
        path = OUT / "layers" / scene / f"{name}.webp"
        path.parent.mkdir(parents=True, exist_ok=True)
        im.save(path, "WEBP", method=6, quality=LAYER_QUALITY, alpha_quality=100)
        # Where the cut's top left sits on the scene's canvas (the master's
        # bleed is paper outside the canvas).
        print(
            f"layers/{scene}/{name}.webp  size {im.width}x{im.height}"
            f"  anchor ({box[0] - bleed[0]}, {box[1] - bleed[1]})"
        )


# The end board's ornaments (docs/design/art/end/*.png, RGBA masters; PROVENANCE.md
# there) -> assets/skins/shadow_paper/end/<name>.webp. (master, output name, the
# width or (width, height) it is stored at, or None for the master's own size). The
# nine- and three-slice art (banner, frame, roof) keeps its own pixels, because the
# slices are declared in them (lib/design_system/skin/end_art.dart).
END = [
    ("banner", "banner", None),
    ("banner-red", "banner_red", None),
    ("frame4", "frame", None),
    ("roof4", "roof", None),
    ("post4-l", "post_l", None),
    ("post4-r", "post_r", None),
    ("lantern", "lantern", (264, 456)),
    ("crow4-1", "crow_1", 312),
    ("crow4-2", "crow_2", 312),
    ("crow4-3", "crow_3", 312),
    ("crow4-4", "crow_4", 312),
    ("crow4-5", "crow_5", 312),
    ("crow4-6", "crow_6", 312),
    ("cobbles", "cobbles", 1170),
    ("marks-1", "seal", (90, 90)),
    ("marks-4", "ribbon", (153, 193)),
]


def _end() -> None:
    folder = OUT / "end"
    folder.mkdir(parents=True, exist_ok=True)
    for master, name, size in END:
        im = Image.open(ART / "end" / f"{master}.png").convert("RGBA")
        if isinstance(size, int):
            if im.width > size:
                size = (size, round(im.height * size / im.width))
            else:
                size = None
        if size is not None and im.size != size:
            im = im.resize(size, Image.LANCZOS)
        im.save(
            folder / f"{name}.webp",
            "WEBP",
            method=6,
            quality=LAYER_QUALITY,
            alpha_quality=100,
        )
        print(f"end/{name}.webp  size {im.width}x{im.height}")


# The night's atmosphere (docs/design/art/atmo/, PROVENANCE.md there; made by
# tool/atmo/flame.py and tool/atmo/moon.py) -> assets/skins/shadow_paper/atmo/.
# The flame's frames are drawn at twice the candle sprite's size and stored at
# it (120 x 106, the size CandleArt declares for the flame); the moon's phases
# are full-canvas masters on the night village's canvas, cut to their box.
FLAME = (120, 106)
ATMO_QUALITY = 72
# The moon's phases are mostly the sky's dark paper: a lower quality holds it.
MOON_QUALITY, MOON_ALPHA = 55, 60


def _atmo() -> None:
    folder = OUT / "atmo" / "flame"
    folder.mkdir(parents=True, exist_ok=True)
    for src in sorted((ART / "atmo" / "flame").glob("*.png")):
        im = Image.open(src).convert("RGBA").resize(FLAME, Image.LANCZOS)
        im.save(folder / f"{src.stem}.webp", "WEBP", method=6, quality=ATMO_QUALITY)
        print(f"atmo/flame/{src.stem}.webp  size {im.width}x{im.height}")
    folder = OUT / "atmo" / "moon"
    folder.mkdir(parents=True, exist_ok=True)
    for src in sorted((ART / "atmo" / "moon").glob("*.png")):
        im = Image.open(src).convert("RGBA")
        box = im.getchannel("A").getbbox()
        assert box is not None, f"{src} is empty"
        im = im.crop(box)
        im.save(
            folder / f"{src.stem}.webp",
            "WEBP",
            method=6,
            quality=MOON_QUALITY,
            alpha_quality=MOON_ALPHA,
        )
        print(
            f"atmo/moon/{src.stem}.webp  size {im.width}x{im.height}"
            f"  anchor ({box[0]}, {box[1]})"
        )


def main() -> None:
    _layers()
    _end()
    _atmo()
    for src, folder, name, size in _jobs():
        im = Image.open(src).convert("RGB")
        if im.size != size:
            im = im.resize(size, Image.LANCZOS)
        path = OUT / folder / f"{name}.webp"
        path.parent.mkdir(parents=True, exist_ok=True)
        im.save(path, "WEBP", method=6, quality=QUALITY)
        print(f"{folder}/{name}.webp")


if __name__ == "__main__":
    main()
