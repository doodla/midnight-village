# The roles' art: where it came from

Twelve role masters, 576 x 768 JPEG (3:4); `just skin-art` (from `frontend/`) makes
`frontend/assets/skins/shadow_paper/roles/<name>.webp` from each (same size, WebP quality 75, deterministic).
The Werewolf has three masters, one drawn for a whole game (`frontend/lib/design_system/skin/werewolf_portrait.dart`:
chosen from the game's id like the card back, with a different salt; the lunge outside a game):
`werewolf_lunge.jpg`, `werewolf_stare.jpg`, `werewolf_snarl.jpg`. The other ten roles' history was not recorded.

## The owner's words (23 November 2026)

The first Werewolf portrait was "dopey and not dangerous". Shown five redraws (A to E), the owner chose:
"Lunging. I also like the cold stare/snarling. Randomize these as well for the game" ("as well" as the card
backs). So C is `werewolf_lunge`, B is `werewolf_stare`, A is `werewolf_snarl`; D (the turning) and E (the
moon silhouette) were not kept, and the old werewolf.jpg is gone.

## Werewolf redraw: where the candidates came from

Five candidates (A to E) to replace docs/design/art/roles/werewolf.jpg. Masters are 576 x 768 JPEG (3:4), the
size of every role master and of the shipped `frontend/assets/skins/shadow_paper/roles/<name>.webp`
(`frontend/tool/skin_art.py`, ROLE). There was no provenance file for the roles; this follows the card backs'
(`docs/design/art/card-backs/PROVENANCE.md`).

### Generation

OpenAI `gpt-image-2`, images/edits, 1200 x 1600, quality high, n 1, with two sibling portraits as style
references (`docs/design/art/roles/seer.jpg`, `minion.jpg`, sent as `image[]`). Text prompts only: art and style
descriptions, no names, no project or game name. Script: tools/gen.sh (the key only from the environment, in
the request header). Raw results: `raw/<id>.png`.

8 calls in all (budget 12):

| Call | Idea | Kept? |
|---|---|---|
| a1 | low three-quarter snarl | no: head small, pushed into the lower left, a grey blob at 56 px |
| a2 | same, head hung between the shoulders, eyes up | no: best pose, but a dark fur mass at 56 px; alternative if the owner prefers the pose |
| a3 | same, face all bone-white, hung between dark shoulders | **A** |
| b1 | still cold stare, mouth shut, torn ear | **B** |
| c1 | mid-lunge, jaws open, claw, shards | **C** |
| d1 | man turning: wolf muzzle bursting from the face, claw hand | **D** |
| e1 | silhouette against the moon | no: the head sat below the moon, so dark on indigo |
| e2 | same, the head inside the moon's disc | **E** |

### Clean-up (tools/finish.py, deterministic)

1. Resized 1200 x 1600 -> 576 x 768 (Lanczos).
2. Graded toward the palette as the card backs were: blues (hue 190-265) hue +14 and saturation -18% toward
   the violet-leaning indigo; bone (bright, low saturation) lifted 4% and warmed; darks lifted (gamma 0.9) so
   the figure does not sink into the indigo ground (the raws sat darker than the siblings).
3. Paper grain: fine soft noise, 2.5% of the range, mostly in the mid tones, one seed per file (CRC of the name).
4. Shadow: the model's own cut-paper cast shadows kept; no frame, so no lip shadow added.
5. Saved as JPEG quality 92. The kept three are `werewolf_lunge|stare|snarl.jpg` here; the script is `finish_werewolf.py`.

sheet.png: row 1 the current portrait and A to E at 288 x 384; row 2 each at 56 px wide on the indigo ground
beside the Seer and Minion (tools/sheet.py).

### Prompts

Each prompt is the idea followed by the shared style paragraph (the last paragraph of every prompt file in
prompts/). Full text below.

#### prompts/a.txt (call a1)

```text
A werewolf: a huge wolf head on a hunched man's shoulders in a torn dark coat. Pose: low three-quarter view, the head turned to the left and dropped BELOW the line of the hunched shoulders, as if about to spring; the eyes look UP at the viewer from under a heavy brow, narrow slanted wolf eyes, glowing pale amber with tiny black slit pupils, deep shadow above them. Long narrow wolf muzzle, the upper lip curled back in a snarl with the nose wrinkled into hard cut ridges; long sharp fangs cut as clean bone-white paper triangles, top and bottom, the gums a small patch of dried-blood red. Ears pinned flat back. The hackles stand up along the neck and shoulders as jagged torn indigo and slate paper spikes. Asymmetric, tense, coiled.
Style: match the two reference images exactly in hand and finish: a character portrait made entirely of layered cut and torn paper collage, photographed straight on under soft light. Flat shapes of matte coloured paper with sharp scissor-cut and torn edges, stacked in layers with soft real cast shadows between them, visible paper fibre grain everywhere. No outlines, no ink lines, no airbrush gradients, nothing glossy, nothing photographic, not a 3D render. Palette only: deep midnight indigo (near black-blue) and dusty slate indigo, bone white, dried-blood red used sparingly in one or two small places, and at most a small touch of lantern amber. Framing like the references: one figure, head and shoulders, the head large in the upper middle of a portrait 3:4 card, the shoulders reaching the bottom edge, a simple dark indigo night background. The creature must be frightening and dangerous, never cute, goofy, cartoonish or surprised: no round eyes, no white of the eye, no button nose, no smile, no grin. It must read as a tiny thumbnail: a strong clear silhouette, the face built from big bone-white paper planes against the dark, eyes and fangs bold and legible. No gore, no blood, no text, no letters.
```

#### prompts/b.txt (call b1)

```text
A werewolf: a large gaunt wolf head on a man's shoulders, a dark high-collared coat. Pose: perfectly still, the head straight on and slightly lowered, chin down, staring straight into the viewer. Menace by restraint: the mouth is CLOSED, a long hard flat jaw line, only the tips of two long lower fangs show over the lip. Eyes: narrow, slanted, heavy-lidded predator eyes cut in pale bone with tiny black slit pupils, set under a low hard brow, cold and unblinking. The long muzzle is cut from bone-white and pale slate paper in sharp angular planes; a dark indigo shadow plane runs down one side of the face, so the face is not symmetric. One ear stands tall, the other is torn, with a ragged notch bitten out of it. A single thin dried-blood red scar across the muzzle. No snarl, no open mouth: cold, quiet, certain.
Style: match the two reference images exactly in hand and finish: a character portrait made entirely of layered cut and torn paper collage, photographed straight on under soft light. Flat shapes of matte coloured paper with sharp scissor-cut and torn edges, stacked in layers with soft real cast shadows between them, visible paper fibre grain everywhere. No outlines, no ink lines, no airbrush gradients, nothing glossy, nothing photographic, not a 3D render. Palette only: deep midnight indigo (near black-blue) and dusty slate indigo, bone white, dried-blood red used sparingly in one or two small places, and at most a small touch of lantern amber. Framing like the references: one figure, head and shoulders, the head large in the upper middle of a portrait 3:4 card, the shoulders reaching the bottom edge, a simple dark indigo night background. The creature must be frightening and dangerous, never cute, goofy, cartoonish or surprised: no round eyes, no white of the eye, no button nose, no smile, no grin. It must read as a tiny thumbnail: a strong clear silhouette, the face built from big bone-white paper planes against the dark, eyes and fangs bold and legible. No gore, no blood, no text, no letters.
```

#### prompts/c.txt (call c1)

```text
A werewolf mid-lunge toward the viewer: a huge bone-white wolf head thrust forward and tilted at a sharp diagonal, jaws wide open in attack, long sharp bone fangs cut as clean triangles, a dark indigo throat inside, a small dried-blood red tongue. The eyes narrowed to slanted amber slits under a crushed brow, the nose wrinkled back. Ears flattened by the speed. One clawed hand with long hooked bone claws reaches out from the lower corner toward the viewer. Torn paper shards and slivers fly outward around the head, showing the motion. Strongly asymmetric, diagonal, violent energy, the whole figure leaning out of the frame.
Style: match the two reference images exactly in hand and finish: a character portrait made entirely of layered cut and torn paper collage, photographed straight on under soft light. Flat shapes of matte coloured paper with sharp scissor-cut and torn edges, stacked in layers with soft real cast shadows between them, visible paper fibre grain everywhere. No outlines, no ink lines, no airbrush gradients, nothing glossy, nothing photographic, not a 3D render. Palette only: deep midnight indigo (near black-blue) and dusty slate indigo, bone white, dried-blood red used sparingly in one or two small places, and at most a small touch of lantern amber. Framing like the references: one figure, head and shoulders, the head large in the upper middle of a portrait 3:4 card, the shoulders reaching the bottom edge, a simple dark indigo night background. The creature must be frightening and dangerous, never cute, goofy, cartoonish or surprised: no round eyes, no white of the eye, no button nose, no smile, no grin. It must read as a tiny thumbnail: a strong clear silhouette, the face built from big bone-white paper planes against the dark, eyes and fangs bold and legible. No gore, no blood, no text, no letters.
```

#### prompts/d.txt (call d1)

```text
A man at the moment of turning into a wolf. The head is already mostly a wolf: a long bone-white wolf muzzle bursting out of a gaunt human face, the human side of the jaw splitting, long fangs pushing out of the lips; narrow slanted amber eyes with slit pupils, hard brow, a snarl. Head tilted, in pain and fury. Coarse dark indigo fur in jagged torn paper spikes spreading up the neck and over the scalp. His shirt collar torn open at the throat, the collar and coat ripping at the shoulder seam. One hand raised in front of the chest, half human, the fingers stretching into long hooked bone claws. Asymmetric, tense, dangerous.
Style: match the two reference images exactly in hand and finish: a character portrait made entirely of layered cut and torn paper collage, photographed straight on under soft light. Flat shapes of matte coloured paper with sharp scissor-cut and torn edges, stacked in layers with soft real cast shadows between them, visible paper fibre grain everywhere. No outlines, no ink lines, no airbrush gradients, nothing glossy, nothing photographic, not a 3D render. Palette only: deep midnight indigo (near black-blue) and dusty slate indigo, bone white, dried-blood red used sparingly in one or two small places, and at most a small touch of lantern amber. Framing like the references: one figure, head and shoulders, the head large in the upper middle of a portrait 3:4 card, the shoulders reaching the bottom edge, a simple dark indigo night background. The creature must be frightening and dangerous, never cute, goofy, cartoonish or surprised: no round eyes, no white of the eye, no button nose, no smile, no grin. It must read as a tiny thumbnail: a strong clear silhouette, the face built from big bone-white paper planes against the dark, eyes and fangs bold and legible. No gore, no blood, no text, no letters.
```

#### prompts/e.txt (call e1)

```text
A werewolf as a silhouette against a huge full moon: a large plain bone-white paper moon fills the upper two thirds behind it. In front, the head and hunched shoulders of a werewolf cut entirely from near-black indigo paper, a three-quarter view, a long wolf muzzle, ears pointed and laid back, rough jagged fur along the neck and shoulders in torn paper spikes, a hunched shoulder line. The silhouette has no face detail at all except two things: two narrow slanted glowing amber eyes with slit pupils, and a snarling row of long bone-white fang triangles in the slightly open jaw. Everything else is dark shape against the bright moon. Stark, graphic, menacing.
Style: match the two reference images exactly in hand and finish: a character portrait made entirely of layered cut and torn paper collage, photographed straight on under soft light. Flat shapes of matte coloured paper with sharp scissor-cut and torn edges, stacked in layers with soft real cast shadows between them, visible paper fibre grain everywhere. No outlines, no ink lines, no airbrush gradients, nothing glossy, nothing photographic, not a 3D render. Palette only: deep midnight indigo (near black-blue) and dusty slate indigo, bone white, dried-blood red used sparingly in one or two small places, and at most a small touch of lantern amber. Framing like the references: one figure, head and shoulders, the head large in the upper middle of a portrait 3:4 card, the shoulders reaching the bottom edge, a simple dark indigo night background. The creature must be frightening and dangerous, never cute, goofy, cartoonish or surprised: no round eyes, no white of the eye, no button nose, no smile, no grin. It must read as a tiny thumbnail: a strong clear silhouette, the face built from big bone-white paper planes against the dark, eyes and fangs bold and legible. No gore, no blood, no text, no letters.
```

#### prompts/a2.txt (call a2)

```text
A werewolf: a huge wolf head on a hunched man's shoulders in a torn dark coat. Composition: the head is LARGE, filling the middle of the card, its centre slightly above the middle of the picture; the two hunched shoulders rise high on both sides of the head, nearly to the level of the ears, so the head hangs low BETWEEN and slightly below the shoulder line, as if about to spring. Low three-quarter view, the muzzle turned toward the lower left. The eyes look UP at the viewer from under a heavy brow: narrow slanted wolf eyes, glowing pale amber with tiny black slit pupils, deep shadow above them. Long narrow bone-white wolf muzzle, the upper lip curled back in a snarl, the nose wrinkled into hard cut ridges; long sharp fangs cut as clean bone-white paper triangles, top and bottom, the gums a small patch of dried-blood red. Ears pinned flat back. The hackles stand up along the neck and shoulders as jagged torn indigo and slate paper spikes. Asymmetric, tense, coiled. Small cut-paper bare trees in the background.
Style: match the two reference images exactly in hand and finish: a character portrait made entirely of layered cut and torn paper collage, photographed straight on under soft light. Flat shapes of matte coloured paper with sharp scissor-cut and torn edges, stacked in layers with soft real cast shadows between them, visible paper fibre grain everywhere. No outlines, no ink lines, no airbrush gradients, nothing glossy, nothing photographic, not a 3D render. Palette only: deep midnight indigo (near black-blue) and dusty slate indigo, bone white, dried-blood red used sparingly in one or two small places, and at most a small touch of lantern amber. Framing like the references: one figure, head and shoulders, the head large in the upper middle of a portrait 3:4 card, the shoulders reaching the bottom edge, a simple dark indigo night background. The creature must be frightening and dangerous, never cute, goofy, cartoonish or surprised: no round eyes, no white of the eye, no button nose, no smile, no grin. It must read as a tiny thumbnail: a strong clear silhouette, the face built from big bone-white paper planes against the dark, eyes and fangs bold and legible. No gore, no blood, no text, no letters.
```

#### prompts/e2.txt (call e2)

```text
A werewolf as a silhouette against a huge full moon. The background is a large plain bone-white paper full moon, centred, its disc filling most of the card's width, from near the top down to below the middle. In front of the moon, centred, the head and hunched shoulders of a werewolf cut entirely from near-black indigo paper, so the whole head sits INSIDE the bright disc of the moon and its outline is sharp against the bone white: a three-quarter view with the long wolf muzzle pointing to the left, tall pointed ears laid slightly back, rough jagged fur along the neck in torn paper spikes, the hunched shoulders running off the bottom of the card. The silhouette has no face detail at all except two things: two narrow slanted glowing amber eyes with slit pupils, and a snarling row of long bone-white fang triangles in the slightly open jaw. Everything else is dark shape against the bright moon. Stark, graphic, menacing. A few bare cut-paper branches at the bottom corners.
Style: match the two reference images exactly in hand and finish: a character portrait made entirely of layered cut and torn paper collage, photographed straight on under soft light. Flat shapes of matte coloured paper with sharp scissor-cut and torn edges, stacked in layers with soft real cast shadows between them, visible paper fibre grain everywhere. No outlines, no ink lines, no airbrush gradients, nothing glossy, nothing photographic, not a 3D render. Palette only: deep midnight indigo (near black-blue) and dusty slate indigo, bone white, dried-blood red used sparingly in one or two small places, and at most a small touch of lantern amber. Framing like the references: one figure, head and shoulders, the head large in the upper middle of a portrait 3:4 card, the shoulders reaching the bottom edge, a simple dark indigo night background. The creature must be frightening and dangerous, never cute, goofy, cartoonish or surprised: no round eyes, no white of the eye, no button nose, no smile, no grin. It must read as a tiny thumbnail: a strong clear silhouette, the face built from big bone-white paper planes against the dark, eyes and fangs bold and legible. No gore, no blood, no text, no letters.
```

#### prompts/a3.txt (call a3)

```text
A werewolf about to spring. Composition: the wolf head is LARGE, its centre near the middle of the card; the two hunched shoulders, cut from near-black indigo paper with jagged torn fur spikes, rise high on both sides so the head hangs low BETWEEN them, below the shoulder line. The whole face and long muzzle are cut from bright bone-white paper in big sharp angular planes, so the face stands out strongly against the dark shoulders and the dark background. Low three-quarter view, the muzzle angled toward the lower left. The eyes look UP at the viewer from under a heavy dark brow: narrow slanted wolf eyes, pale amber with tiny black slit pupils, a hard dark shadow cut above them. The upper lip curled back in a snarl, the nose wrinkled into hard cut ridges; long sharp fangs cut as clean bone-white paper triangles, top and bottom, set in a dark mouth with a small patch of dried-blood red gum. Ears pinned flat back. Asymmetric, tense, coiled, predatory. A few small cut-paper bare trees in the dark background.
Style: match the two reference images exactly in hand and finish: a character portrait made entirely of layered cut and torn paper collage, photographed straight on under soft light. Flat shapes of matte coloured paper with sharp scissor-cut and torn edges, stacked in layers with soft real cast shadows between them, visible paper fibre grain everywhere. No outlines, no ink lines, no airbrush gradients, nothing glossy, nothing photographic, not a 3D render. Palette only: deep midnight indigo (near black-blue) and dusty slate indigo, bone white, dried-blood red used sparingly in one or two small places, and at most a small touch of lantern amber. Framing like the references: one figure, head and shoulders, the head large in the upper middle of a portrait 3:4 card, the shoulders reaching the bottom edge, a simple dark indigo night background. The creature must be frightening and dangerous, never cute, goofy, cartoonish or surprised: no round eyes, no white of the eye, no button nose, no smile, no grin. It must read as a tiny thumbnail: a strong clear silhouette, the face built from big bone-white paper planes against the dark, eyes and fangs bold and legible. No gore, no blood, no text, no letters.
```
## Werewolf redraw: notes

### Why the current one reads dopey

- Passport-photo pose: dead frontal, perfectly symmetric, head upright and level, centred under a halo-like moon
  with rays. Nothing leans, coils or threatens; it reads as a saint's icon.
- Human eyes: round-ish with white sclera and small dark pupils under heavy cartoon brows: a grumpy man, not a
  predator. The brows meet in a frown that reads as sulking.
- Short dog muzzle with a round button nose sitting low, on a human-proportioned bone face: a man in a wolf mask.
- Mouth: a wide open, square gape with many small even teeth and the corners turned up: a yawn or a goofy
  grin, not a snarl. No curled lip, no wrinkled nose.
- Silhouette: an anime fringe of hair, human ears below the wolf ears, a bathrobe-like wrap at the shoulders:
  costume, not creature.

The fix in every candidate: narrow slanted slit-pupil eyes with no white, a long wolf muzzle, curled lip or a
shut hard jaw, head off the level (lowered, tilted or turned), asymmetry, no halo.

### Candidates (werewolf-a.jpg ... werewolf-e.jpg)

- A: head hung low between dark hunched shoulders, bone-white face, V brow, snarl. Danger: the coiled spring.
- B: still, straight-on, mouth shut, two lower fangs, torn ear, a red scar. Danger: restraint, it is watching you.
- C: mid-lunge, jaws wide, claw reaching out of the corner, paper shards flying. Danger: it is coming now.
- D: the turning: wolf muzzle bursting from a gaunt human face, claw hand, torn collar. Danger: horror of the change.
- E: black silhouette inside a bone moon, only amber eyes and fangs lit. Danger: the shape in the night. Reads best at 56 px.

Dropped: a1 and a2 (dark fur blobs at 56 px; a2's pose is the best of all and could be redone if wanted), e1
(the head below the moon, dark on dark).

### Pick: C

Clearly a werewolf and clearly attacking, at full size and at 56 px (bone face, open jaws, claw), with motion
and asymmetry the siblings lack, so it is the strongest answer to "not dangerous". Red is the tongue and a
few scraps only. Runner-up: E (the cleanest chip of all, but less of the face). Note: C and D use more red
than B, A or E; if red must stay to a touch, B or E.
