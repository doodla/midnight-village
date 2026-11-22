# The card backs: where they came from

Five backs, one drawn for a whole game (`frontend/lib/design_system/skin/card_back.dart`: chosen from the
game's id; the calm one, `moon`, outside a game). The owner saw five options and said "Randomize between
all 5. They're all better than the current one." They replace the single card back (a thorn-framed eye)
that shipped before.

All five are 1200 x 1600 JPEG masters (3:4). `just skin-art` makes
`frontend/assets/skins/shadow_paper/scenes/card_back_<name>.webp` (600 x 800, WebP quality 75) from each,
deterministically.

| File | Idea | Picture | Made from |
|---|---|---|---|
| `moon.jpg` | Crescent moon over low rooftops, one lit window. The one outside a game. | The moon cradles the middle (where the Hold disc sits), three stars, rooftops along the foot. One way up. | OpenAI `gpt-image-2`, an edit of a first result (moon moved down, spire dropped) |
| `window.jpg` | A lit window in a dark cottage. | Dark gable, one lit lattice window high up, calm wall below. One way up. Mirrored left to right. | `gpt-image-2` |
| `teeth.jpg` | Wolf-tooth bone border. | Symmetric paper-cut border of fangs round a calm middle, one small amber diamond. Same upside down. Mirrored both ways. | `gpt-image-2` |
| `eye.jpg` | A wolf's eye. | Three shapes: almond, bone rim, slit pupil. Same upside down. Mirrored both ways. The almond is toned to dusty gold (below). | `gpt-image-2` |
| `quilt.jpg` | Star quilt. | Lone star in bone and dusty indigo, calm hub with a diamond. Same upside down. Mirrored both ways. | `gpt-image-2` |

## Making

1. Generation: `gpt-image-2`, 1200 x 1600, quality high, text prompts only (style descriptions; no names, no
   project name). 13 calls in all; the five kept are the ones named above. The rest were thrown away: a moon too
   high so the Hold disc cut it, a window hidden under the Hold disc, cross-shaped bars that read as a church, a
   rug-like border with no card rim, a loud red, white and blue quilt, a quilt of twelve stars.
2. Clean-up: the left half (window) or left and top (teeth, eye, quilt) mirrored over the rest for exact
   symmetry; the colours graded toward the app's palette (blues toward the violet-leaning indigo, hue +14 and
   saturation -18%; bone lifted and warmed); the window's dark tones lifted (gamma 0.78) so it does not melt into
   the table; the frame evened (the bone rim measured to the red line on all four sides, trimmed to the
   narrowest, scaled back to 1200 x 1600).
3. Finishing, so they sit in the cut-paper world of the rest of the art (Pillow, numpy, scipy):
   - a deeper lip shadow: the red frame's own cast shadow (offset down and to the right, softened, 62% strong)
     laid on what lies inside it, so the frame stands up from the field;
   - a little paper grain: fine, soft noise (2 to 3% of the range, most in the mid tones), one seed per card;
   - `eye`: the almond's amber (the primary button's hue, and ten of them on a board of ten) lowered to dusty
     gold (saturation -38%, value -20%, on the amber only), so the one amber fill on a screen is still the
     button. The amber rule's test (`amber_rule_test.dart`) counts widgets and does not see pictures, so it passed
     either way; this is for the eye;
   - `window`: a soft warm halo round the lit window, and the window a little brighter, so it reads at the 55 px
     card of a board of ten.

The scripts were run in a scratch folder and are not kept here: the JPEGs are the record.

## Prompts of the kept pictures

Shared style words: layered cut paper photographed top-down, sharp angular cuts, stacked layers with a thick
paper edge and a hard cast shadow, visible paper grain, matte, not glossy or plastic; palette midnight indigo,
bone white, dried-blood red, a little lantern amber; no text, no people, readable as a thumbnail.

### `moon` (A3)

```text
Back of a playing card, portrait, filling the whole canvas edge to edge, made entirely of layered cut paper photographed top-down: sharp angular scissor-cut edges, clearly stacked paper layers each with a visible thick paper edge and a deep hard dark cast shadow beneath it, visible paper fibre grain, matte paper, nothing glossy or plastic. Palette only: deep dark midnight indigo (nearly black-blue), bone white, a little dried-blood red, a tiny touch of lantern amber.
Design: one single bold motif. A bone-white crescent moon, opening upward like a bowl, about 60 percent of the card's width. The centre of the crescent's circle (the middle of its empty bowl) is exactly at the centre point of the card, 50 percent down from the top and 50 percent across, so the whole crescent sits in the middle of the card with equal empty sky above and below it. Above the moon, in the top quarter, three small bone cut-out four-point stars. Below the moon, only in the bottom 12 percent of the card, a low row of jagged angular village rooftops with one church spire, cut from near-black indigo paper in two stacked layers; exactly one tiny amber lit window on one house. The sky is flat dark indigo paper. The empty bowl of the moon is calm and plain.
A thin even bone-white paper border frames the card, with a thin dried-blood red inner line, border no wider than 3 percent of the card width.
Very simple, graphic, readable as a tiny thumbnail, large shapes, strong contrast between bone-white and the dark. No text, no letters, no numbers, no people, no faces, no eye.
```

### `moon` (A4 (edit of A3))

```text
Keep this exact cut-paper card back, same style, same colours, same border, same rooftops and same amber window, but move the bone crescent moon and its three stars down by about 12 percent of the card height, so that the middle of the moon's empty bowl is exactly at the centre of the card. Remove the church spire so nothing touches the moon, and keep the rooftops low along the bottom edge. Nothing else changes. No text.
```

### `window` (B3)

```text
Back of a playing card, portrait, filling the whole canvas edge to edge, made entirely of layered cut paper photographed top-down: sharp angular scissor-cut edges, clearly stacked paper layers each with a visible thick paper edge and a deep hard dark cast shadow beneath it, visible paper fibre grain, matte paper, nothing glossy or plastic. Palette only: deep dark midnight indigo (nearly black-blue), bone white, a little dried-blood red, and ONE glowing lantern-amber window.
Design: a lit window in a dark house. The whole card is the front wall of one dark cottage made of stacked near-black indigo paper layers: a steep pointed gable roof at the top with a lighter indigo roof edge, and below it a big plain calm wall with only faint horizontal board lines. In the upper third, exactly centred horizontally, its top at about 22 percent and its bottom at about 45 percent of the card height, ONE small window with a pointed arch top, glowing lantern amber, with a diamond-lattice of thin bone-white leaded bars across it (crossing diagonal bars, NOT a plus or cross shape), set deep in the wall through two stacked frame layers with a bone-white sill. Nothing else on the wall: the lower half of the card is a calm, plain, dark, finely paper-grained wall. Left and right halves are exact mirror images.
A thin even bone-white paper border frames the card, with a thin dried-blood red inner line, border no wider than 3 percent of the card width.
Very simple, graphic, readable as a tiny thumbnail: a single amber glint in a dark card. No text, no letters, no numbers, no people, no faces, no eye, no cross.
```

### `teeth` (C2)

```text
Back of a playing card, portrait, filling the whole canvas edge to edge, made entirely of layered cut paper photographed top-down: sharp angular scissor-cut edges, clearly stacked paper layers each with a visible thick paper edge and a deep hard dark cast shadow beneath it, visible paper fibre grain, matte paper, nothing glossy or plastic. Palette only: deep dark midnight indigo (nearly black-blue), bone white, a little dried-blood red, a tiny touch of lantern amber.
Design: a perfectly symmetrical paper-cut border with a calm centre, identical on all four sides, the same when turned upside down. From the outside in: an even thin bone-white paper rim; a narrow band of dried-blood red; then a wide bone-white band (about 12 percent of the card width) whose inner edge is cut into a row of sharp triangular fangs pointing inward like wolf teeth, an odd number of fangs per side with one fang exactly on the middle of each side; in each of the four corners one larger bone-white diamond with a smaller dried-blood red diamond inside it. Inside the border: a large completely calm field of plain dark indigo paper, nothing in it except one small amber diamond exactly at the centre. The calm field is more than half the card.
Very simple, graphic, readable as a tiny thumbnail, strong contrast between bone-white and the dark. No text, no letters, no numbers, no people, no faces.
```

### `eye` (D1)

```text
Back of a playing card, portrait, filling the whole canvas edge to edge, made entirely of layered cut paper photographed top-down: sharp angular scissor-cut edges, deep hard dark shadows between the paper layers, visible paper fibre grain, matte paper, nothing glossy or plastic. Palette only: deep midnight indigo, bone white, a little dried-blood red, lantern amber.
Design: a wolf's eye reduced to just three bold shapes. In the exact centre, one huge almond-shaped lantern-amber paper eye, wide as most of the card, pointed at both ends; in the middle of it a tall narrow vertical slit pupil cut from near-black indigo paper; around the almond a single sharp bone-white paper rim like a wolf's eye-shape. Nothing else in the middle, no eyelashes, no iris detail, no veins. Behind it a flat dark indigo field with a very faint large diamond shape cut into it in a slightly lighter indigo. The eye is perfectly symmetric left-right and top-bottom, so the card looks identical when turned upside down. A thin even bone-white paper border frames the card with a thin dried-blood red inner line.
Very simple, graphic, readable as a tiny thumbnail, large shapes, strong contrast. No text, no letters, no numbers, no people, no faces.
```

### `quilt` (E3)

```text
Back of a playing card, portrait, filling the whole canvas edge to edge, made entirely of layered cut paper photographed top-down: sharp angular scissor-cut edges, clearly stacked paper layers each with a visible thick paper edge and a deep hard dark cast shadow beneath it, visible paper fibre grain, matte paper, nothing glossy or plastic.
Palette: mostly bone white and tones of deep midnight indigo (a very dark indigo, a mid slate-indigo and a soft dusty periwinkle-indigo), with dried-blood red used only in tiny amounts, and one tiny amber diamond.
Design: a folk lone-star quilt in cut paper. One large eight-pointed star, centred, filling most of the card, built from rings of sharp diamond-shaped paper patches radiating from the exact centre: the outer ring of diamonds bone white, the next ring mid slate-indigo, the next ring bone white again, and the hub at the centre a calm plain very-dark-indigo octagon with nothing in it except one tiny amber diamond exactly at the centre. The star sits on a very dark indigo field; the corners and the spaces between the star's points are plain triangles and squares of soft dusty indigo, like patchwork, with a tiny dried-blood red diamond in each of the four corners. The star is symmetric left-right and top-bottom, so the card looks identical when turned upside down. Big bold patches, only a few of them, no tiny detail, no stripes.
A thin even bone-white paper border frames the card, with a thin dried-blood red inner line, border no wider than 3 percent of the card width.
Very simple, graphic, readable as a tiny thumbnail, strong contrast between bone-white and the dark. No text, no letters, no numbers, no people, no faces, no eye.
```
