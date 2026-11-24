"""The contact sheets of a hand-over (tool/handover.py): main | this change | changed.

    uv run --with pillow python tool/handover_sheet.py <run> <out> <state>...

Reads <run>/<width>x<height>/after/<state>.png and .../before/<state>.png for
each size drawn. For every state whose pixels differ from main at some size (or
that main does not have), writes

    <out>/<state>-<width>x<height>.png   the three panels at full size
    <out>/sheet-<n>.png                  those rows, a few to a page, scaled to read

and prints, as JSON, which states changed, which are new, which could not be
drawn, and the sheets. A state identical to main at every size is listed by the
hand-over and not drawn on a sheet: a reviewer opens the changes, not forty
panels of nothing.
"""

import json
import sys
from pathlib import Path

from look_compare import BG, GAP, changed, labelled
from PIL import Image

# A page is read whole by a reviewer: rows to a page, and its width in pixels.
ROWS_A_PAGE = 3
PAGE_WIDTH = 2400


def main(argv: list[str]) -> int:
    run, out, states = Path(argv[1]), Path(argv[2]), argv[3:]
    out.mkdir(parents=True, exist_ok=True)
    for stale in [*out.glob("sheet-*.png"), *out.glob("*-*x*.png")]:
        stale.unlink()
    sizes = sorted(p.name for p in run.iterdir() if p.is_dir())
    rows: list[Image.Image] = []
    moved, new, missing = [], [], []
    for state in states:
        for size in sizes:
            after_file = run / size / "after" / f"{state}.png"
            before_file = run / size / "before" / f"{state}.png"
            if not after_file.is_file():
                if state not in missing:
                    missing.append(state)
                continue
            after = Image.open(after_file).convert("RGB")
            if before_file.is_file():
                before = Image.open(before_file).convert("RGB")
                diff, count = changed(before, after)
                if not count:
                    continue
                panels = [
                    (f"{state}  {size}  main", before),
                    ("this change", after),
                    (f"{count} pixels changed", diff),
                ]
                if state not in moved:
                    moved.append(state)
            else:
                panels = [(f"{state}  {size}  new (main has no such state)", after)]
                if state not in new:
                    new.append(state)
            row = labelled(panels)
            row.save(out / f"{state}-{size}.png")
            rows.append(row)
    sheets = []
    for number, start in enumerate(range(0, len(rows), ROWS_A_PAGE), 1):
        page_rows = []
        for row in rows[start : start + ROWS_A_PAGE]:
            scale = min(1.0, PAGE_WIDTH / row.width)
            page_rows.append(
                row.resize(
                    (int(row.width * scale), int(row.height * scale)), Image.LANCZOS
                )
            )
        page = Image.new(
            "RGB",
            (
                max(r.width for r in page_rows),
                sum(r.height for r in page_rows) + GAP * len(page_rows),
            ),
            BG,
        )
        y = 0
        for row in page_rows:
            page.paste(row, (0, y))
            y += row.height + GAP
        target = out / f"sheet-{number}.png"
        page.save(target)
        sheets.append(str(target))
    print(
        json.dumps({"changed": moved, "new": new, "missing": missing, "sheets": sheets})
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
