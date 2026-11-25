"""Cuts the moth out of its token (prototype `atmosphere-proto`), for the moth that visits the candle.

No image model: the bone-paper moth is kept by its brightness, the token's disc dropped, and
the cut cropped to the moth. Writes `assets/skins/shadow_paper/atmo/moth.webp`.

    uv run --with numpy --with pillow python frontend/tool/atmo/moth_cut.py
"""

import pathlib

import numpy as np
from PIL import Image

HERE = pathlib.Path(__file__).resolve().parents[2]
TOKEN = HERE / "assets/skins/shadow_paper/tokens/moth.webp"
OUT = HERE / "assets/skins/shadow_paper/atmo/moth.webp"

rgb = np.asarray(Image.open(TOKEN).convert("RGB"), float)
lum = rgb @ np.array([0.299, 0.587, 0.114])
alpha = np.clip((lum - 120) / 50, 0, 1)
# Only the middle of the token: its ring is bright too.
h, w = lum.shape
yy, xx = np.mgrid[0:h, 0:w]
alpha *= ((xx - w / 2) ** 2 + (yy - h / 2) ** 2) < (0.40 * w) ** 2
out = Image.fromarray(np.dstack([rgb, alpha * 255]).astype(np.uint8), "RGBA")
out = out.crop(out.getbbox()).resize((48, 48 * out.height // out.width), Image.LANCZOS)
out.save(OUT, "WEBP", quality=90, method=6)
print(OUT, OUT.stat().st_size, "bytes", out.size)
