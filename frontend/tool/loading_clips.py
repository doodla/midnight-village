#!/usr/bin/env python3
"""Puts the frames of `test_screens/loading_clips_test.dart` together as looping
animated WebPs (390 wide, each under 1.2 MB).

usage: tool/loading_clips.py <frames dir> <out dir>

Each clip is a folder of `NNN-<ms>.png` (how long that frame stays). The
quality is lowered until the file is under the limit.
"""
import sys
from pathlib import Path

from PIL import Image

LIMIT = 1_200_000


def build(folder: Path, out: Path) -> None:
    files = sorted(folder.glob("*.png"))
    images = [Image.open(f).convert("RGB") for f in files]
    durations = [int(f.stem.split("-")[1]) for f in files]
    target = out / f"{folder.name}.webp"
    for quality in (70, 60, 50, 40, 30, 20):
        images[0].save(
            target,
            save_all=True,
            append_images=images[1:],
            duration=durations,
            loop=0,
            quality=quality,
            method=4,
        )
        if target.stat().st_size < LIMIT:
            break
    print(f"{target}  {len(images)} frames  {target.stat().st_size // 1024} KB  q{quality}")


def main() -> None:
    frames, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    for folder in sorted(p for p in frames.iterdir() if p.is_dir()):
        build(folder, out)


main()
