"""Options for the top of the talk screen (08): today, A, B and C, at 5 and 10 players.

A: one banner (the night's and your card's) over the night sky. B: the board's roof at the top and the clock on a
paper sign hung from its eave; at 6 players or fewer the deck is drawn larger. C: a strip of night sky with the
roofline and the moon, the clock on the same sign hung from the lantern's bracket.

Each picture is cut from the app's own renders of main (25 Nov 2026; `just screens`) and its art,
then scaled to a 412 pt phone (824 px). Run from anywhere:

    python3 docs/design/mocks/options/talk-top/make_mocks.py [--screens <dir of renders>]

The renders used: 08-talk-put-away (5 players, My night put away), 08-talk-10-long (10 players),
06-night-board (its banner's paper, clock and candle).
"""

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

import paper as P

HERE = Path(__file__).resolve().parent
W, H = 780, 1688
OUT_W = 824
# The rows of the deck, the names and My night in each render (the gaps between are felt).
BLOCKS = {
    5: [(352, 797), (962, 1126), (1258, 1442)],
    10: [(248, 797), (822, 1226), (1258, 1442)],
}
CORD = (176, 156, 120, 255)
# B at 5 players: the deck's piles (x0, y0, x1, y1 in 08-talk-put-away), drawn larger in two columns.
PILES = [
    (52, 355, 238, 535),
    (256, 355, 443, 536),
    (472, 355, 714, 554),
    (167, 573, 389, 792),
    (435, 574, 626, 792),
]


def load(screens, name):
    return Image.open(screens / f"{name}.png").convert("RGBA")


def body(src, n, height, g0_min=0):
    blocks = BLOCKS[n]
    edges = [237] + [y for b in blocks for y in b] + [1455]
    old = [edges[i + 1] - edges[i] for i in range(0, len(edges), 2)]
    flex = height - sum(b[1] - b[0] for b in blocks)
    gaps = P.plan_gaps(old, flex, [g0_min, 24, 24, 0])
    return P.felt_body(src, blocks, gaps, CLEAN)


def stack(parts):
    out = Image.new("RGBA", (W, H))
    y = 0
    for p in parts:
        out.paste(p, (0, y))
        y += p.height
    assert y == H, y
    return out


# ---------------------------------------------------------------- A: one banner everywhere
def night_sky(h):
    """The night village's sky, the game's moon and the village roofline in front of it."""
    plate = P.art("layers/night_village/village_plate.webp").crop((0, 0, 768, 300))
    sky = plate.resize((W, int(300 * W / 768)), Image.LANCZOS).crop((0, 0, W, h))
    moon = (
        P.art("layers/night_village/moon.webp")
        .crop((37, 75, 262, 296))
        .resize((150, 147), Image.LANCZOS)
    )
    glow = Image.new("RGBA", (W, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i, r in enumerate(range(170, 70, -10)):
        gd.ellipse((700 - r, 170 - r, 700 + r, 170 + r), fill=(220, 226, 255, 5 + i))
    sky.alpha_composite(glow)
    sky.alpha_composite(moon, (628, 98))
    roofs = P.art("layers/dawn_gallows/roofs_mid.webp")
    roofs = roofs.resize((W, int(roofs.height * W / roofs.width)), Image.LANCZOS)
    rgb = ImageEnhance.Brightness(roofs.convert("RGB")).enhance(0.85)
    rgb = Image.blend(rgb, Image.new("RGB", rgb.size, (20, 24, 58)), 0.22).convert(
        "RGBA"
    )
    rgb.putalpha(roofs.getchannel("A"))
    sky.alpha_composite(rgb, (0, h - 262))
    return sky


def banner(paper, nb, w, h, title):
    piece = P.paper_piece(paper, w, h, seed=8, depth=9)
    d = ImageDraw.Draw(piece)
    f = P.font("gloock", 48)
    _, th, tb = P.text_size(d, title, f)
    d.text((34 - tb[0], (h - th) // 2 - tb[1] - 2), title, font=f, fill=P.INK)
    c = P.candle(nb, 78)
    cx = w - 30 - c.width
    piece.alpha_composite(c, (cx, (h - c.height) // 2 + 2))
    P.clock(d, cx - 10, (h - 58) // 2, 58, P.INK)
    P.pin(piece, (26, 14))
    P.pin(piece, (w - 14, 12))
    return P.rotate(piece, -0.7)


def option_a(t, n, nb, paper):
    sky_h = 220
    top = night_sky(sky_h)
    b = banner(paper, nb, 676, 112, "The village wakes")
    P.stamp(top, b, (12, 36), drop=6, lean=-0.6)
    plank = t.crop((0, 200, W, 237))
    foot = t.crop((0, 1455, W, H))
    return stack([top, plank, body(t, n, H - sky_h - 37 - foot.height), foot])


# ---------------------------------------------------------------- B: the board's own sign
def pile(t, box, scale):
    """One pile of the deck lifted off the felt with its shadow, drawn `scale` times larger."""
    x0, y0, x1, y1 = box
    m = 16
    crop = t.crop((x0 - m, y0 - m, x1 + m, y1 + m))
    dev = np.abs(
        np.asarray(crop.convert("RGB")).astype(int) - np.array([38, 43, 92])
    ).sum(axis=2)
    keep = dev > 40
    keep[:, :8] = keep[:, -8:] = (
        False  # the crop's own edge (the frame can reach into it)
    )
    keep[:8], keep[-8:] = False, False
    alpha = Image.fromarray((keep * 255).astype("uint8"))
    alpha = alpha.filter(ImageFilter.MaxFilter(11)).filter(ImageFilter.GaussianBlur(4))
    crop.putalpha(alpha)
    return crop.resize(
        (round(crop.width * scale), round(crop.height * scale)), Image.LANCZOS
    ), m


def large_deck_body(t, height, g0, scale=1.15):
    """At 6 players or fewer: the piles larger, in two columns, and the three groups spaced evenly."""
    tiles = Image.new("RGBA", (W, height))
    for y in range(0, height, CLEAN.height):
        tiles.paste(CLEAN, (0, y))
    rows = [PILES[0:2], PILES[2:4], PILES[4:5]]
    row_h = [round(max(b[3] - b[1] for b in r) * scale) for r in rows]
    deck_h = sum(row_h) + 2 * 22
    names = t.crop((0, 962, W, 1126))
    note = t.crop((0, 1258, W, 1442))
    free = height - g0 - 13 - deck_h - names.height - note.height
    gap = free / 2.8
    y = g0 + round(gap * 0.4)
    for r, h in zip(rows, row_h):
        sprites = [pile(t, b, scale) for b in r]
        widths = [s.width - 2 * m * scale for s, m in sprites]
        x = (W - sum(widths) - 44 * (len(r) - 1)) / 2
        for (s, m), w in zip(sprites, widths):
            tiles.alpha_composite(s, (round(x - m * scale), round(y - m * scale)))
            x += w + 44
        y += h + 22
    y += round(gap) - 22
    tiles.paste(names, (0, y))
    tiles.paste(note, (0, y + names.height + round(gap)))
    return tiles


def lantern(height):
    lan = P.art("end/lantern.webp").transpose(Image.FLIP_LEFT_RIGHT)
    return lan.resize((int(lan.width * height / lan.height), height), Image.LANCZOS)


def sign(paper, nb):
    w, h = 232, 104
    piece = P.paper_piece(paper, w, h, seed=21, depth=9)
    d = ImageDraw.Draw(piece)
    c = P.candle(nb, 74)
    cx = w - 22 - c.width
    piece.alpha_composite(c, (cx, (h - c.height) // 2 + 2))
    P.clock(d, cx - 8, (h - 60) // 2, 60, P.INK)
    P.pin(piece, (22, 13))
    P.pin(piece, (w - 14, 12))
    return P.rotate(piece, 0.8)


def option_b(t, n, nb, paper):
    top = Image.new("RGBA", (W, 136))
    top.paste(clear_clock(t).crop((0, 101, W, 141)), (0, 0))
    top.paste(t.crop((0, 141, W, 237)), (0, 40))
    foot = t.crop((0, 1455, W, H))
    sign_top, sign_bottom = 112, 230
    g0 = sign_bottom + 16 - 136
    if n <= 6:
        board = large_deck_body(t, H - 136 - foot.height, g0)
    else:
        board = body(t, n, H - 136 - foot.height, g0_min=g0)
    page = stack([top, board, foot])
    d = ImageDraw.Draw(page)
    s = sign(paper, nb)
    sx = (W - s.width) // 2
    for nx in (sx + 26, sx + s.width - 16):  # cords from the eave to the sign's pins
        d.line([(nx, 92), (nx, sign_top + 14)], fill=CORD, width=5)
        d.ellipse((nx - 5, 88, nx + 5, 98), fill=(40, 40, 52, 255))
    P.stamp(page, s, (sx, sign_top), drop=6, lean=-0.6)
    lan = lantern(181)
    page.alpha_composite(lan, (645 - 6, -50))
    return page


# ---------------------------------------------------------------- the clock off today's sky (B)
def clear_clock(img):
    """Take today's big clock off the sky (filled down each column, so the gallows post stays)."""
    a = np.asarray(img).astype(float)
    x0, x1, y0, y1 = 334, 446, 56, 134
    lum = a[y0:y1, x0:x1, :3].mean(axis=2)
    mask = lum > 120
    grow = mask.copy()
    for dy in (-3, -2, -1, 1, 2, 3):
        grow |= np.roll(mask, dy, axis=0)
    for dx in (-3, -2, -1, 1, 2, 3):
        grow |= np.roll(mask, dx, axis=1)
    for j in range(x1 - x0):
        col = grow[:, j]
        ys = np.where(~col)[0]
        if len(ys) == 0:
            continue
        for i in np.where(col)[0]:
            above, below = ys[ys < i], ys[ys > i]
            ya = above.max() if len(above) else below.min()
            yb = below.min() if len(below) else above.max()
            t = 0 if yb == ya else (i - ya) / (yb - ya)
            a[y0 + i, x0 + j] = a[y0 + ya, x0 + j] * (1 - t) + a[y0 + yb, x0 + j] * t
    return Image.fromarray(a.astype("uint8"))


# ---------------------------------------------------------------- C: the square's sky
def bracket(page, x0, x1, y):
    """The lantern's iron bracket carried out along the eave: a bar, a brace and a curl."""
    d = ImageDraw.Draw(page)
    iron, shade = (34, 38, 40, 255), (7, 9, 26, 150)
    for off, col in (((-3, 4), shade), ((0, 0), iron)):
        ox, oy = off
        d.line([(x0 + ox, y + oy), (x1 + ox, y + oy)], fill=col, width=7)
        d.line(
            [(x1 - 4 + ox, y + 52 + oy), (x1 - 120 + ox, y + 2 + oy)], fill=col, width=5
        )
        d.arc(
            (x0 - 14 + ox, y - 2 + oy, x0 + 10 + ox, y + 22 + oy),
            90,
            360,
            fill=col,
            width=5,
        )


def option_c(t, n, nb, paper):
    sky = Image.new("RGBA", (W, 141))
    plate = P.art("layers/night_village/village_plate.webp").crop((0, 0, 768, 300))
    sky.paste(plate.resize((W, int(300 * W / 768)), Image.LANCZOS).crop((0, 0, W, 141)))
    glow = Image.new("RGBA", (W, 141), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i, r in enumerate(range(130, 50, -10)):
        gd.ellipse((170 - r, 84 - r, 170 + r, 84 + r), fill=(220, 226, 255, 5 + i))
    sky.alpha_composite(glow)
    moon = P.art("layers/night_village/moon.webp").crop((37, 75, 262, 296))
    sky.alpha_composite(moon.resize((92, 90), Image.LANCZOS), (124, 40))
    roofs = P.art("layers/dawn_gallows/roofs_mid.webp")
    roofs = roofs.resize((W, int(roofs.height * W / roofs.width)), Image.LANCZOS)
    rgb = ImageEnhance.Brightness(roofs.convert("RGB")).enhance(0.85)
    rgb = Image.blend(rgb, Image.new("RGB", rgb.size, (20, 24, 58)), 0.22).convert(
        "RGBA"
    )
    rgb.putalpha(roofs.getchannel("A"))
    sky.alpha_composite(rgb, (0, 141 - 232))
    roof = t.crop((0, 141, W, 237))
    roof.paste(
        t.crop((520, 141, 625, 200)), (630, 0)
    )  # the slate under today's lantern
    page = stack([sky, roof, t.crop((0, 237, W, H))])
    bracket(page, 372, 742, 30)
    s = sign(paper, nb)
    sx, sy = 392, 50
    d = ImageDraw.Draw(page)
    for nx in (sx + 26, sx + s.width - 16):  # cords from the bracket to the sign's pins
        d.line([(nx, 33), (nx, sy + 14)], fill=CORD, width=5)
    P.stamp(page, s, (sx, sy), drop=6, lean=-0.6)
    page.alpha_composite(lantern(181), (639, -1))
    return page


# ---------------------------------------------------------------- out
def save(img, name):
    out = img.convert("RGB").resize((OUT_W, round(H * OUT_W / W)), Image.LANCZOS)
    out.save(HERE / f"{name}.png", optimize=True)
    return out


def sheet(pictures):
    cols, cw, ch, pad, head = 4, 412, 892, 24, 56
    w = cols * cw + (cols + 1) * pad
    h = 2 * (ch + head) + 3 * pad
    out = Image.new("RGB", (w, h), (24, 24, 32))
    d = ImageDraw.Draw(out)
    f = P.font("figtree-semi", 24)
    for i, (label, img) in enumerate(pictures):
        r, c = divmod(i, cols)
        x = pad + c * (cw + pad)
        y = pad + r * (ch + head + pad)
        d.text((x, y + 12), label, font=f, fill=(236, 228, 210))
        out.paste(img.resize((cw, ch), Image.LANCZOS), (x, y + head))
    out.save(HERE / "sheet.png", optimize=True)


def main():
    global CLEAN
    ap = argparse.ArgumentParser()
    ap.add_argument("--screens", type=Path, default=P.ROOT / "frontend/build/screens")
    screens = ap.parse_args().screens
    talk = {5: load(screens, "08-talk-put-away"), 10: load(screens, "08-talk-10-long")}
    nb = load(screens, "06-night-board")
    CLEAN = talk[5].crop((0, 800, W, 958))
    paper = P.Paper(nb)
    made = {}
    for n in (5, 10):
        made[f"today-{n}"] = save(talk[n], f"today-{n}")
        made[f"a-{n}"] = save(option_a(talk[n], n, nb, paper), f"a-{n}")
        made[f"b-{n}"] = save(option_b(talk[n], n, nb, paper), f"b-{n}")
        made[f"c-{n}"] = save(option_c(talk[n], n, nb, paper), f"c-{n}")
    labels = {
        "today": "Today",
        "a": "A  One banner (+ words)",
        "b": "B  The board's sign",
        "c": "C  The square's sky",
    }
    sheet(
        [
            (f"{labels[k]}, {n} players", made[f"{k}-{n}"])
            for n in (5, 10)
            for k in ("today", "a", "b", "c")
        ]
    )


CLEAN = None

if __name__ == "__main__":
    main()
