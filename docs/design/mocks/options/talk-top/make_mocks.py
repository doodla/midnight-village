"""Options for the top of the talk screen (08): today, A, B and C, at 5 and 10 players.

Each picture is cut from the app's own renders of main (25 Nov 2026; `just screens`) and its art,
then scaled to a 412 pt phone (824 px). Run from anywhere:

    python3 docs/design/mocks/options/talk-top/make_mocks.py [--screens <dir of renders>]

The renders used: 08-talk-put-away (5 players, My night put away), 08-talk-10-long (10 players),
06-night-board (its banner's paper, clock and candle).
"""

import argparse
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance

import paper as P

HERE = Path(__file__).resolve().parent
W, H = 780, 1688
OUT_W = 824
# The rows of the deck, the names and My night in each render (the gaps between are felt).
BLOCKS = {
    5: [(352, 797), (962, 1126), (1258, 1442)],
    10: [(248, 797), (822, 1226), (1258, 1442)],
}
NAME_ROWS = {5: [1003, 1084], 10: [865, 945, 1025, 1106, 1185]}
READY = {5: [1, 3], 10: [1, 4, 8]}  # C shows some tags turned; the button counts them


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
        gd.ellipse((655 - r, 205 - r, 655 + r, 205 + r), fill=(220, 226, 255, 5 + i))
    sky.alpha_composite(glow)
    sky.alpha_composite(moon, (580, 132))
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
    b = banner(paper, nb, 742, 112, "The village wakes")
    P.stamp(top, b, (16, 44), drop=6, lean=-0.6)
    plank = t.crop((0, 200, W, 237))
    foot = t.crop((0, 1455, W, H))
    return stack([top, plank, body(t, n, H - sky_h - 37 - foot.height), foot])


# ---------------------------------------------------------------- B: the board's own sign
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
    board = body(t, n, H - 136 - foot.height, g0_min=sign_bottom + 16 - 136)
    page = stack([top, board, foot])
    d = ImageDraw.Draw(page)
    s = sign(paper, nb)
    sx = (W - s.width) // 2
    for nx in (sx + 26, sx + s.width - 16):  # cords from the eave to the sign's pins
        d.line([(nx, 92), (nx, sign_top + 14)], fill=(150, 132, 104, 255), width=3)
        d.ellipse((nx - 5, 88, nx + 5, 98), fill=(40, 40, 52, 255))
    P.stamp(page, s, (sx, sign_top), drop=6, lean=-0.6)
    lan = lantern(181)
    page.alpha_composite(lan, (645 - 6, -50))
    return page


# ---------------------------------------------------------------- C: the table's faces
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


def sigils(t, n):
    """Where each name tag's sigil disc is, in reading (seat) order: 37 px in from the tag's left edge."""
    a = np.asarray(t.convert("RGB")).astype(int)
    lum = a.mean(axis=2)
    out = []
    for y in NAME_ROWS[n]:
        x = 40
        while x < 700:
            felt = ((a[y, x - 16 : x - 2, 2] - a[y, x - 16 : x - 2, 0]) > 40).any()
            if (
                felt
                and (lum[y, x - 8 : x - 2] < 110).all()
                and (lum[y, x : x + 12] > 170).all()
            ):
                left = x + 12 + int(np.argmax(lum[y, x + 12 : x + 40] < 110))
                cx = left + 23
                if (lum[y, cx - 20 : cx + 20] < 110).mean() > 0.25:
                    out.append((cx, y, 46))
                    x += 100
                    continue
            x += 1
    return out


def sigil_crops(t, n):
    """Each name tag's own sigil disc, cut from the render (so a tag is the same token as its name)."""
    a = np.asarray(t.convert("RGB")).astype(float)
    lum = a.mean(axis=2)
    yy, xx = np.mgrid[-32:33, -32:33]
    r = np.hypot(xx, yy)
    crops = []
    for cx, cy, _ in sigils(t, n):
        best = None
        for dy in range(-10, 11):
            for dx in range(-8, 9):
                win = lum[cy + dy - 32 : cy + dy + 33, cx + dx - 32 : cx + dx + 33]
                score = (
                    win[(r > 25) & (r < 28)].mean() - win[(r > 18) & (r < 21.5)].mean()
                )
                if best is None or score > best[0]:
                    best = (score, cx + dx, cy + dy)
        _, x, y = best
        crops.append(t.convert("RGB").crop((x - 23, y - 23, x + 23, y + 23)))
    return crops


def tag(sigil, d, turned, paper, seed):
    tok = sigil.resize((d, d), Image.LANCZOS)
    m = Image.new("L", (d, d), 0)
    ImageDraw.Draw(m).ellipse((1, 1, d - 2, d - 2), fill=255)
    if turned:  # the tag turned over: bone paper, the sigil in ink
        face = paper.fill(d, d, seed).convert("RGB")
        lum = np.asarray(tok).mean(axis=2)
        sil = Image.fromarray(((lum > 150) * 255).astype("uint8"))
        inner = Image.new("L", (d, d), 0)
        ImageDraw.Draw(inner).ellipse(
            (d * 0.12, d * 0.12, d * 0.88, d * 0.88), fill=255
        )
        sil = Image.fromarray(np.minimum(np.asarray(sil), np.asarray(inner)))
        face.paste(Image.new("RGB", (d, d), P.INK), (0, 0), sil)
        ImageDraw.Draw(face).ellipse((2, 2, d - 3, d - 3), outline=P.INK, width=2)
        tok = face
    out = Image.new("RGBA", (d, d + 14), (0, 0, 0, 0))
    out.paste(tok, (0, 14), m)
    dr = ImageDraw.Draw(out)
    dr.line([(d // 2, 0), (d // 2, 18)], fill=(170, 152, 120, 255), width=2)
    dr.ellipse((d // 2 - 3, 16, d // 2 + 3, 22), fill=(20, 22, 40, 255))
    return out


def recount(page, ready, n):
    """The button's count, as it reads with `ready` players ready."""
    a = np.asarray(page.convert("RGB")).astype(int)
    y0, y1 = 1597, 1625
    ink = a[y0:y1, 70:560].mean(axis=2) < 110
    xs = np.where(ink.any(axis=0))[0] + 70
    lx, rx = xs.min(), xs.max()
    patch = page.crop((lx - 150 - 6, y0, rx - 150 + 6, y1))
    page.paste(patch, (lx - 6, y0))
    d = ImageDraw.Draw(page)
    f = P.font("figtree-semi", 25)
    text = f"{ready} of {n} ready"
    tw, _, tb = P.text_size(d, text, f)
    cx = (lx + rx) // 2
    d.text((cx - tw // 2 - tb[0], 1600 - tb[1]), text, font=f, fill=(48, 42, 46))


def option_c(t, n, paper):
    page = clear_clock(t).convert("RGBA")
    d = ImageDraw.Draw(page)
    P.clock(d, 132, 76, 44, P.BONE_TEXT)
    cord = P.sag(150, 40, 632, 34, 16)
    d.line(cord, fill=(170, 152, 120, 255), width=3)
    for nx, ny in (cord[0], cord[-1]):  # the cord's two nails
        d.ellipse((nx - 5, ny - 5, nx + 5, ny + 5), fill=(40, 40, 52, 255))
    toks = sigil_crops(t, n)
    size = 58 if n <= 6 else 42
    x0, x1 = 176, 606
    step = (x1 - x0) / max(1, n - 1)
    rnd = random.Random(n)
    for i, p in enumerate(toks):
        x = x0 + step * i
        y = np.interp(x, [q[0] for q in cord], [q[1] for q in cord])
        piece = tag(p, size, i in READY[n], paper, i)
        sw, (ax, ay) = P.swing(piece, rnd.uniform(-5, 5), (size // 2, 0))
        P.stamp(page, sw, (int(x - ax), int(y - ay)), drop=4, lean=-0.6)
    recount(page, len(READY[n]), n)
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
        made[f"c-{n}"] = save(option_c(talk[n], n, paper), f"c-{n}")
    labels = {
        "today": "Today",
        "a": "A  One banner",
        "b": "B  The board's sign",
        "c": "C  The table's faces",
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
