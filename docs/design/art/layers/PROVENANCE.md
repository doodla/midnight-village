# The layered scenes: where the pieces came from

04's village at night (`night-village/`) and 08's dawn (`dawn-gallows/`) are drawn in layers so the
moon, the clouds, the roofs, the birds and the sun can move on their own when a scene brings the
screen in (`docs/design/feel.md`). The layers are the files here: full-canvas PNG masters with
alpha (the sun is a 150 x 150 sprite). `just skin-art` cuts each to the box it paints and writes
`frontend/assets/skins/shadow_paper/layers/<scene>/<layer>.webp`, and prints the size and anchor the
skin must declare (`frontend/lib/design_system/skin/skins/shadow_paper.dart`, `LayeredScene`).
`flat.jpg` in each folder is the picture the layers were cut from; it is not shipped, and
`frontend/test/design_system/skin/layered_scene_test.dart` draws the layers at rest and holds them to it.

All of it is original to this app. Every piece was cut from the two flat pictures that shipped before
(`flat.jpg`) and, where a hole had to be filled or a disc built, made from texture sampled out of the
same art, with Pillow, numpy and OpenCV (scipy for one median filter). One image-model call was made
(`gpt-image-2`, images/edits, to fill the hills behind the gallows); its result repainted the whole
crop and was discarded, so no pixel of it is in any layer. The scripts were run in a scratch
folder and are not kept here: the PNGs are the record, and `flat.jpg` is the check.

| Piece | Made by | Texture / content came from |
|---|---|---|
| 04 `moon` | circle fit to the disc edge, alpha from the picture at the rim; the parts hidden by two clouds rebuilt from the moon's own paper (smooth base plus tiled grain from clean moon pixels) | 04 moon |
| 04 `clouds_dark`, `clouds_cream` | thresholded cuts, rim alpha measured against the plate; the thin dark tip over the moon redrawn as a flat sliver with a torn edge, the cream tail over the moon drawn as a wedge by hand, both with the grain of their own cloud | 04 clouds |
| 04 `clouds_*_shadow` | the clouds' soft cast shadows on the sky, kept as black alpha | 04 |
| 04 `moon_shadow_*` | the clouds' shadows on the moon, computed from the cloud shapes (soft term offset (+1,+7), blur 5; hard contact term offset (-2,+5), blur 2.5), fitted to the picture | 04 |
| 04 `village_plate` | clouds, moon and their shadows removed; holes filled by a cubic sky model plus grain tiled from clean sky | 04 sky |
| 08 `sky_plate` | sky and the pale band with the baked sun lifted out; holes filled from the band and the sky | 08 sky |
| 08 `sun` | disc cut from the moon's bone paper at 1:1 with a slightly irregular scissor-cut edge, lit lip upper right, thin darker paper outline, hard shadow down and left | 04 moon paper |
| 08 `hills_far` | everything under the first ridge except the pale band; holes behind the gallows and roofs filled by a smoothed row fill with grain | 08 hills |
| 08 `gallows`, `birds` | colour masks, rim alpha measured against what is behind | 08 |
| 08 `roofs_mid`, `roofs_near` | one roof cut, then split along the seams read off the picture; the middle roofs continue 14 px under the near roofs | 08 roof paper |

## What each layer may do (and why the skin keeps to it)

- A file named `*_bleedNN` carries NN px of mirrored paper outside the canvas on the sides it slides
  toward (04: 16 px left and right; 08: 12 px on every side), so a moved layer still reaches the
  picture's edge. The art is cut for: 04's moon 60 px up or down, each cloud and its shadows 12 px sideways
  (a cloud's own shadow moves with it); 08's roofs about 4 to 8 px of difference between the near and
  the middle roofs before a seam shows (the app moves them much further, from below the window's faded
  foot, where the rest is hidden), the birds freely.
- Light: 04 from the upper left (shadows fall down and right), 08 from the upper right (down and left).
- The shadows of the clouds on the moon are drawn over the moon only where the moon has paint
  (`BlendMode.srcATop`), and move with their cloud sideways, not with the moon.
- The sun sits under the hills, so it can come up from behind them; its path is the screen's.

## Known limits (what would not survive 3x)

1. The dark cloud's tip over the moon is a little pixel-stepped at 3x (its end is about 3 px thick); fine at
   2x on a phone.
2. The cream cloud's tail has no dark underside line like the original's; its shadow is a computed soft one.
3. The hills behind the gallows legs and chimney are filled, not drawn; the gallows' feet and the notches in the
   ridge edge next to the legs show small ragged bits at 4x. The hills layer's left end (x 253) is only hidden by the
   near roofs, so the roofs and the hills rise together.
4. The sun's edge is generated (a wobble), not scanned from a real cut: it reads as hand-cut, but is a different paper
   object from the moon's near-perfect circle.
5. If any of 1 to 3 must be perfect, they need an illustrator pass on `hills_far` and the two tips.

Drawn at rest against the flat pictures (`flat.jpg`, 8-bit, as the test measures: blocks of 4 x 4 px, the sun's disc left
out of 08): the mean difference is about 1.1 (04) and 1.5 (08); single rim pixels differ by up to 200.
