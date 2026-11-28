# The end board's ornaments: where the art came from

The masters here (RGBA PNG) are what `just skin-art` (`frontend/tool/skin_art.py`, `END`) turns into
`frontend/assets/skins/shadow_paper/end/<name>.webp`: lossless-alpha WebP, method 6, quality 80, the same
pipeline and quality as the layered scenes. 462 KB (461,784 bytes) in all.

**Accepted as final art by the owner on 23 Nov 2026** (the nine kinds of ornament below, shown on the end board's
sheet-final.png). One new image was generated with the owner's yes the same day: the red banner.

## How they were made

All but the red banner: OpenAI `gpt-image-2`, `POST /v1/images/generations`, quality high (1536x1024, or 1024x1536
for the lantern), one request each. The model cannot make a transparent background, so each object was made on flat
chroma-key green (#00FF00) and keyed out (chroma key, despill, closing, largest piece, a small pad) into the PNG.
The prompts describe art and style only: no names, no project, no text. Round three's were made on 23 Nov 2026 as
the bold pass, round four's the same day as the finishing pass.

Shared style text of round three: "Style: handmade cut-paper collage, layered torn and cut paper with soft real
shadows between the layers, visible paper grain and fibres, matte, not glossy, not 3D render, not vector. Palette:
deep midnight indigo, bone white, weathered dark wood browns, iron grey; dried-blood red only where asked. The
object is isolated on a perfectly flat, uniform, pure chroma-key green background (#00FF00) ... no text, no letters,
no writing, no numbers, no symbols, no signature, no watermark."

Shared style text of round four: "Style: handmade cut-paper collage made with scissors and a craft knife: each piece
is one flat matte colour of thick coarse paper with a visible fibrous torn or cut edge; no photographic texture, no
painted detail, no gloss, no 3D render, not vector. Palette: deep midnight indigo, bone white, dark warm browns,
iron grey. ... isolated on a perfectly flat, uniform, pure chroma-key green background (#00FF00) ..."

| Master | App file | Stored at | What it is, and its subject prompt |
|---|---|---|---|
| `banner.png` 1460x477 | `banner.webp` | same | round 3. "One long horizontal swallowtail ribbon banner, completely blank, cut from bone-white paper with a subtle deckled edge; each end folds back behind itself showing a darker underside and finishes in a forked swallowtail notch. A small cut-paper laurel branch of dark indigo and bone leaves crosses behind each folded end. The flat middle of the ribbon is wide, plain and empty." Drawn as a three-slice. |
| `banner-red.png` 1460x477 | `banner_red.webp` | same | **23 Nov 2026, with the owner's yes** ("Yes, generate it."): `gpt-image-2`, `POST /v1/images/edits`, 1536x1024, quality high, n 1, one image on the first try. Input: the bone banner's own original on green. Prompt: edit only the colour of the ribbon's paper to dried-blood red (a deep muted brick red like #8a2a22, matte, the same grain, fibres and deckled edge, folded undersides darker), keep everything else exactly (silhouette, outline, folds, size, placement, soft shadows, the laurel leaves, the flat green). Clean-up: the same key steps as the bone banner (it comes out the same 1460x477), then one light grade on the red pixels only (the middle from about #aa251d to #962a22, the palette's dried-blood red). Checked against the bone banner: the same bounding box, silhouettes overlap 98.6%. It replaces an earlier recolour made in code ("a look is never a recolour"), which is not used. One request before it was refused by the API (the `input_fidelity` setting is not supported by this model) and made nothing. |
| `lantern.png` 677x1170 | lantern.webp 264x456 | 3x of 88x152 | round 3. "A hanging village lantern cut from paper: black iron frame with a little pointed cap and a ring on top, four panes of thin paper lit from inside by a candle so they glow a pale warm honey light; no halo or glow spilling onto the background. It hangs from a short curled iron bracket." |
| `cobbles.png` 1467x816 | `cobbles.webp` 1170x651 | 3x of 390 wide | round 3 (made twice by mistake; the second is the one). "A wide strip of cobbled village ground seen from slightly above, rounded cobblestones each cut from deep indigo and slate paper with grey edges, a few loose straw bits, filling the whole picture edge to edge with no background visible and no green, softly lit from above." |
| `marks-1.png` 430x430 | `seal.webp` 90x90 | 3x of 30 | round 3, one object of the sheet "marks": "a round blank wax seal of black-indigo wax with a raised rim and drips". The player's own sigil is pressed on it in code. |
| `marks-4.png` 382x482 | `ribbon.webp` 153x193 | 4.5x of 34 | round 3, another object of "marks": "a short folded black mourning ribbon like a corner sash". The death mark. |
| `frame4.png` 666x863 | `frame.webp` | same | round 4. "An empty rectangular notice-board frame seen straight on, built from four coarse planks of thick dark-brown paper, each plank a flat strip with torn fibrous edges, two or three long knife-cut grain lines, and a thin lighter-brown paper strip along its inner edge; small flat iron-grey paper plates on the four corners and a few small flat paper nail discs. The inside of the frame is completely empty and the same flat chroma-key green." Drawn as a nine-slice. |
| `roof4.png` 629x140, `post4-l.png` 79x147, `post4-r.png` 81x148 | `roof.webp`, `post_l.webp`, `post_r.webp` | same | the same image as the frame: "a long low pitched roof strip of overlapping flat slate-blue paper shingles; and under it, two short square posts of the same dark-brown paper", cut out of it. The roof is a three-slice. |
| `crow4-1.png` to `crow4-6.png` | `crow_1.webp` to `crow_6.webp` | 312 wide at most | round 4. "Six crows, each cut from a single layer of flat matte black paper: bold simple silhouettes with scissor-cut edges and a few sharp V-shaped notches for feathers; no painted feathers, no shading, no highlights. Each in a different pose (wings raised, wings down, gliding, landing, turning, perched), scattered well apart with space between them." Cut into six files. |

Everything else on the board (felt, grain, pins, twine, tags, scraps, slips, the stamp and its ink burst, the glow,
the pool and the vignette) is drawn in code.
