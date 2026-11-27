"""Options for the title on the first screen (01), built from today's real screen.

Usage (repo root): python3 docs/design/mocks/options/village-title/make_options.py [01-join.png]
The screen defaults to frontend/build/screens/01-join.png (`just screens`). Deterministic: every
random choice comes from a fixed seed. Writes today.png, a.png, b.png, c.png, pick-short-a.png,
pick-short-b.png and sheet.png beside this file. A second argument, "bone", gives A's board in bone.

Material, as docs/design/feel.md 1a: paper is cut, grained and lies on hard shadows made of
stepped flat copies (no blur). The title's own shadow is stronger than PaperShadow and leans down-right,
so it reads on the dark ground.
Only the title changes: the name field and the two buttons are today's pixels, untouched.
"""

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
        ImageFilter.GaussianBlur(SS * 0.35)
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


# ---------------------------------------------------------------- the title's shadow


def title_shadow(alpha, drop):
    """The title's hard shadow, made to read on the dark ground: the ground's shadow ink, a contact
    copy (.8) and four stepped cast copies (.22 each), leaning down-right, away from the moon."""
    out = Image.new("RGBA", (alpha.shape[1], alpha.shape[0]), (0, 0, 0, 0))
    for k in range(4, 0, -1):
        a = shift(dilate(alpha, drop * k / 10), 0.6 * drop * k / 4, drop * k / 4)
        over(out, rgba(solid(a, NIGHT_INK, 0.22)))
    c = 1 + 0.25 * drop
    over(out, rgba(solid(shift(alpha, 0.6 * c, c), NIGHT_INK, 0.8)))
    return out


def cut_piece(alpha, fill, edge_px, edge_color, drop, seed):
    """A cut piece lying on the scene: its title shadow, its thickness, its grained face."""
    p = int(drop * 2 + edge_px + 8)
    a = pad(alpha, p)
    h, w = a.shape
    out = title_shadow(np.maximum(a, shift(a, 0, edge_px)), drop)
    over(out, rgba(solid(shift(a, 0, edge_px), edge_color)))
    tex = texture(fill, w, h, seed)
    over(out, rgba(np.dstack([tex[..., :3], a * 255])))
    return out, p


def deckle(w, h, depth, step, seed):
    """DeckleBorder: each side steps in by up to `depth` in nibbles of `step` px, seeded."""
    rng = np.random.default_rng(seed)
    W, H, d, st = w * SS, h * SS, depth * SS, step * SS

    def edge(n):
        pts = np.arange(0, n + st, st)
        return np.interp(np.arange(n), pts, rng.uniform(0, d, len(pts)))

    yy, xx = np.mgrid[:H, :W]
    top, bot = edge(W), edge(W)
    left, right = edge(H), edge(H)
    m = (yy >= top[None, :]) & (yy < H - bot[None, :])
    m &= (xx >= left[:, None]) & (xx < W - right[:, None])
    return down(m.astype(np.float32))


def pin_layer(size=18):
    """PaperPin: a flat matte pin head (9 px), a darker rim, its own hard shadow."""
    s = size + 16
    img = Image.new("L", (s * SS, s * SS), 0)
    ImageDraw.Draw(img).ellipse(
        (6 * SS, 6 * SS, (6 + size) * SS, (6 + size) * SS), fill=255
    )
    a = down(np.asarray(img).astype(np.float32) / 255)
    out = title_shadow(a, 3)
    over(out, rgba(solid(a, (98, 36, 32))))
    rim = a * (1 - shift(a, -2, -2))
    over(out, rgba(solid(rim, (62, 22, 22))))
    return out


def lay(out, piece, p, mask, x, y, deg, rng=None):
    """Turn a piece about its own centre and put its mask's top left at (x, y)."""
    r = rotated(piece, deg)
    ox = x - p - (r.width - mask.shape[1] - 2 * p) / 2
    oy = y - p - (r.height - mask.shape[0] - 2 * p) / 2
    over(out, r, (ox, oy))


# ---------------------------------------------------------------- A: the road sign


def option_a(base, bone, sky, cx, field_top, board="indigo", seed=11):
    """A paper signpost at the roadside: a post planted in the grass at the picture's foot, a deckled
    board on it where today's title sits, the name in two lines, a hair crooked, two pins."""
    out = base.copy()
    rng = np.random.default_rng(seed)
    bw, bh = 404, 182
    board_bottom = field_top - 30
    board_top = board_bottom - bh
    # the post: a strip of dark paper, its top cut at a slant, standing from the grass up past the board
    post_w = 26
    post_top = board_top - 70
    post_h = field_top + 10 - post_top
    pm = np.zeros((post_h * SS, post_w * SS), np.float32)
    pm[:, :] = 1
    for y in range(12 * SS):
        pm[y, : int((12 * SS - y) * post_w / 12)] = (
            0  # the slanted cut, high on the right
        )
    pa = knife_cut(pm, seed + 1, 0.08)
    post_paper = np.clip(texture(sky, post_w, post_h, seed + 2) * 0.95 + 2, 0, 255)
    post, pp = cut_piece(pa, post_paper, 3, (30, 30, 44), 5, seed + 3)
    px = cx + 16 - post_w / 2
    lay(out, post, pp, pa, px, post_top, -1.6)
    # grass the post stands in: a few blades cut from the ground's paper, in front of its foot
    blades = Image.new("L", (160 * SS, 70 * SS), 0)
    db = ImageDraw.Draw(blades)
    for i in range(9):
        bx = rng.uniform(20, 140) * SS
        tip = (bx + rng.uniform(-26, 26) * SS, rng.uniform(0, 30) * SS)
        db.polygon([(bx - 5 * SS, 70 * SS), (bx + 5 * SS, 70 * SS), tip], fill=255)
    ga = knife_cut(np.asarray(blades).astype(np.float32) / 255, seed + 4, 0.05)
    gl = Image.new("RGBA", (ga.shape[1], ga.shape[0]), (0, 0, 0, 0))
    over(gl, rgba(solid(ga, (24, 26, 40))))
    over(out, gl, (px + post_w / 2 - 80, board_bottom - 34))
    # the board: face, letters and pins built flat, then turned together
    face = deckle(bw, bh, 6, 7, seed + 5)
    if board == "indigo":
        paper = np.clip(texture(sky, bw, bh, seed + 6) * 1.25, 0, 255)
        edge_c, letter_fill, letter_edge = (18, 20, 36), bone, BONE_EDGE
    else:
        paper = texture(bone, bw, bh, seed + 6)
        edge_c = BONE_EDGE
        letter_fill = np.clip(texture(sky, 200, 60, seed + 7) * 0.8, 0, 255)
        letter_edge = (12, 14, 28)
    sign, sp = cut_piece(face, paper, 4, edge_c, 8, seed + 8)
    font = ImageFont.truetype(str(GLOOCK), 72)
    for li, (word, base_y) in enumerate([("Midnight", 82), ("Village", 156)]):
        widths = [font.getlength(ch) for ch in word]
        x = sp + (bw - sum(widths)) / 2
        lrng = np.random.default_rng(seed + 20 + li)
        for ch, wch in zip(word, widths):
            m, bl = glyph_mask(ch, 72, seed=int(lrng.integers(1e6)), wobble=0.1)
            piece, p = paper_piece(
                m, letter_fill, 2, letter_edge, 2, int(lrng.integers(1e6))
            )
            lay(
                sign,
                piece,
                p,
                m,
                x - 3,
                sp + base_y - bl + lrng.uniform(-1.5, 1.5),
                lrng.uniform(-1.4, 1.4),
            )
            x += wch
    pin = pin_layer()
    for pxp in (sp + 14, sp + bw - 32):  # in the corners, clear of the letters
        over(sign, pin, (pxp - 8, sp + 2))
    tilt = 2.2  # an old sign, a hair crooked
    sr = rotated(sign, tilt)
    over(out, sr, (cx - sr.width / 2, board_top + bh / 2 - sr.height / 2))
    # the name field lies on top of all of it, as today
    restore(out, base, field_top)
    return out


def restore(out, base, field_top):
    """Put the form back on top: today's pixels from the name field's top down."""
    b = np.asarray(base).copy()
    o = np.asarray(out).copy()
    band = slice(field_top - 6, field_top + 40)
    lum = b[band, :, :3].astype(np.float32) @ np.array([0.3, 0.59, 0.11])
    paper = (lum > 120)[..., None]
    o[band] = np.where(paper, b[band], o[band])
    o[field_top + 40 :] = b[field_top + 40 :]
    out.paste(Image.fromarray(o, "RGBA"))


# ---------------------------------------------------------------- B: cut letters


def option_b(base, bone, cx, field_top, seed=23):
    """Each letter cut from bone paper and laid on the scene; one centred block, its first line's
    feet in the grass at the picture's foot."""
    out = base.copy()
    size = 108
    rng = np.random.default_rng(seed)
    font = ImageFont.truetype(str(GLOOCK), size)
    lines = [("Midnight", field_top - 196), ("Village", field_top - 64)]
    for word, baseline in lines:
        widths = [font.getlength(ch) * 1.04 for ch in word]
        x = cx - sum(widths) / 2  # both lines centred on one axis: one block
        for ch, wch in zip(word, widths):
            k = 1 + rng.uniform(-0.05, 0.06)
            m, bl = glyph_mask(
                ch, int(size * k), seed=int(rng.integers(1e6)), wobble=0.14
            )
            piece, p = cut_piece(m, bone, 4, BONE_EDGE, 9, int(rng.integers(1e6)))
            lay(
                out,
                piece,
                p,
                m,
                x - 3,
                baseline + rng.uniform(-6, 6) - bl,
                rng.uniform(-3.2, 3.2),
            )
            x += wch
    restore(out, base, field_top)
    return out


# ---------------------------------------------------------------- C: on the moon


def option_c(base, sky, seed=31):
    """The words cut out of the moon: the sky's paper shows through, the moon's edge shadows it.
    The moon is the disc at (433, 205), radius 160, on today's screen; the words sit in its clear
    upper part, where no branch or roof stands in front of it."""
    out = base.copy()
    a = np.asarray(out).astype(np.float32)
    lum = a[..., :3] @ np.array([0.3, 0.59, 0.11])
    yy, xx = np.mgrid[: lum.shape[0], : lum.shape[1]]
    disc = ((xx - 433) ** 2 + (yy - 205) ** 2) < 156**2
    moon = (disc & (lum > 105)).astype(np.float32)
    r2 = (xx - 433) ** 2 + (yy - 205) ** 2
    clear = (r2 < 150**2) & (lum > 105)
    in_front = dilate((~clear & (r2 < 175**2)).astype(np.float32), 5)
    hole = np.zeros(lum.shape, np.float32)
    for word, cx, baseline in [("Midnight", 432, 136), ("Village", 386, 191)]:
        m, bl = glyph_mask(word, 46, seed=seed + baseline, wobble=0.1)
        h, w = m.shape
        x0, y0 = int(cx - w / 2), int(baseline - bl)
        hole[y0 : y0 + h, x0 : x0 + w] = np.maximum(hole[y0 : y0 + h, x0 : x0 + w], m)
    crossed = float((hole * in_front).sum())
    assert crossed < 1, f"a branch or a roof crosses a letter ({crossed:.0f})"
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
    board = sys.argv[2] if len(sys.argv) > 2 else "indigo"
    today = Image.open(src).convert("RGBA")
    assert today.size == (780, 1688), today.size
    base = erase_title(today)
    bone, sky = samples(today)
    short, _ = short_phone(base)
    shots = {
        "today": today,
        "a": option_a(base, bone, sky, 374, FIELD_TOP, board),
        "b": option_b(base, bone, 390, FIELD_TOP),
        "c": option_c(base, sky),
        "pick-short-a": option_a(short, bone, sky, 346, 842, board),
        "pick-short-b": option_b(short, bone, 360, 842),
    }
    framed = {k: phone(v) for k, v in shots.items()}
    for k, v in framed.items():
        v.save(HERE / f"{k}.png", optimize=True)
    sheet(
        [
            ("Today", framed["today"]),
            ("A  The road sign", framed["a"]),
            ("B  Cut letters", framed["b"]),
            ("C  On the moon", framed["c"]),
            ("A, short phone", framed["pick-short-a"]),
            ("B, short phone", framed["pick-short-b"]),
        ],
        HERE / "sheet.png",
    )


if __name__ == "__main__":
    main()
