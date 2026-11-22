"""Joins the type-size review's pictures: per screen, today | compact | tight side by side
at full resolution with a label under each, and one overview of all six.

    uv run --with pillow python tool/type_scale_sheet.py [in_dir] [out_dir]

Reads <in_dir>/<screen>-<scale>.png (written by test_screens/type_scale_options_test.dart,
once per `--dart-define=TYPE_SCALE=today|compact|tight`). See docs/design/type-audit.md.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

SCALES = ["today", "compact", "tight"]
LABELS = {"today": "Today", "compact": "Compact", "tight": "Tight"}
BG = (32, 28, 36)
INK = (230, 224, 214)
GAP = 24
LABEL_H = 56


def font(size):
    for name in ("DejaVuSans-Bold.ttf", "Arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def main(argv):
    src = Path(argv[1] if len(argv) > 1 else "build/typescale")
    out = Path(argv[2] if len(argv) > 2 else src / "sheets")
    out.mkdir(parents=True, exist_ok=True)
    screens = sorted({p.name.rsplit("-", 1)[0] for p in src.glob("*-today.png")})
    sheets = []
    for screen in screens:
        images = [Image.open(src / f"{screen}-{s}.png").convert("RGB") for s in SCALES]
        w, h = images[0].size
        sheet = Image.new("RGB", (3 * w + 4 * GAP, h + LABEL_H + 2 * GAP), BG)
        draw = ImageDraw.Draw(sheet)
        for i, (scale, im) in enumerate(zip(SCALES, images)):
            x = GAP + i * (w + GAP)
            sheet.paste(im, (x, GAP))
            draw.text(
                (x, GAP + h + 12), f"{screen}  {LABELS[scale]}", fill=INK, font=font(28)
            )
        name = f"{screen}-today-compact-tight.png"
        sheet.save(out / name)
        sheets.append((screen, sheet))
        print(out / name)
    # The overview: all six, two rows of three screens, each screen's three scales.
    cell_w = 1000
    cells = []
    for screen, sheet in sheets:
        scale = cell_w / sheet.width
        cells.append(sheet.resize((cell_w, round(sheet.height * scale)), Image.LANCZOS))
    cols = 2
    rows = [cells[i : i + cols] for i in range(0, len(cells), cols)]
    row_h = [max(c.height for c in r) for r in rows]
    overview = Image.new(
        "RGB", (cols * cell_w + (cols + 1) * 10, sum(row_h) + (len(rows) + 1) * 10), BG
    )
    y = 10
    for r, rh in zip(rows, row_h):
        for i, c in enumerate(r):
            overview.paste(c, (10 + i * (cell_w + 10), y))
        y += rh + 10
    overview.save(out / "overview.png")
    print(out / "overview.png", overview.size)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
