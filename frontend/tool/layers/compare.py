"""How far a `run.sh` run is from the committed masters.

    uv run --with numpy --with pillow python tool/layers/compare.py <work-folder>/out

Prints, for every master in docs/design/art/layers/, the mean and largest difference (8-bit, all
channels, alpha included) from the layer the run made. A run is a reproduction when the means are
near 0; the masters were exported from these scripts and kept as they came out.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ART = Path(__file__).resolve().parents[3] / "docs" / "design" / "art" / "layers"
PREFIX = {"night-village": "04_", "dawn-gallows": "08_"}


def main() -> None:
    out = Path(sys.argv[1])
    for scene, prefix in PREFIX.items():
        for master in sorted((ART / scene).glob("*.png")):
            made = out / f"{prefix}{master.name}"
            if not made.exists():
                print(f"{scene}/{master.name}: not made by the run")
                continue
            a = np.asarray(Image.open(master).convert("RGBA")).astype(int)
            b = np.asarray(Image.open(made).convert("RGBA")).astype(int)
            if a.shape != b.shape:
                print(f"{scene}/{master.name}: size {a.shape} against {b.shape}")
                continue
            d = np.abs(a - b)
            print(f"{scene}/{master.name}: mean {d.mean():.3f} max {d.max()}")


if __name__ == "__main__":
    main()
