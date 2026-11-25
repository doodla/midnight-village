"""Contact sheets for the night's atmosphere art, to judge it by eye.

    uv run --with numpy --with pillow python tool/atmo/sheets.py <out folder>

(from frontend/, after `just skin-art`). Writes, from the shipped WebP:
- flame-sheet.png: the frames in a row at 4x on the night ground; today's flame
  beside frame 1 at 8x; every frame on the candle as the night board draws it
  (CandleGauge, 90 px high) at a phone's 3x.
- flame-burst.webp: the burst on that candle at 3x, looping (rest, the seven
  frames in about 0.7 s, rest).
- moon-sheet.png: the phases at 2x the village canvas (about 4x their size on a
  390-wide phone), then each in the night village at the canvas's own pixels
  (about 2x a phone's), every layer in its order, the phase laid on the moon.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
SKIN = ROOT / "frontend/assets/skins/shadow_paper"
LAYERS = ROOT / "docs/design/art/layers/night-village"
GROUND = (0x14, 0x17, 0x2F, 255)
SHADOW = (0x07, 0x09, 0x1A)
PANEL = (0x1D, 0x21, 0x45, 255)

# The candle's canvas (shadow_paper.dart, _candle).
VIEW = (40, 12, 280, 484)
WAX_AT, HOLDER_AT, FLAME_AT = (58, 107), (36, 328), (60, 15)
WICK = (120, 121)
LIGHT = (0xE9, 0xA4, 0x4A)


def rgba(path):
    return Image.open(path).convert("RGBA")


def tint(im, colour):
    out = Image.new("RGBA", im.size, colour + (255,))
    out.putalpha(im.getchannel("A"))
    return out


def candle(flame: Image.Image, height: float, dpr: float) -> Image.Image:
    """The candle as CandleGauge draws it whole ([share] null), [height]
    logical px high at [dpr]: glow, hard shadows, wax, holder, flame, ledge."""
    wax, holder = rgba(SKIN / "candle/wax.webp"), rgba(SKIN / "candle/holder.webp")
    c = Image.new("RGBA", (300, 530), GROUND)
    scale = height / (VIEW[3] - VIEW[1])  # logical px per canvas px
    # the warm light behind the flame
    cx, cy = WICK[0], WICK[1] - 106 * 0.45
    rad = 120 * (0.9 + 0.7)
    yy, xx = np.mgrid[0:530, 0:300]
    t = np.hypot(xx - cx, yy - cy) / rad
    a = np.interp(t, [0, 0.45, 1], [0.3, 0.1, 0.0])
    glow = np.zeros((530, 300, 4), np.uint8)
    glow[..., :3] = LIGHT
    glow[..., 3] = (a * 255).astype(np.uint8)
    c.alpha_composite(Image.fromarray(glow, "RGBA"))
    off = round(1.5 * min(max(height / 90, 0.8), 1.6) / scale)
    c.alpha_composite(tint(holder, SHADOW), (HOLDER_AT[0] + off, HOLDER_AT[1] + off))
    sh = Image.new("RGBA", c.size, (0, 0, 0, 0))
    sh.alpha_composite(tint(wax, SHADOW), (WAX_AT[0] + off, WAX_AT[1] + off))
    c.alpha_composite(sh.crop((0, 0, 300, 385 + off)), (0, 0))
    c.alpha_composite(wax.crop((0, 0, wax.width, 385 - WAX_AT[1])), WAX_AT)
    c.alpha_composite(holder, HOLDER_AT)
    c.alpha_composite(flame, FLAME_AT)
    c = c.crop(VIEW)
    w, h = round(c.width * scale * dpr), round(height * dpr)
    out = c.resize((w, h), Image.LANCZOS)
    d = ImageDraw.Draw(out)
    lh = round(min(max(height / 20, 4), 7) * dpr)
    d.rectangle((-round(w * 0.04), h - lh, w, h), fill=PANEL)
    return out


def label(im, text):
    ImageDraw.Draw(im).text((6, 4), text, fill=(170, 176, 207, 255))


def flame_sheet(out: Path) -> None:
    frames = [rgba(SKIN / f"atmo/flame/flame_{i}.webp") for i in range(1, 9)]
    today = rgba(SKIN / "candle/flame.webp")
    gap = 16
    row1 = Image.new("RGBA", (8 * (480 + gap) + gap, 424 + 2 * gap), GROUND)
    for i, f in enumerate(frames):
        row1.alpha_composite(
            f.resize((480, 424), Image.NEAREST), (gap + i * (480 + gap), gap)
        )
        label_box = Image.new("RGBA", (40, 18), GROUND)
        label(label_box, str(i + 1))
        row1.alpha_composite(label_box, (gap + i * (480 + gap), 0))
    row2 = Image.new("RGBA", (2 * 960 + 3 * gap, 848 + 2 * gap), GROUND)
    row2.alpha_composite(today.resize((960, 848), Image.NEAREST), (gap, gap))
    row2.alpha_composite(
        frames[0].resize((960, 848), Image.NEAREST), (2 * gap + 960, gap)
    )
    label(
        row2,
        "today's flame.webp (8x)                                                    frame 1 (8x)",
    )
    cands = [candle(today, 90, 3)] + [candle(f, 90, 3) for f in frames]
    cw, ch = cands[0].size
    row3 = Image.new("RGBA", (len(cands) * (cw + gap) + gap, ch + 2 * gap), GROUND)
    for i, cd in enumerate(cands):
        row3.alpha_composite(cd, (gap + i * (cw + gap), gap))
    label(row3, "today, then frames 1-8, on the candle at 90 px, 3x")
    ones = [candle(today, 90, 1)] + [candle(f, 90, 1) for f in frames]
    w1, h1 = ones[0].size
    row4 = Image.new("RGBA", (len(ones) * (w1 + gap) + gap, h1 + 2 * gap), GROUND)
    for i, cd in enumerate(ones):
        row4.alpha_composite(cd, (gap + i * (w1 + gap), gap))
    rows = [row1, row2, row3, row4]
    sheet = Image.new(
        "RGBA", (max(r.width for r in rows), sum(r.height for r in rows)), GROUND
    )
    y = 0
    for r in rows:
        sheet.alpha_composite(r, (0, y))
        y += r.height
    sheet.convert("RGB").save(out / "flame-sheet.png", optimize=True)
    # the burst
    seq = [candle(f, 90, 3) for f in frames]
    order = [0, 1, 2, 3, 4, 5, 6, 7, 0]
    ms = [1400, 70, 90, 110, 100, 90, 90, 110, 600]
    pics = [seq[i].crop((0, 0, cw, ch)) for i in order]
    pics[0].save(
        out / "flame-burst.webp",
        save_all=True,
        append_images=pics[1:],
        duration=ms,
        loop=0,
        lossless=True,
    )


def village(phase: Image.Image | None, anchor=(0, 0), clouds=True) -> Image.Image:
    """The night village with every layer at rest and [phase] on the moon
    (without the clouds themselves when not [clouds])."""

    def at(name):
        im = rgba(LAYERS / name)
        if im.width == 800:  # 16 px of bleed each side
            im = im.crop((16, 0, 784, 1024))
        return im

    v = rgba(LAYERS / "village_plate.png")
    for n in ("clouds_dark_shadow_bleed16.png", "clouds_cream_shadow_bleed16.png"):
        v.alpha_composite(at(n))
    moon = at("moon.png")
    v.alpha_composite(moon)
    moon_a = np.asarray(moon.getchannel("A")).astype(np.float32) / 255
    for n in ("moon_shadow_dark.png", "moon_shadow_cream.png"):
        s = np.asarray(at(n)).astype(np.float32)
        s[..., 3] *= moon_a  # clipTo: 'moon'
        v.alpha_composite(Image.fromarray(s.astype(np.uint8), "RGBA"))
    # the phase: over the moon and the clouds' shadows on it, under the clouds
    if phase is not None:
        p = Image.new("RGBA", v.size, (0, 0, 0, 0))
        p.alpha_composite(phase, anchor)
        v.alpha_composite(p)
    for n in ("clouds_dark_bleed16.png", "clouds_cream_bleed16.png") if clouds else ():
        v.alpha_composite(at(n))
    return v


# The phases in the month's order; None is the full moon (no file).
PHASES = [
    "crescent_thin_waxing", "crescent_fat_waxing", "gibbous_thin_waxing",
    "gibbous_fat_waxing", None, "gibbous_fat_waning", "gibbous_thin_waning",
    "crescent_fat_waning", "crescent_thin_waning",
]


def moon_sheet(out: Path) -> None:
    gap = 12
    crop = (470, 50, 744, 330)
    tiles, scenes = [], []
    for name in PHASES:
        webp, box = None, (0, 0)
        if name is not None:
            master = rgba(ROOT / f"docs/design/art/atmo/moon/{name}.png")
            box = master.getchannel("A").getbbox()[:2]
            webp = rgba(SKIN / f"atmo/moon/{name}.webp")
        v = village(webp, box)
        t = village(webp, box, clouds=False).crop(crop)
        tiles.append(t.resize((t.width * 2, t.height * 2), Image.NEAREST))
        scenes.append(v.crop((300, 0, 768, 420)))
    tw, th = tiles[0].size
    sw, sh = scenes[0].size
    cols = 5
    a = Image.new("RGBA", (cols * (tw + gap) + gap, 2 * (th + gap) + gap), GROUND)
    for i, t in enumerate(tiles):
        a.alpha_composite(
            t, (gap + (i % cols) * (tw + gap), gap + (i // cols) * (th + gap))
        )
    b = Image.new("RGBA", (cols * (sw + gap) + gap, 2 * (sh + gap) + gap), GROUND)
    for i, s in enumerate(scenes):
        b.alpha_composite(
            s, (gap + (i % cols) * (sw + gap), gap + (i // cols) * (sh + gap))
        )
    sheet = Image.new("RGBA", (max(a.width, b.width), a.height + b.height), GROUND)
    sheet.alpha_composite(a, (0, 0))
    sheet.alpha_composite(b, (0, a.height))
    sheet.convert("RGB").save(out / "moon-sheet.png", optimize=True)


def main() -> None:
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    flame_sheet(out)
    moon_sheet(out)
    print(
        "wrote",
        out / "flame-sheet.png",
        out / "flame-burst.webp",
        out / "moon-sheet.png",
    )


if __name__ == "__main__":
    main()
