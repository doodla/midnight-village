"""Options for the title on the first screen (01), built from today's real screen.

Usage (repo root): python3 docs/design/mocks/options/village-title/make_options.py [01-join.png]
The screen defaults to frontend/build/screens/01-join.png (`just screens`). Deterministic: every
random choice comes from a fixed seed. Writes today.png, a.png .. d.png, pick-short.png, sheet.png
beside this file.

Material, as docs/design/feel.md 1a: paper is cut, grained and lies on hard shadows made of
stepped flat copies (a contact copy and five cast copies, no blur); light falls from above.
Only the title changes: the name field and the two buttons are today's pixels, untouched.
"""

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
GLOOCK = ROOT / "frontend/assets/fonts/gloock/Gloock-Regular.ttf"
FIGTREE = ROOT / "frontend/assets/fonts/figtree/Figtree-SemiBold.ttf"
ART = ROOT / "docs/design/art"
SS = 4  # supersampling for every cut edge

NIGHT_INK = (7, 9, 26)
BONE_EDGE = (178, 166, 144)
IRON = (38, 41, 50)
IRON_EDGE = (74, 79, 92)
TWINE = (146, 124, 88)

# Today's screen, 780 x 1688 (390 x 844 at 2x): where things are.
TITLE_BOX = (100, 1036, 680, 1136)
FIELD_TOP = 1142


# ---------------------------------------------------------------- basics


def rgba(arr):
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def over(base, layer, xy=(0, 0)):
    """Composite an RGBA layer onto an RGBA base in place."""
    base.alpha_composite(layer, dest=(int(round(xy[0])), int(round(xy[1]))))


def solid(alpha, color, a=1.0):
    h, w = alpha.shape
    out = np.zeros((h, w, 4), np.float32)
    out[..., :3] = color
    out[..., 3] = np.clip(alpha, 0, 1) * 255 * a
    return out


def shift(alpha, dx, dy):
    out = np.zeros_like(alpha)
    h, w = alpha.shape
    dx, dy = int(round(dx)), int(round(dy))
    ys, yd = (
        (slice(0, h - dy), slice(dy, h))
        if dy >= 0
        else (slice(-dy, h), slice(0, h + dy))
    )
    xs, xd = (
        (slice(0, w - dx), slice(dx, w))
        if dx >= 0
        else (slice(-dx, w), slice(0, w + dx))
    )
    out[yd, xd] = alpha[ys, xs]
    return out


def dilate(alpha, r):
    r = int(round(r))
    if r < 1:
        return alpha
    img = Image.fromarray((alpha * 255).astype(np.uint8), "L")
    return (
        np.asarray(img.filter(ImageFilter.MaxFilter(2 * r + 1))).astype(np.float32)
        / 255
    )


def hard_shadow(alpha, drop, ink=NIGHT_INK):
    """PaperShadow: a contact copy (.62) and five cast copies (.075 each), flat, stepped."""
    out = Image.new("RGBA", (alpha.shape[1], alpha.shape[0]), (0, 0, 0, 0))
    for k in range(5, 0, -1):
        a = shift(dilate(alpha, 2.4 * drop * k / 5 / 2), 0, drop * k / 5)
        over(out, rgba(solid(a, ink, 0.075)))
    over(out, rgba(solid(shift(alpha, 0, 1 + 0.2 * drop), ink, 0.62)))
    return out


def pad(alpha, p):
    return np.pad(alpha, p)


def texture(sample, w, h, seed):
    """A paper fill of w x h from a real sample, mirror-tiled, from a seeded offset."""
    rng = np.random.default_rng(seed)
    sh, sw = sample.shape[:2]
    reps = (h // sh + 3, w // sw + 3)
    rows = [
        np.concatenate(
            [sample if (i + j) % 2 == 0 else sample[:, ::-1] for j in range(reps[1])], 1
        )
        for i in range(reps[0])
    ]
    big = np.concatenate([r if i % 2 == 0 else r[::-1] for i, r in enumerate(rows)], 0)
    oy, ox = rng.integers(0, sh), rng.integers(0, sw)
    return big[oy : oy + h, ox : ox + w].astype(np.float32)


def smooth_noise(h, w, cell, seed):
    rng = np.random.default_rng(seed)
    small = rng.random((h // cell + 2, w // cell + 2)).astype(np.float32)
    img = Image.fromarray((small * 255).astype(np.uint8), "L").resize(
        (w, h), Image.BICUBIC
    )
    return np.asarray(img).astype(np.float32) / 255 - 0.5


def knife_cut(mask_ss, seed, wobble=0.22):
    """A crisp cut edge a hand made: the outline moves a hair, in facets, then is cut clean."""
    h, w = mask_ss.shape
    soft = Image.fromarray((mask_ss * 255).astype(np.uint8), "L").filter(
        ImageFilter.GaussianBlur(SS * 0.9)
    )  # construction only: thresholded below
    soft = np.asarray(soft).astype(np.float32) / 255
    cut = (soft + wobble * smooth_noise(h, w, SS * 6, seed) > 0.5).astype(np.float32)
    return down(cut)


def down(mask_ss):
    h, w = mask_ss.shape
    img = Image.fromarray((mask_ss * 255).astype(np.uint8), "L")
    return (
        np.asarray(img.resize((w // SS, h // SS), Image.LANCZOS)).astype(np.float32)
        / 255
    )


def glyph_mask(text, size, seed=None, wobble=0.22):
    """The word in Gloock as a cut piece (final resolution), with its baseline offset."""
    font = ImageFont.truetype(str(GLOOCK), size * SS)
    l, t, r, b = font.getbbox(text)
    m = 3 * SS
    img = Image.new("L", (r - l + 2 * m, b - t + 2 * m), 0)
    ImageDraw.Draw(img).text((m - l, m - t), text, font=font, fill=255)
    arr = np.asarray(img).astype(np.float32) / 255
    if seed is None:
        a = down(arr)
    else:
        a = knife_cut(arr, seed, wobble)
    ascent = font.getmetrics()[0]
    return a, (ascent - t + m) / SS  # mask, baseline row within it


def paper_piece(alpha, fill, edge_px, edge_color, drop, seed):
    """A cut piece of paper: its fill, its thickness (a hard copy in a darker tone), its shadow."""
    p = int(drop * 3 + edge_px + 6)
    a = pad(alpha, p)
    h, w = a.shape
    out = hard_shadow(np.maximum(a, shift(a, 0, edge_px)), drop)
    over(out, rgba(solid(shift(a, 0, edge_px), edge_color)))
    tex = texture(fill, w, h, seed)
    face = np.dstack([tex[..., :3], a * 255])
    over(out, rgba(face))
    return out, p


def rotated(layer, deg):
    return layer.rotate(deg, resample=Image.BICUBIC, expand=True)


# ---------------------------------------------------------------- today's screen


def erase_title(img):
    """Today's screen without its title: the letters filled from the ground round them."""
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    x0, y0, x1, y1 = TITLE_BOX
    crop = a[y0:y1, x0:x1].copy()
    lum = crop @ np.array([0.3, 0.59, 0.11])
    ground = np.median(lum, axis=1, keepdims=True)
    mask = dilate(((lum - ground) > 10).astype(np.float32), 3) > 0
    # each hole starts from its row's ends, then relaxes (Laplace) from the ground round it
    for c in range(3):
        ch = crop[..., c]
        for y in range(ch.shape[0]):
            row = ch[y]
            keep = ~mask[y]
            row[mask[y]] = np.interp(np.where(mask[y])[0], np.where(keep)[0], row[keep])
        for _ in range(600):
            avg = (
                np.roll(ch, 1, 0)
                + np.roll(ch, -1, 0)
                + np.roll(ch, 1, 1)
                + np.roll(ch, -1, 1)
            ) / 4
            ch[mask] = avg[mask]
    a[y0:y1, x0:x1] = crop
    return Image.fromarray(a.astype(np.uint8)).convert("RGBA")


def samples(img):
    a = np.asarray(img.convert("RGB"))
    bone = a[1165:1230, 250:720]
    sky = a[4:40, 100:250]
    return bone, sky


def short_phone(base):
    """01 at 360 x 640 (720 x 1280): the picture gives way first (pushed off the top, never cropped
    at the sides); the form keeps its heights, its pieces 60 px narrower, the numbers below the fold."""
    a = np.asarray(base.convert("RGB"))
    out = np.zeros((1280, 720, 3), np.uint8)
    dy = 1142 - 842  # the name field's top moves from 1142 to 842
    scene = Image.fromarray(a[:1136]).resize(
        (720, round(1136 * 720 / 780)), Image.LANCZOS
    )
    s = np.asarray(scene)
    top = s.shape[0] - (1136 - dy)
    out[: 1136 - dy] = s[top:]
    cuts = [
        (1136, 1266, [(450, 510)]),
        (1266, 1402, [(90, 120), (450, 480)]),
        (1402, 1580, [(90, 120), (660, 690)]),
    ]
    for y0, y1, spans in cuts:
        band = a[y0:y1]
        keep = np.ones(780, bool)
        for c0, c1 in spans:
            keep[c0:c1] = False
        out[y0 - dy : y1 - dy] = band[:, keep]
    return Image.fromarray(out).convert("RGBA"), 1136 * 720 / 780 - (1136 - dy)


# ---------------------------------------------------------------- A: the village's sign


def planks(width, height):
    """A board of three planks, cut from the end board's notice frame: its top and bottom planks
    (iron plates at their ends) and, between them, a plank's plain middle; no light inner strip."""
    f = Image.open(ART / "end/frame4.png").convert("RGBA")
    top = f.crop((8, 7, 660, 84))
    bottom = f.crop((8, 778, 660, 853))
    # the frame's middle nails would sit among the letters: plank from beside them covers them
    for p in (top, bottom):
        p.paste(p.crop((222, 0, 296, p.height)), (296, 0))
    mid = top.crop((102, 2, 548, 75)).transpose(Image.FLIP_LEFT_RIGHT)
    ph = height // 3
    board = Image.new("RGBA", (width, ph * 3), (0, 0, 0, 0))
    for i, p in enumerate([top, mid, bottom]):
        board.alpha_composite(
            p.resize((width, ph + 2), Image.LANCZOS), (0, i * ph - (1 if i else 0))
        )
    # the joins between planks: a hard dark line, the paper under it
    a = np.asarray(board).astype(np.float32)
    for j in (ph, 2 * ph):
        a[j - 1 : j + 2, :, :3] *= 0.45
    return rgba(a)


def option_a(base, bone, cx, field_top, seed=11):
    out = base.copy()
    bw, bh = 470, 198
    gap = 40
    board_top = field_top - gap - bh
    sign = planks(bw, bh)
    # bone letters pasted on, each a hair off the line, as a hand pastes them
    for li, (word, base_y) in enumerate([("Midnight", 86), ("Village", 166)]):
        font = ImageFont.truetype(str(GLOOCK), 74)
        widths = [font.getlength(ch) for ch in word]
        x = (bw - sum(widths)) / 2
        rng = np.random.default_rng(seed + li)
        for ch, wch in zip(word, widths):
            m, bl = glyph_mask(ch, 74, seed=int(rng.integers(1e6)), wobble=0.1)
            piece, p = paper_piece(m, bone, 3, BONE_EDGE, 3, int(rng.integers(1e6)))
            piece = rotated(piece, rng.uniform(-1.6, 1.6))
            ox = x - 3 - p - (piece.width - m.shape[1] - 2 * p) / 2
            oy = (
                base_y
                - bl
                - p
                - (piece.height - m.shape[0] - 2 * p) / 2
                + rng.uniform(-1.5, 1.5)
            )
            over(sign, piece, (ox, oy))
            x += wch
    # two iron rings on the top edge
    ring_x = [62, bw - 62]
    d = ImageDraw.Draw(sign)
    for rx in ring_x:
        d.ellipse((rx - 9, -1, rx + 9, 17), outline=IRON_EDGE, width=4)
    tilt = -1.2
    sign_r = rotated(sign, tilt)
    sx, sy = cx - sign_r.width / 2, board_top - (sign_r.height - bh) / 2
    sa = np.asarray(sign_r)[..., 3].astype(np.float32) / 255
    sh = hard_shadow(pad(sa, 30), 7)
    # the bracket: a flat iron arm out of the wall on the left, a brace under it, a curl at its tip
    arm_y = board_top - 62
    tip = cx + bw / 2 - 18
    W, H = out.size
    iron = Image.new("L", (W * SS, H * SS), 0)
    di = ImageDraw.Draw(iron)
    s = SS
    di.rectangle((-10 * s, (arm_y - 4) * s, tip * s, (arm_y + 12) * s), fill=255)
    di.rectangle((0, (arm_y - 44) * s, 26 * s, (arm_y + 120) * s), fill=255)
    # a scroll brace from low on the wall up under the arm
    di.arc(
        (0, (arm_y + 4) * s, 380 * s, (arm_y + 220) * s),
        180,
        270,
        fill=255,
        width=11 * s,
    )
    di.arc(
        (38 * s, (arm_y + 28) * s, 84 * s, (arm_y + 74) * s),
        330,
        630,
        fill=255,
        width=8 * s,
    )
    di.arc(
        ((tip - 20) * s, (arm_y - 26) * s, (tip + 20) * s, (arm_y + 14) * s),
        180,
        90,
        fill=255,
        width=9 * s,
    )
    ia = knife_cut(np.asarray(iron).astype(np.float32) / 255, seed + 7, 0.1)
    over(out, hard_shadow(ia, 4))
    face = solid(ia, IRON)
    top_edge = ia * (1 - shift(ia, 0, 3))
    face[..., :3] = np.where(top_edge[..., None] > 0.5, IRON_EDGE, face[..., :3])
    over(out, rgba(face))
    # the cords, from the arm to the rings, with their own thin shadow
    th = math.radians(-tilt)
    cords = Image.new("RGBA", out.size, (0, 0, 0, 0))
    dc = ImageDraw.Draw(cords)
    for rx in ring_x:
        lx, ly = rx - bw / 2, 4 - bh / 2
        px = cx + lx * math.cos(th) + ly * math.sin(th)
        py = board_top + bh / 2 - lx * math.sin(th) + ly * math.cos(th)
        top_x = px + (6 if rx > bw / 2 else -6)
        dc.line((top_x, arm_y + 6, px, py), fill=TWINE + (255,), width=4)
        for t in np.arange(0, 1, 7 / max(1, py - arm_y)):
            qx, qy = top_x + (px - top_x) * t, arm_y + 6 + (py - arm_y - 6) * t
            dc.line((qx - 2, qy - 1, qx + 2, qy + 2), fill=(96, 80, 56, 255), width=1)
    ca = np.asarray(cords)[..., 3].astype(np.float32) / 255
    over(out, hard_shadow(ca, 3))
    over(out, cords)
    over(out, sh, (sx - 30, sy - 30))
    over(out, sign_r, (sx, sy))
    return out


# ---------------------------------------------------------------- B: cut letters


def option_b(base, bone, cx, field_top, seed=23):
    out = base.copy()
    size = 104
    lines = [
        ("Midnight", cx - 28, field_top - 166),
        ("Village", cx + 40, field_top - 50),
    ]
    rng = np.random.default_rng(seed)
    pieces = []
    for word, lcx, baseline in lines:
        font = ImageFont.truetype(str(GLOOCK), size)
        widths = [font.getlength(ch) * 1.04 for ch in word]
        x = lcx - sum(widths) / 2
        for ch, wch in zip(word, widths):
            k = 1 + rng.uniform(-0.05, 0.06)
            m, bl = glyph_mask(
                ch, int(size * k), seed=int(rng.integers(1e6)), wobble=0.14
            )
            piece, p = paper_piece(m, bone, 4, BONE_EDGE, 6, int(rng.integers(1e6)))
            piece = rotated(piece, rng.uniform(-3.2, 3.2))
            ox = x - 3 - p - (piece.width - m.shape[1] - 2 * p) / 2
            oy = (
                baseline
                + rng.uniform(-6, 6)
                - bl
                - p
                - (piece.height - m.shape[0] - 2 * p) / 2
            )
            pieces.append((piece, ox, oy))
            x += wch
    for piece, ox, oy in pieces:
        over(out, piece, (ox, oy))
    return out


# ---------------------------------------------------------------- C: on the moon


def option_c(base, sky, seed=31):
    """The words cut out of the moon: the sky's paper shows through, the moon's edge shadows it.
    The moon is the disc at (433, 205), radius 160, on today's screen; what stands in front of it
    (branches, roofs) is not cut."""
    out = base.copy()
    a = np.asarray(out).astype(np.float32)
    lum = a[..., :3] @ np.array([0.3, 0.59, 0.11])
    yy, xx = np.mgrid[: lum.shape[0], : lum.shape[1]]
    disc = ((xx - 433) ** 2 + (yy - 205) ** 2) < 156**2
    moon = (disc & (lum > 105)).astype(np.float32)
    hole = np.zeros(lum.shape, np.float32)
    for word, cx, baseline in [("Midnight", 418, 170), ("Village", 402, 238)]:
        m, bl = glyph_mask(word, 52, seed=seed + baseline, wobble=0.1)
        h, w = m.shape
        x0 = int(cx - w / 2)
        y0 = int(baseline - bl)
        hole[y0 : y0 + h, x0 : x0 + w] = np.maximum(hole[y0 : y0 + h, x0 : x0 + w], m)
    hole *= moon
    tex = texture(sky, a.shape[1], a.shape[0], seed)
    a[..., :3] = a[..., :3] * (1 - hole[..., None]) + tex * hole[..., None]
    # the moon is paper: its cut edge throws a hard shadow down into each hole
    lip = hole * np.clip(shift(1 - hole, 0, 1) + shift(1 - hole, 0, 2), 0, 1)
    cast = hole * shift(1 - hole, 0, 4) * (1 - lip)
    for sh_a, alpha in [(lip, 0.62), (cast, 0.3)]:
        a[..., :3] = (
            a[..., :3] * (1 - sh_a[..., None] * alpha)
            + np.array(NIGHT_INK) * sh_a[..., None] * alpha
        )
    return Image.fromarray(a.astype(np.uint8), "RGBA")


# ---------------------------------------------------------------- D: the ribbon


def option_d(base, cx, field_top):
    """The end board's swallowtail ribbon (three-slice), the title inked on it, a hair off square."""
    out = base.copy()
    b = Image.open(ART / "end/banner.png").convert("RGBA")
    s = 0.36
    left, mid, right = (
        b.crop((0, 0, 300, 477)),
        b.crop((300, 0, 1140, 477)),
        b.crop((1140, 0, 1460, 477)),
    )
    font = ImageFont.truetype(str(GLOOCK), 60)
    tw = font.getlength("Midnight Village")
    mw = int(tw + 40)
    h = int(477 * s)
    lw, rw = int(300 * s), int(320 * s)
    ban = Image.new("RGBA", (lw + mw + rw, h), (0, 0, 0, 0))
    ban.alpha_composite(left.resize((lw, h), Image.LANCZOS), (0, 0))
    ban.alpha_composite(mid.resize((mw + 2, h), Image.LANCZOS), (lw - 1, 0))
    ban.alpha_composite(right.resize((rw, h), Image.LANCZOS), (lw + mw, 0))
    d = ImageDraw.Draw(ban)
    d.text(
        (lw + 20, 233 * s),
        "Midnight Village",
        font=font,
        fill=(20, 23, 47, 255),
        anchor="lm",
    )
    ban = rotated(ban, 1.0)
    ba = np.asarray(ban)[..., 3].astype(np.float32) / 255
    x = cx - ban.width / 2
    y = field_top - 30 - ban.height + 22
    over(out, hard_shadow(pad(ba, 30), 6), (x - 30, y - 30))
    over(out, ban, (x, y))
    return out


# ---------------------------------------------------------------- frames and the sheet


def phone(screen, border=22, radius=62):
    w, h = screen.size
    body = Image.new("RGBA", (w + 2 * border, h + 2 * border), (0, 0, 0, 0))
    m = Image.new("L", body.size, 0)
    ImageDraw.Draw(m).rounded_rectangle(
        (0, 0, body.width - 1, body.height - 1), radius, fill=255
    )
    body.paste((12, 12, 16, 255), (0, 0), m)
    sm = Image.new("L", (w, h), 0)
    ImageDraw.Draw(sm).rounded_rectangle(
        (0, 0, w - 1, h - 1), radius - border, fill=255
    )
    body.paste(screen, (border, border), sm)
    return body


def sheet(items, path):
    scale = 0.5
    label_h = 92
    cells = [
        (lab, im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS))
        for lab, im in items
    ]
    gap = 36
    W = sum(c.width for _, c in cells) + gap * (len(cells) + 1)
    H = max(c.height for _, c in cells) + label_h + 2 * gap
    out = Image.new("RGBA", (W, H), (21, 22, 29, 255))
    d = ImageDraw.Draw(out)
    font = ImageFont.truetype(str(FIGTREE), 30)
    x = gap
    for lab, c in cells:
        d.text((x + 8, gap), lab, font=font, fill=(233, 226, 208, 255))
        out.alpha_composite(
            c, (x, gap + label_h - 20 + (H - label_h - 2 * gap - c.height))
        )
        x += c.width + gap
    out.convert("RGB").save(path, optimize=True)


def main():
    src = (
        Path(sys.argv[1])
        if len(sys.argv) > 1
        else ROOT / "frontend/build/screens/01-join.png"
    )
    today = Image.open(src).convert("RGBA")
    assert today.size == (780, 1688), today.size
    base = erase_title(today)
    bone, sky = samples(today)
    shots = {
        "today": today,
        "a": option_a(base, bone, 390, FIELD_TOP),
        "b": option_b(base, bone, 390, FIELD_TOP),
        "c": option_c(base, sky),
        "d": option_d(base, 390, FIELD_TOP),
    }
    short, _ = short_phone(base)
    shots["pick-short"] = option_a(short, bone, 360, 842)
    framed = {k: phone(v) for k, v in shots.items()}
    for k, v in framed.items():
        v.save(HERE / f"{k}.png", optimize=True)
    sheet(
        [
            ("Today", framed["today"]),
            ("A  The village's sign", framed["a"]),
            ("B  Cut letters", framed["b"]),
            ("C  On the moon", framed["c"]),
            ("D  The ribbon", framed["d"]),
            ("A, short phone", framed["pick-short"]),
        ],
        HERE / "sheet.png",
    )


if __name__ == "__main__":
    main()
