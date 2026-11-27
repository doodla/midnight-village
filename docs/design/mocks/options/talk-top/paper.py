"""Cut-paper pieces for the talk-top mocks: paper, torn edges, pins, shadows, felt.

Everything is cut from the app's own renders (frontend/build/screens) and art
(frontend/assets/skins/shadow_paper); nothing here is drawn as a flat box.
Coordinates are the renders' own: 780 x 1688, two pixels to a phone point.
"""

import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[5]
SKIN = ROOT / "frontend/assets/skins/shadow_paper"
FONTS = ROOT / "frontend/assets/fonts"

INK = (27, 27, 48)  # the day's ink on bone paper (sampled from 06's banner)
BONE_TEXT = (236, 228, 210)  # the talk's clock on the sky (sampled from 08)
EDGE = (191, 182, 159)  # the paper's own thickness under a banner (06)
SHADOW = (7, 9, 26)  # night ink for cast shadows


def font(name, size):
    path = {
        "gloock": FONTS / "gloock/Gloock-Regular.ttf",
        "figtree": FONTS / "figtree/Figtree-Medium.ttf",
        "figtree-semi": FONTS / "figtree/Figtree-SemiBold.ttf",
    }[name]
    return ImageFont.truetype(str(path), size)


def art(rel):
    return Image.open(SKIN / rel).convert("RGBA")


class Paper:
    """A tile of clean bone paper cut from 06's banner, between its words."""

    def __init__(self, night_board):
        tile = night_board.crop((350, 100, 500, 212)).convert("RGB")
        row = Image.new("RGB", (tile.width * 2, tile.height))
        row.paste(tile, (0, 0))
        row.paste(tile.transpose(Image.FLIP_LEFT_RIGHT), (tile.width, 0))
        self.tile = Image.new("RGB", (row.width, row.height * 2))
        self.tile.paste(row, (0, 0))
        self.tile.paste(row.transpose(Image.FLIP_TOP_BOTTOM), (0, row.height))

    def fill(self, w, h, seed=0):
        out = Image.new("RGB", (w, h))
        rnd = random.Random(seed)
        ox, oy = rnd.randrange(self.tile.width), rnd.randrange(self.tile.height)
        for y in range(-oy, h, self.tile.height):
            for x in range(-ox, w, self.tile.width):
                out.paste(self.tile, (x, y))
        return out


def deckle_mask(w, h, seed, depth=9, step=(10, 22), sides="tblr"):
    """A rectangle whose sides step in by up to `depth` px in seeded bites."""
    rnd = random.Random(seed)
    pts = []

    def side(n):
        out, pos = [], 0
        while pos < n:
            out.append((pos, rnd.uniform(0, depth)))
            pos += rnd.randint(*step)
        out.append((n, rnd.uniform(0, depth)))
        return out

    d = lambda s: s if s in sides else None
    for x, dd in side(w):
        pts.append((x, dd if d("t") else 0))
    for y, dd in side(h):
        pts.append((w - (dd if d("r") else 0), y))
    for x, dd in reversed(side(w)):
        pts.append((x, h - (dd if d("b") else 0)))
    for y, dd in reversed(side(h)):
        pts.append((dd if d("l") else 0, y))
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).polygon(pts, fill=255)
    return m


def cast_shadow(mask, drop, lean=-0.5):
    """PaperShadow: a tight contact shadow and five stepped flat copies (no blur)."""
    pad = int(drop * 4 + 8)
    w, h = mask.size
    size = (w + 2 * pad, h + 2 * pad)
    acc = np.zeros((size[1], size[0]), int)
    for i in range(5):
        k = (i + 1) / 5
        grown = mask.filter(ImageFilter.MaxFilter(_odd(drop * 2.4 * k)))
        layer = Image.new("L", size, 0)
        layer.paste(grown, (pad + int(lean * drop * k), pad + int(drop * k)))
        acc += (np.asarray(layer) > 128) * 19
    contact = Image.new("L", size, 0)
    contact.paste(mask, (pad + int(lean), pad + int(0.5 + 0.2 * drop)))
    arr = np.maximum(acc, (np.asarray(contact) > 128) * 158)
    return Image.fromarray(arr.clip(0, 255).astype("uint8")), pad


def _odd(v):
    n = max(1, round(v))
    return n if n % 2 else n + 1


def stamp(canvas, piece, xy, drop=4, lean=-0.5):
    """Lay an RGBA piece of paper on the canvas with its paper shadow."""
    alpha = piece.getchannel("A")
    sh, pad = cast_shadow(alpha, drop, lean)
    ink = Image.new("RGBA", sh.size, SHADOW + (0,))
    ink.putalpha(sh)
    _paste_clip(canvas, ink, (xy[0] - pad, xy[1] - pad))
    _paste_clip(canvas, piece, xy)


def _paste_clip(canvas, piece, xy):
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    layer.paste(piece, xy, piece)
    canvas.alpha_composite(layer)


def pin(canvas, xy, r=9):
    """PaperPin: a flat matte pin with its own hard shadow, leaning from the light."""
    d = ImageDraw.Draw(canvas)
    x, y = xy
    d.ellipse((x - r - 3, y - r + 3, x + r - 3, y + r + 3), fill=SHADOW + (150,))
    d.ellipse((x - r, y - r, x + r, y + r), fill=(52, 55, 74, 255))
    d.ellipse((x - r + 4, y - r + 3, x - 1, y - 2), fill=(92, 96, 118, 255))


def paper_piece(paper, w, h, seed, depth=9, edge=6, sides="tblr"):
    """Torn bone paper with its own thickness showing under it (HardShadow.edge)."""
    m = deckle_mask(w, h, seed, depth, sides=sides)
    out = Image.new("RGBA", (w, h + edge), (0, 0, 0, 0))
    under = Image.new("RGBA", (w, h), EDGE + (255,))
    out.paste(under, (0, edge), m)
    face = paper.fill(w, h, seed).convert("RGBA")
    out.paste(face, (0, 0), m)
    return out


def rotate(piece, deg):
    return piece.rotate(deg, resample=Image.BICUBIC, expand=True)


def text_size(draw, text, f):
    b = draw.textbbox((0, 0), text, font=f)
    return b[2] - b[0], b[3] - b[1], b


def clock(draw, right, baseline_top, digit_h, colour, seconds="14"):
    """The talk's clock: the number and a smaller 's', right edge fixed.

    `digit_h` is the height of the digits' ink; the unit is set smaller, as ClockFigure draws it.
    Returns the left x of the number.
    """
    size = int(digit_h / 0.70)
    fnum, funit = font("gloock", size), font("gloock", int(size * 0.42))
    uw, _, ub = text_size(draw, "s", funit)
    nw, nh, nb = text_size(draw, seconds, fnum)
    gap = int(digit_h * 0.12)
    nx = right - uw - gap - nw
    draw.text((nx - nb[0], baseline_top - nb[1]), seconds, font=fnum, fill=colour)
    draw.text(
        (right - uw - ub[0], baseline_top + nh - (ub[3] - ub[1]) - ub[1]),
        "s",
        font=funit,
        fill=colour,
    )
    return nx


def candle(night_board, height):
    """The candle beside 06's clock (CandleGauge), cut with its own paper round it."""
    c = night_board.crop((672, 92, 742, 214)).convert("RGBA")
    m = Image.new("L", c.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((3, 3, c.width - 4, c.height - 4), 14, fill=255)
    c.putalpha(m.filter(ImageFilter.GaussianBlur(3)))
    s = height / c.height
    return c.resize((int(c.width * s), int(height)), Image.LANCZOS)


def felt_body(src, blocks, gaps_new, clean_felt):
    """The board between its top plank and its foot, with the gaps between its blocks re-sized.

    `blocks` are the rows of the deck, the names and My night in the render; the felt and the
    frame's sides between them are cut out or grown (from a clean band of felt) to `gaps_new`.
    """
    top, bottom = 237, 1455
    edges = [top] + [y for b in blocks for y in b] + [bottom]
    gaps_old = [(edges[i], edges[i + 1]) for i in range(0, len(edges), 2)]
    parts = []
    for i, (g0, g1) in enumerate(gaps_old):
        parts.append(_gap(src, g0, g1, gaps_new[i], clean_felt))
        if i < len(blocks):
            parts.append(src.crop((0, blocks[i][0], src.width, blocks[i][1])))
    h = sum(p.height for p in parts)
    out = Image.new("RGBA", (src.width, h))
    y = 0
    for p in parts:
        out.paste(p, (0, y))
        y += p.height
    return out


def _gap(src, g0, g1, n, clean):
    old = g1 - g0
    out = Image.new("RGBA", (src.width, max(n, 0)))
    if n <= 0:
        return out
    if n <= old:
        a = n // 2
        out.paste(src.crop((0, g0, src.width, g0 + a)), (0, 0))
        out.paste(src.crop((0, g1 - (n - a), src.width, g1)), (0, a))
        return out
    a = old // 2
    out.paste(src.crop((0, g0, src.width, g0 + a)), (0, 0))
    y = a
    while y < n - (old - a):
        piece = clean.crop((0, 0, src.width, min(clean.height, n - (old - a) - y)))
        out.paste(piece, (0, y))
        y += piece.height
    out.paste(src.crop((0, g0 + a, src.width, g1)), (0, n - (old - a)))
    return out


def plan_gaps(old, flex, minimum=None, fixed_last=13):
    """Share `flex` rows among the gaps, in today's proportions, with a floor for each."""
    minimum = minimum or [0] * len(old)
    body = old[:-1]
    rest = flex - fixed_last
    s = rest / sum(body)
    new = [g * s for g in body]
    for _ in range(4):
        short = [i for i, g in enumerate(new) if g < minimum[i]]
        if not short:
            break
        for i in short:
            new[i] = minimum[i]
        free = [i for i in range(len(new)) if i not in short]
        left = rest - sum(new[i] for i in short)
        tot = sum(body[i] for i in free)
        for i in free:
            new[i] = body[i] * left / tot
    new = [round(g) for g in new]
    new[-1] += rest - sum(new)
    return new + [fixed_last]


def swing(piece, deg, anchor):
    """Turn a hanging piece round the point it hangs from."""
    w, h = piece.size
    big = Image.new("RGBA", (w * 3, h * 3), (0, 0, 0, 0))
    big.paste(piece, (w, h))
    ax, ay = anchor[0] + w, anchor[1] + h
    return big.rotate(deg, resample=Image.BICUBIC, center=(ax, ay)), (ax, ay)


def sag(x0, y0, x1, y1, depth, n=60):
    """Points of a cord hung between two nails."""
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append(
            (x0 + (x1 - x0) * t, y0 + (y1 - y0) * t + depth * math.sin(math.pi * t))
        )
    return pts
