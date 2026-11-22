"""One image of many screens: each scaled to about 240 px wide, its file name under it.

    uv run --with pillow python tool/contact_sheet.py [folder] [out.png]

(`just contact-sheet`, from the repo root or frontend/.) Takes the PNGs directly in
<folder> (default build/screens; `compare/` is not entered), in name order.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw

CELL_W = 240
LABEL_H = 18
GAP = 10
COLUMNS = 6
BG = (32, 28, 36)
INK = (230, 224, 214)


def main(argv):
    folder = Path(argv[1] if len(argv) > 1 else "build/screens")
    out = Path(argv[2] if len(argv) > 2 else folder / "contact_sheet.png")
    files = sorted(p for p in folder.glob("*.png") if p.resolve() != out.resolve())
    if not files:
        print(f"contact_sheet: no PNGs in {folder} (run `just screens` first)", file=sys.stderr)
        return 1
    cells = []
    for p in files:
        with Image.open(p) as im:
            im = im.convert("RGB")
            h = max(1, round(im.height * CELL_W / im.width))
            cells.append((p.name, im.resize((CELL_W, h), Image.LANCZOS)))
    cols = min(COLUMNS, len(cells))
    rows = [cells[i : i + cols] for i in range(0, len(cells), cols)]
    row_h = [max(c[1].height for c in r) + LABEL_H + GAP for r in rows]
    sheet = Image.new("RGB", (cols * (CELL_W + GAP) + GAP, sum(row_h) + GAP), BG)
    draw = ImageDraw.Draw(sheet)
    y = GAP
    for r, rh in zip(rows, row_h):
        for i, (name, im) in enumerate(r):
            x = GAP + i * (CELL_W + GAP)
            sheet.paste(im, (x, y))
            draw.text((x, y + im.height + 3), name[:38], fill=INK)
        y += rh
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print(f"{out}: {len(files)} screens, {sheet.width}x{sheet.height}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
