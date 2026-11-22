"""Make the app's icons and launch marks from the Shadow paper art.

    uv run --with pillow python tool/app_icon.py            # write every file
    uv run --with pillow python tool/app_icon.py --preview DIR
                                  # also the three candidates, for review

(`just app-icon`, from frontend/.) The mark is "the moon over the house": a
square window onto the Join screen's own scene (docs/design/art/scenes/
street-door.jpg), the full moon with the gable and its lit lantern under it,
its dark tones pressed toward the night ground so the moon reads first at
48 px. Nothing is drawn by hand: every pixel is the original art, cropped,
toned within the palette and masked. docs/design/app-icon.md says what each
file is for.

Geometry is in Android's adaptive-icon units (dp of a 108 dp canvas): the
launcher shows the inner 72 dp through its mask, and everything that must
be seen sits inside the 66 dp circle in the middle. The scene is set so
that the moon, the roof's peak and the lantern are inside that circle.

Deterministic: the same art gives the same bytes, so a second run changes
nothing (`git status` stays clean).
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "docs" / "design" / "art"
FRONTEND = ROOT / "frontend"
RES = FRONTEND / "android" / "app" / "src" / "main" / "res"
WEB = FRONTEND / "web"

# The night ground (lib/design_system/skin/skins/shadow_paper.dart, _indigo).
NIGHT = (0x14, 0x17, 0x2F)

# Android densities: pixels per dp.
DENSITIES = {
    "mdpi": 1.0,
    "hdpi": 1.5,
    "xhdpi": 2.0,
    "xxhdpi": 3.0,
    "xxxhdpi": 4.0,
}

CANVAS_DP = 108  # an adaptive icon layer
VISIBLE_DP = 72  # what a launcher mask shows of it
SAFE_DP = 66  # the circle every mask keeps
LEGACY_DP = 48  # a pre-Android 8 launcher icon
SPLASH_MARK_DP = 192  # the launch mark: Android 12's splash icon circle
QUALITY = 88  # WebP, for the pictures (the monochrome layer is lossless)


@dataclass(frozen=True)
class Mark:
    """A square window onto one picture of the art.

    [centre] is the window's middle in the source's pixels and [visible]
    how many source pixels the launcher's 72 dp shows; everything else
    follows from them.
    """

    name: str
    source: Path
    centre: tuple[float, float]
    visible: float
    # Tones darker than this (0-255 luminance) are pressed toward the night
    # ground by [press] (0: untouched, 1: flat night), the lantern's amber
    # kept: the moon and the lit window read first, the rest recedes.
    shadow_below: int = 0
    press: float = 0.0
    # Pixels lighter than this count as the shape of the monochrome layer.
    mono_above: int = 170
    # A circle (centre x, centre y, radius) in source pixels the monochrome
    # shape is kept inside, and the width of the thin details it drops.
    mono_within: tuple[float, float, float] | None = None
    mono_open: int = 0
    # A polygon (source pixels) cut out of the monochrome shape: the house
    # in front of the moon, traced along the outside of its roof's edges.
    mono_cut: tuple[tuple[float, float], ...] = ()
    # A box (left, top, right, bottom; source pixels) whose warm pixels (the
    # lantern's glass) are added to the monochrome shape after the cut: the
    # lit window inside the house's silhouette.
    mono_warm: tuple[float, float, float, float] | None = None
    # A circle (centre x, centre y, radius) outside which the picture is
    # filled with [outside_colour]: a token without its rim.
    keep_within: tuple[float, float, float] | None = None
    outside_colour: tuple[int, int, int] = NIGHT

    def px_per_dp(self) -> float:
        return self.visible / VISIBLE_DP


MOON = Mark(
    name="moon",
    source=ART / "scenes" / "street-door.jpg",
    # The moon is the circle (430, 208) r 161; the lantern hangs at
    # (462, 455). The window's middle sits between them.
    centre=(434.0, 272.0),
    visible=520.0,
    shadow_below=150,
    press=0.45,
    mono_above=165,
    mono_within=(430.0, 208.0, 161.0),
    mono_open=14,
    # The gable's roof: its peak, and its two edges running down past the
    # moon (along the outer side of the bone trim).
    mono_cut=((452.0, 252.0), (752.0, 712.0), (162.0, 712.0)),
    mono_warm=(432.0, 412.0, 496.0, 486.0),
)

# Tried, shown on the review sheet, not shipped.
LANTERN = Mark(
    name="lantern",
    source=ART / "tokens" / "lantern.jpg",
    centre=(160.0, 163.0),
    visible=330.0,
    mono_above=120,
    mono_within=(160.0, 163.0, 132.0),
    keep_within=(160.0, 160.0, 134.0),
    outside_colour=(31, 36, 67),
)
CANDIDATES = (MOON, LANTERN)
CHOSEN = MOON


# --- Pictures ---------------------------------------------------------------


def _source(mark: Mark) -> tuple[Image.Image, int]:
    """The source picture, toned, with room around it: the 108 dp canvas
    reaches past the art's edges, so its edge is mirrored outward (only in
    the margin a launcher keeps for its parallax, never shown at rest)."""
    im = Image.open(mark.source).convert("RGB")
    if mark.press > 0:
        im = _press_shadows(im, mark)
    if mark.keep_within:
        x, y, r = mark.keep_within
        inside = Image.new("L", im.size, 0)
        ImageDraw.Draw(inside).ellipse((x - r, y - r, x + r, y + r), fill=255)
        im = Image.composite(im, Image.new("RGB", im.size, mark.outside_colour), inside)
    pad = int(mark.px_per_dp() * CANVAS_DP)
    w, h = im.size
    big = Image.new("RGB", (w + 2 * pad, h + 2 * pad))
    big.paste(im, (pad, pad))
    # Outward, the art's last EDGE pixels mirrored back and forth: plain
    # sky above, not a second moon.
    for i in range(pad // EDGE + 1):
        flip = i % 2 == 0
        for side in ("left", "right"):
            box = (0, 0, EDGE, h) if side == "left" else (w - EDGE, 0, w, h)
            strip = im.crop(box)
            if flip:
                strip = strip.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            x = pad - (i + 1) * EDGE if side == "left" else pad + w + i * EDGE
            big.paste(strip, (x, pad))
    wide = big.crop((0, pad, w + 2 * pad, pad + h))
    for i in range(pad // EDGE + 1):
        flip = i % 2 == 0
        for side in ("top", "bottom"):
            box = (0, 0, wide.width, EDGE) if side == "top" else (0, h - EDGE, wide.width, h)
            strip = wide.crop(box)
            if flip:
                strip = strip.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            y = pad - (i + 1) * EDGE if side == "top" else pad + h + i * EDGE
            big.paste(strip, (0, y))
    return big, pad


def _press_shadows(im: Image.Image, mark: Mark) -> Image.Image:
    """Dark tones drawn toward the night ground; the light and the amber kept."""
    night = Image.new("RGB", im.size, NIGHT)
    lum = im.convert("L")
    # 0 at and above the threshold, rising to [press] at black.
    weight = lum.point(
        lambda v: (
            0
            if v >= mark.shadow_below
            else round(255 * mark.press * (1 - v / mark.shadow_below) ** 0.6)
        )
    )
    r, g, b = im.split()
    # The lantern's warm glass (red well above blue) is not pressed.
    warm = ImageChops.subtract(r, b).point(lambda v: 255 if v > 60 else 0)
    weight = ImageChops.subtract(weight, warm)
    return Image.composite(night, im, weight)


EDGE = 32  # pixels of the art's edge mirrored outward


_SOURCES: dict[str, tuple[Image.Image, int]] = {}


def window(mark: Mark, extent_dp: float, size: int) -> Image.Image:
    """[extent_dp] of the canvas around the mark's middle, as [size] square
    pixels (one resampling from the art)."""
    if mark.name not in _SOURCES:
        _SOURCES[mark.name] = _source(mark)
    big, pad = _SOURCES[mark.name]
    half = mark.px_per_dp() * extent_dp / 2
    cx, cy = mark.centre[0] + pad, mark.centre[1] + pad
    box = (cx - half, cy - half, cx + half, cy + half)
    return big.resize((size, size), Image.LANCZOS, box=box)


MONO_MASTER = 1728  # the monochrome shape is cut once at 16 px per dp


_MONO: dict[str, Image.Image] = {}


def _mono_master(mark: Mark) -> Image.Image:
    """The mark's one shape over the whole canvas, at [MONO_MASTER]."""
    size = MONO_MASTER
    big = window(mark, CANVAS_DP, size)
    shape = big.convert("L").point(lambda v: 255 if v > mark.mono_above else 0)
    scale = size / (mark.px_per_dp() * CANVAS_DP)  # master px per source px

    def at(x: float, y: float) -> tuple[float, float]:
        return (x - mark.centre[0]) * scale + size / 2, (y - mark.centre[1]) * scale + size / 2

    if mark.mono_open:
        k = int(mark.mono_open * scale) // 2 * 2 + 1
        # A closing of the light: thin dark lines across it (the twigs over
        # the moon) and the paper's grain fill in.
        shape = shape.filter(ImageFilter.MaxFilter(k)).filter(ImageFilter.MinFilter(k))
    if mark.mono_within:
        x, y, r = mark.mono_within
        (ox, oy), rr = at(x, y), r * scale
        disc = Image.new("L", shape.size, 0)
        ImageDraw.Draw(disc).ellipse((ox - rr, oy - rr, ox + rr, oy + rr), fill=255)
        shape = ImageChops.multiply(shape, disc)
    if mark.mono_cut:
        ImageDraw.Draw(shape).polygon([at(x, y) for x, y in mark.mono_cut], fill=0)
        # An opening: the specks the cut leaves (a chimney's gap) go.
        k = int(4 * scale) // 2 * 2 + 1
        shape = shape.filter(ImageFilter.MinFilter(k)).filter(ImageFilter.MaxFilter(k))
    if mark.mono_warm:
        r, g, b = big.split()
        warm = ImageChops.subtract(r, b).point(lambda v: 255 if v > 70 else 0)
        lit = g.point(lambda v: 255 if v > 110 else 0)
        box = Image.new("L", shape.size, 0)
        x0, y0, x1, y1 = mark.mono_warm
        ImageDraw.Draw(box).rectangle((*at(x0, y0), *at(x1, y1)), fill=255)
        glass = ImageChops.multiply(ImageChops.multiply(warm, lit), box)
        shape = ImageChops.lighter(shape, glass)
    return shape.filter(ImageFilter.GaussianBlur(2))


def monochrome(mark: Mark, extent_dp: float, size: int) -> Image.Image:
    """The mark as one shape (white on transparent), for Android 13's themed
    icons: the light of the picture (the moon and the lantern's glass),
    with the roof and the branches cut out of it."""
    if mark.name not in _MONO:
        _MONO[mark.name] = _mono_master(mark)
    master = _MONO[mark.name]
    half = MONO_MASTER * extent_dp / CANVAS_DP / 2
    c = MONO_MASTER / 2
    alpha = master.resize(
        (size, size), Image.LANCZOS, box=(c - half, c - half, c + half, c + half)
    )
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


def _mask(size: int, shape: str) -> Image.Image:
    """A launcher's mask, drawn 4x and reduced."""
    s = size * 4
    m = Image.new("L", (s, s), 0)
    d = ImageDraw.Draw(m)
    if shape == "circle":
        d.ellipse((0, 0, s - 1, s - 1), fill=255)
    elif shape == "rounded":
        d.rounded_rectangle((0, 0, s - 1, s - 1), radius=s * 0.22, fill=255)
    elif shape == "square":
        d.rounded_rectangle((0, 0, s - 1, s - 1), radius=s * 0.08, fill=255)
    elif shape == "squircle":
        # |x|^4 + |y|^4 <= 1, row by row.
        half = s / 2
        for row in range(s):
            y = (row + 0.5 - half) / half
            rest = 1 - y**4
            if rest <= 0:
                continue
            x = rest**0.25 * half
            d.line((half - x, row, half + x, row), fill=255)
    else:
        raise ValueError(shape)
    return m.resize((size, size), Image.LANCZOS)


def masked(im: Image.Image, shape: str) -> Image.Image:
    out = im.convert("RGBA")
    out.putalpha(_mask(im.size[0], shape))
    return out


def launch_mark(mark: Mark, size: int) -> Image.Image:
    """The launch mark: the safe circle of the icon, as a round window."""
    return masked(window(mark, SAFE_DP, size), "circle")


# --- Files ------------------------------------------------------------------


def _save(im: Image.Image, path: Path, *, lossless: bool = False) -> None:
    """PNG for the web; WebP on Android (every launcher since API 18 reads
    it, and the paper's grain costs a third of the bytes)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    # No metadata and fixed settings: the same pixels give the same bytes.
    if path.suffix == ".webp":
        if lossless:
            im.save(path, "WEBP", lossless=True, quality=100, method=6)
        else:
            im.save(path, "WEBP", quality=QUALITY, method=6)
    else:
        im.save(path, "PNG", optimize=True)
    print(path.relative_to(ROOT))


def write_android(mark: Mark) -> None:
    for density, k in DENSITIES.items():
        mip = RES / f"mipmap-{density}"
        layer = round(CANVAS_DP * k)
        legacy = round(LEGACY_DP * k)
        _save(window(mark, CANVAS_DP, layer), mip / "ic_launcher_foreground.webp")
        _save(
            monochrome(mark, CANVAS_DP, layer),
            mip / "ic_launcher_monochrome.webp",
            lossless=True,
        )
        # A pre-Android 8 launcher shows the picture as it is: the visible
        # 72 dp, shaped like the masks the newer ones apply.
        _save(
            masked(window(mark, VISIBLE_DP, legacy), "rounded"), mip / "ic_launcher.webp"
        )
        _save(
            masked(window(mark, VISIBLE_DP, legacy), "circle"),
            mip / "ic_launcher_round.webp",
        )
        draw = RES / f"drawable-{density}"
        _save(launch_mark(mark, round(SPLASH_MARK_DP * k)), draw / "launch_mark.webp")


def write_web(mark: Mark) -> None:
    icons = WEB / "icons"
    # Browser tabs and "any" icons: the round window, on nothing.
    _save(launch_mark(mark, 48), WEB / "favicon.png")
    for size in (192, 512):
        _save(
            masked(window(mark, VISIBLE_DP, size), "rounded"),
            icons / f"Icon-{size}.png",
        )
        # Maskable: the safe circle is the inner 80% of the picture.
        _save(window(mark, SAFE_DP / 0.8, size), icons / f"Icon-maskable-{size}.png")
    # iOS rounds the corners itself and wants no transparency.
    _save(window(mark, VISIBLE_DP, 180), icons / "apple-touch-icon.png")
    # The page's own launch mark, before Flutter paints (index.html rounds
    # it): 160 CSS pixels, sharp at 2.4x, small enough to come at once.
    path = icons / "launch-mark.webp"
    window(mark, SAFE_DP, 384).save(path, "WEBP", method=6, quality=80)
    print(path.relative_to(ROOT))


def write_preview(out: Path) -> None:
    """Each candidate's layers at 512, for the review sheet."""
    for mark in CANDIDATES:
        d = out / mark.name
        _save_preview(window(mark, CANVAS_DP, 768), d / "foreground.png")
        _save_preview(monochrome(mark, CANVAS_DP, 768), d / "monochrome.png")
        _save_preview(window(mark, VISIBLE_DP, 512), d / "visible.png")
        _save_preview(launch_mark(mark, 512), d / "launch_mark.png")


def _save_preview(im: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, "PNG")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--preview", type=Path, help="also write each candidate's layers here"
    )
    args = parser.parse_args()
    write_android(CHOSEN)
    write_web(CHOSEN)
    if args.preview:
        write_preview(args.preview)


if __name__ == "__main__":
    main()
