"""Make Shadow paper's phone-sized art from the originals in docs/design/art/.

    uv run --with pillow python tool/skin_art.py

(`just skin-art`, from frontend/.) Writes
assets/skins/shadow_paper/{roles,tokens,scenes}/<name>.webp: each original
resized to the size the skin's ArtSet declares
(lib/design_system/skin/skins/shadow_paper.dart) and encoded as WebP. The
output is deterministic: run it twice and the files do not change.
"""

from __future__ import annotations

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


def _jobs():
    """(source, folder, file name, size) for every picture."""
    for src in sorted((ART / "roles").glob("*.jpg")):
        yield src, "roles", src.stem, ROLE
    for src in sorted((ART / "tokens").glob("*.jpg")):
        yield src, "tokens", src.stem, TOKEN
    for src in sorted((ART / "scenes").glob("*.jpg")):
        name = src.stem.replace("-", "_")
        if name == "card_back":
            yield src, "scenes", name, CARD_BACK
        else:
            with Image.open(src) as im:
                size = im.size
            yield src, "scenes", name, size


def main() -> None:
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
