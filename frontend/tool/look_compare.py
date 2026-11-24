"""Before | after | what changed, for each state `just look` drew.

    uv run --with pillow python tool/look_compare.py <folder> <width> [<sheets>]

Reads <folder>/after/*.png and <folder>/before/*.png (same names) and writes,
into <sheets> (or <folder>), <state>-w<width>.png: the two pictures at full size side by side, and a
third panel where every pixel that differs is red over a faded copy, so a change
a few pixels long cannot hide. A state with no "before" gets the one picture.
"""

import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

GAP = 36
LABEL_H = 54
BG = (32, 28, 36)
INK = (230, 224, 214)
RED = (255, 40, 40)


def labelled(panels: list[tuple[str, Image.Image]]) -> Image.Image:
    height = max(p.height for _, p in panels) + LABEL_H
    width = sum(p.width for _, p in panels) + GAP * (len(panels) + 1)
    sheet = Image.new("RGB", (width, height + GAP), BG)
    draw = ImageDraw.Draw(sheet)
    x = GAP
    for name, picture in panels:
        draw.text((x, 14), name, fill=INK, font_size=28)
        sheet.paste(picture, (x, LABEL_H))
        x += picture.width + GAP
    return sheet


def changed(before: Image.Image, after: Image.Image) -> tuple[Image.Image, int]:
    """The after picture faded, with every differing pixel red; and how many differ."""
    size = (max(before.width, after.width), max(before.height, after.height))
    a = Image.new("RGB", size, BG)
    b = Image.new("RGB", size, BG)
    a.paste(before, (0, 0))
    b.paste(after, (0, 0))
    mask = ImageChops.difference(a, b).convert("L").point(lambda v: 255 if v else 0)
    faded = Image.blend(b, Image.new("RGB", size, (255, 255, 255)), 0.75)
    faded.paste(Image.new("RGB", size, RED), (0, 0), mask)
    return faded, sum(1 for v in mask.getdata() if v)


def main(argv: list[str]) -> int:
    folder, width = Path(argv[1]), argv[2]
    sheets = Path(argv[3]) if len(argv) > 3 else folder
    after_dir, before_dir = folder / "after", folder / "before"
    pictures = sorted(after_dir.glob("*.png"))
    if not pictures:
        print(f"look: nothing was drawn into {after_dir}", file=sys.stderr)
        return 1
    for path in pictures:
        after = Image.open(path).convert("RGB")
        old = before_dir / path.name
        out = sheets / f"{path.stem}-w{width}.png"
        if old.is_file():
            before = Image.open(old).convert("RGB")
            diff, count = changed(before, after)
            panels = [("before (main)", before), ("after (this change)", after)]
            panels.append((f"changed: {count} pixels" if count else "changed: nothing", diff))
            said = f"{count} pixels differ" if count else "identical to main"
        else:
            panels = [("after (this change; no picture from main)", after)]
            said = "no 'before'"
        labelled(panels).save(out)
        print(f"look: {out}  ({after.width}x{after.height} px per picture; {said})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
