# Design handoff: Shadow paper

Everything needed to rebuild the app's screens in the chosen look. Read
`../specs/frontend/design-brief.md` first; it holds the decisions. This folder holds the
pictures.

## What is here

`mock-to-skin.md` maps every element of every mock to the primitive and the skin roles that draw it. `app-icon.md`: the app icon, launch screen and web icons, cut from this art. `feel.md`: how the game moves and feels (motion tokens, vibration, and every micro-interaction, one row each); polish passes build from it.

| Folder | What |
|---|---|
| `mocks/*.png` | The 11 screens (plus `03b`, the role sheet) at 390x844. These are the target. |
| `mocks/*.dc.html` | The mock markup. Every size, colour, radius, shadow and font size is an inline style, so read these for exact values. Image `src` values (`/_blob/...`) only resolve inside the mock canvas; use the files in `art/` instead. |
| `art/roles/` | 12 role portraits, 576x768, one per role, file named after the role. |
| `art/tokens/` | 10 player tokens (crow, key, moth, bell, thorn, antler, hare, lantern, spindle, scythe), 320x320, to be shown in a circle: one per seat at a table of 10. |
| `art/scenes/` | Candle, table, street door, sleeping village (flat pictures). |
| `art/card-backs/` | The five card backs (moon, window, teeth, eye, quilt), 1200x1600; one is drawn for a whole game. `PROVENANCE.md` says how each was made. |
| `art/layers/` | The two headers that move, drawn in layers (cuts of paper with alpha, PNG masters): `night-village/` (04: the plate, the moon, the clouds and their shadows) and `dawn-gallows/` (08: the sky, the sun, the hills, the birds, the roofs, the gallows). `flat.jpg` in each is the picture the layers were cut from. `PROVENANCE.md` says where every piece came from and how far each may move. |

The mock canvas, where the product owner comments: https://claude.ai/artifact/AQ2LuLA5KkRPXHiZoGb6j9
(page "Round 4"). The product owner's verdict on these mocks: "close enough"; build them and
iterate on the real app.

## How art gets in

Originals live here, under `docs/design/art/`; the app ships phone-sized WebP made from them by
`frontend/tool/skin_art.py` (`just skin-art`, from `frontend/`; deterministic), into
`frontend/assets/skins/shadow_paper/{roles,tokens,scenes,layers/<scene>}/`. Flutter's asset folders are not
recursive: a new folder is a new line under `flutter: assets:` in `pubspec.yaml`. The skin names every
picture and its size (`ArtSet`: the `Scene` enum and `scenePixels` for a flat picture, `sceneFocus` for the point of it
kept in view; `skin_contract_test.dart` decodes each file and fails on a size that is wrong or a file nothing declares).

A header that moves is a `LayeredScene` in the skin (`shadow_paper.dart`: `_nightVillage`, `_dawnGallows`): the canvas it was
cut from, its focus, and its layers bottom to top, each a file with its size, its anchor on the canvas, and where it
starts from when a scene brings the screen in (`from`); a shadow cast on another layer says `clipTo`; a place the screen
draws itself (08's sun and its dotted path) is a `SceneSlot`. `just skin-art` cuts each master to the box it
paints and prints the size and anchor to declare; `layered_scene_test.dart` draws the layers at rest and holds them to
`flat.jpg`. A layer that slides carries mirrored paper beyond the canvas (`*_bleedNN`). Nothing ships that nothing draws:
a flat picture or a layer no skin uses is removed, with its master.

## Status of each screen

`01-join`, `04-your-card` and `11-results` were approved earlier. The other eight were revised
after one round of feedback (19 November 2026) and then accepted as close enough.

## How the art was made

Generated, then meant to be tidied by one illustrator later. Style prompt for portraits:

> Cut-paper shadow theatre illustration for a folk horror tale, layered cut paper with sharp
> angular edges and deep hard shadows between layers, visible paper grain, restricted palette
> of midnight indigo, bone white, dried-blood red and a little lantern amber, elongated severe
> faces with narrow eyes and no smile, eerie and tense, not cute, not childlike, centered
> portrait bust of <subject>, no text, no letters, no border

Tokens: "Cut-paper emblem for a folk horror tale, a single round medallion token filling the
frame, ... bone white paper silhouette of <thing> on a midnight indigo paper disc with a thin
dried-blood red rim, flat frontal view, centered, plain dark indigo background outside the
disc, no text, no letters". Avoid emblems that read as religious or national symbols.

All art is original to this app. Do not copy the published game's card art.
