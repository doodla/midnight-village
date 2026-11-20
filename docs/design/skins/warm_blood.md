# Warm blood

The third skin (`SkinId.warmBlood`, `frontend/lib/design_system/skin/skins/warm_blood.dart`). The
village seen by heat, the way a hunter's scope finds a warm body in the dark. It has no mock: it
is a skin on the same eleven screens, and changes only art, colour, type and shape.

## What it is going for

Shadow paper and Night print are both paper: cut and printed, indigo with a pale sheet and a red.
A third paper look would have been the obvious next one, so this one takes its method from the
game instead. Everyone at the table closes their eyes and something warm-blooded is hunted in the
dark; a heat camera is the thing that sees that. The method then decides the rest:

- **Colour is temperature.** One heat scale, cold violet to white-hot, is the whole palette. The
  night is its cold end and the day its hot end, so the phase reads from across the table as
  dark violet against sodium yellow.
- **Warm colour is kept for what is alive.** The frame (plates, text, rules) is cold white and
  violet. Heat shows in the pictures, in the steps things cast, in danger, and in the one thing
  to press: at night the primary button is the hottest thing on the screen and nothing else is
  yellow; by day, when everything is hot, it is the one cold thing.
- **An instrument sets things straight.** Nothing is tilted. Type is tall, narrow and plain.

## Palette

The heat scale, cold to hot (the only twelve colours a picture has; `tool/thermal_art.py`):

`#0E0920` `#1B1040` `#34186B` `#5C1F8C` `#8F2390` `#BC2A7C` `#DE3B5A` `#F25C33` `#FA8A26`
`#FDB933` `#FFD23F` `#FFF3B8`

| Role | Night | Day | Paper (inside a plate) |
|---|---|---|---|
| Ground | Cold `#0E0920` | Hot `#FFD23F` | Frost `#F1EEF6` |
| Text | Frost `#F1EEF6` | Cold `#0E0920` | Cold `#0E0920` |
| Quiet / faint text | `#B7AFD4` / `#9A91BC` | `#3D2C63` / `#4F3D78` | `#5A4F7A` |
| Well, rule | `#1A1136`, `#3A2C66` | `#F3BC2C`, `#C9971A` | `#E2DDED`, `#C9C2DC` |
| Primary button | Hot `#FFD23F`, cold label | Cold `#0E0920`, hot label | Cold `#0E0920`, frost label |
| Its steps | Orange `#FA8A26`, magenta `#BC2A7C` | Ember `#F25C33`, wolf `#B5174F` | Ember, wolf |
| Selection (outline, name) | Orange `#FA8A26` | `#9C1244` | Wolf `#B5174F` |
| Step under plates | Violet `#4A2B9A` (then `#2A1760`) | Orange `#F2811D` | `#C9C2DC` |
| Marks and count badges | Frost | Frost (the sun is white-hot) | Cold |
| Danger, Werewolf, your pick | Wolf `#B5174F` with frost words; red words `#FF7FA3`, lines `#F0457A` | Wolf; red words `#9C1244` | Wolf |

Plates (paper) are frost `#F1EEF6` on every ground. Every text pair passes WCAG AA; the contrast
test measures them on the painted pixels.

## Type

- **Big Shoulders Display ExtraBold** (800) for everything set large: titles, names, button
  labels, timers. Tall and narrow, so headings sit at the top of the brief's ranges, the hero
  lines near the top of theirs, and a long name still fits its row on a 320 phone.
- **Barlow** Medium and Bold (500, 700) for reading text. A little narrow too, which leaves room
  to keep reading text at 16 px and above and captions, tags and badges at 14 px and above. Only
  the two labels set in capitals are smaller (12 px, as the brief's scale fixes it, and 11 px
  for the field names in the row of four pace tiles, so the longest is whole on a 360 phone).

Both are SIL Open Font License faces from Google Fonts, bundled as Latin and Latin Extended
subsets under `frontend/assets/fonts/{bigshouldersdisplay,barlow}/` with their `OFL.txt`, loaded
only when the skin is chosen, and listed on the app's licences page. Three files, 183 KB.

## Shape

- Rounded plates (radius 10; 6 and 4 for the small things; 16 on a sheet) with a 2 px cold line.
- Tokens sit on rounded tiles (roundness 0.35), between Shadow paper's discs and Night print's
  squares; a row's leading end is rounded to match.
- Shadows are isotherm steps: hard copies offset down and to the right, each a step colder (at
  night) or hotter (by day) than the ground. The primary button casts two steps and the one card
  a screen is about casts three; rows and chips cast one. No blur anywhere.
- No tilt. Progress pips are small squares, like sensor cells.

## Art

Shadow paper's originals (`docs/design/art/`) filmed by `frontend/tool/thermal_art.py`
(`just skin-art warm_blood`), deterministic from a fixed seed, PIL and numpy only:

1. A pixel's heat is its lightness plus how much redder it is than blue, so bone paper (a face)
   is warm, flame and lantern light hotter, and indigo paper cold.
2. The heat is read between two fixed levels, the same for every picture of a kind, softened by
   the lens, averaged into square sensor cells (4 px for portraits and scenes, 3 px for tokens,
   2 px for the card back), and given a little sensor noise.
3. Each cell is painted one of the scale's twelve colours. Nothing sits between two steps, so the
   isotherms show.

Per kind: portraits keep faces at orange and let only flame reach white-hot; night scenes count
lightness for less, so moonlit walls stay lukewarm and only a lit window or a lantern is hot;
the two dawns are day pictures with a hot sky; the card back uses the finest cells and only the
lukewarm half of the scale, so a table of face-down cards glows without shouting, with the eye
as its hot spot; tokens are an orange emblem on a flat cold tile, the round rim painted out as
in Night print. Per picture: the Hunter's grey face is warmed to match the others, and the
Werewolf runs a step hotter than the people.

The frames are stored as lossless WebP (flat colours in square cells compress well and lossy
coding would smear them): 30 pictures, 284 KB.

## Where it came from, and licences

The product owner asked for a look built from https://github.com/mankidev/antialgorithm (MIT
licence). What was taken from it is an idea, not a file: name the look you would reach for first,
then move away from it for a reason found in the project itself, and let the chosen method's own
marks carry the state. **Nothing from that repository is copied into this project**: no image,
font, code or text. The art is derived from this project's own originals, and the fonts are the
OFL faces named above.
