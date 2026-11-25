# The night's atmosphere: where the pieces came from

Two small sets for the night: the candle's flame in eight frames (`flame/`), so the clock can
gutter and recover in a short burst and rest on frame 1, and the moon in eight phases (`moon/`:
seven files, the full moon is the moon as it is), so a game can pick one still. Nothing in the
app draws them yet: they are art only, and the asset folder `atmo/` is not in `pubspec.yaml`.

All of it is original to this app and drawn by script (Python: numpy, OpenCV, Pillow). No image
model was used: the frames had to match each other and today's flame exactly, and the moon's
phases had to sit on the existing moon to the pixel, which a script does and a model does not.

| Piece | Made by | Shape, paper and texture came from |
|---|---|---|
| `flame/flame_1..8.png` | `frontend/tool/atmo/flame.py` | the outline and orange heart of today's flame (`assets/.../candle/flame.webp`, cut from `scenes/candle.jpg`), traced and smoothed into scissor curves; its colours sampled; seeded grain |
| `moon/<phase>.png` | `frontend/tool/atmo/moon.py` | the moon layer's disc (`layers/night-village/moon.png`, circle fitted: centre (606.5, 189.8), radius 104.65); the sky's paper from the plate under the moon (`village_plate.png`) |

## The flame

Masters are RGBA PNG at twice the flame sprite (240 x 212 for its 120 x 106); `just skin-art`
stores them at 120 x 106 (`assets/skins/shadow_paper/atmo/flame/flame_N.webp`, lossy WebP 72),
the size `CandleArt` declares for the flame, so any frame can stand where `candle/flame.webp`
stands: the same box at (60, 15) of the candle canvas, the foot on the wick at the bottom middle
(the sprite's (60, 106), the canvas's wick (120, 121)).

Three layers of paper at rest: a pale back sheet (`#FFDDAA`, the lit rim of today's flame), the
amber (`#E9AE6C`) laid on it 1.9 px right and 1.3 px down so the pale shows as a sliver on the
side toward the light, and the orange heart (`#D98542`) round the wick. Each has a dark cut line
on its far edge and casts a hard shadow (no blur) on the sheet under it. A notch is cut for the
wick: the wick shows through it from the wax sprite, as it does today. Grain, seeded (20261125):
a fine speck, a slow mottle, a few fibres and flecks. No glow: today's flame carried a faint
brown halo from the photograph; the gauge paints its own warm light behind the flame, so the
halo is left out (on the night ground the difference is a few levels at the rim).

Every frame is the one rest paper bent (so the grain and the layers travel with it): the bottom
10 px hold the wick and never move; above, the flame is scaled in height and width, leans at
the tip and bows in the middle. Two frames add a tongue cut from the tip that flies off.

| Frame | Height | Width | Lean at tip | What it is |
|---|---|---|---|---|
| 1 | 1.00 | 1.00 | 0 | rest: today's flame |
| 2 | 0.90 | 1.06 | +13 px | a draught leans it right |
| 3 | 0.64 | 1.20 | +5 | it gutters: low and fat |
| 4 | 0.58 | 1.10 | -5 | the tip splits off as a tongue |
| 5 | 0.84 | 0.95 | -11 | it rises; the tongue flies up-left, smaller |
| 6 | 1.10 | 0.90 | +6 | recovers, stretched tall |
| 7 | 0.96 | 1.03 | -3 | settling |
| 8 | 1.01 | 0.99 | +1 | back toward the rest |

The burst as it was judged (`sheets.py`'s `flame-burst.webp`): frames 2 to 8 at 70, 90, 110,
100, 90, 90, 110 ms (about 0.66 s), then frame 1. The gauge's `Transform.scale` by the time left
still applies to every frame (it scales about the foot).

## The moon

Masters are full-canvas RGBA PNG on the night village's canvas (768 x 1024), like the layers in
`../layers/night-village/`; each holds only the dark part of a phase. Laid on the `moon` layer,
moving with it (its `from` and `span`), and under the clouds' shadows on the moon, a phase turns
the full moon into itself. `just skin-art` cuts each to its box
(`assets/skins/shadow_paper/atmo/moon/<phase>.webp`, lossy WebP 72) and prints where it sits:

| Phase (in the month's order) | Size | Anchor on the canvas |
|---|---|---|
| `crescent_young` | 193 x 211 | (503, 84) |
| `crescent_waxing` | 161 x 208 | (503, 87) |
| `quarter_first` | 107 x 211 | (503, 84) |
| `gibbous_waxing` | 111 x 211 | (503, 84) |
| full | no file | the moon as it is |
| `gibbous_waning` | 109 x 210 | (603, 85) |
| `quarter_last` | 106 x 210 | (606, 85) |
| `crescent_waning` | 161 x 208 | (551, 87) |

The new moon is left out: it would be a dark disc, not a moon. Waxing is lit on the right.

The dark part is a piece of the sky's own paper laid over the moon: for a crescent or a quarter
the moon inside a disc (a quarter's disc is 40 moon radii, so its edge is all but straight), for
a gibbous moon the moon outside one (a crescent of sky paper on the limb). Its cut edge has a
scissor wobble (under half a pixel, seeded per phase), a lit lip on the side toward the light
(upper left, as in the village) and a dark cut line on the far side. It casts the look's paper
shadow on the bone: a hard contact copy (alpha .55, (+1, +1.5) px) and four stepped flat copies
(alpha .09 each, falling down and right), no blur; so a waxing moon shows a hard dark line along
its terminator and a waning one a lit paper edge. Its paint stops at the moon's bone, a hair
generous at the rim so no bone rings the dark part; the moon's own cast shadow on the sky stays,
so the dark disc still reads as a moon.

## Making them again

From `frontend/`:

    uv run --with numpy --with pillow --with opencv-python-headless python tool/atmo/flame.py
    uv run --with numpy --with pillow --with opencv-python-headless python tool/atmo/moon.py
    just skin-art
    uv run --with numpy --with pillow python tool/atmo/sheets.py /some/folder

Each step is deterministic. `sheets.py` draws the contact sheets the art was judged by: the
frames at 4x, frame 1 beside today's flame at 8x, every frame on the candle as `CandleGauge`
draws it (90 px, at 1x and 3x), the burst as an animated WebP, and the phases alone and in the
village with every layer at rest.

## Known limits

1. The flame's grain is a drawn grain: finer and calmer than the photographed speckle of
   today's flame, which shows at 8x and not on the phone.
2. The tongue in frames 4 and 5 is 3 to 4 px on a phone at 3x: it reads as a spark, not a shape.
3. The phases' terminators are circular arcs, a storybook moon, not the true elliptical
   terminator; the waning moon's lit lip is fainter than the waxing moon's shadow line.
