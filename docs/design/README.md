# Design handoff: Shadow paper

Everything needed to rebuild the app's screens in the chosen look. Read
`../specs/frontend/design-brief.md` first; it holds the decisions. This folder holds the
pictures.

## What is here

`mock-to-skin.md` maps every element of every mock to the primitive and the skin roles that draw it.

| Folder | What |
|---|---|
| `mocks/*.png` | The 11 screens (plus `03b`, the role sheet) at 390x844. These are the target. |
| `mocks/*.dc.html` | The mock markup. Every size, colour, radius, shadow and font size is an inline style, so read these for exact values. Image `src` values (`/_blob/...`) only resolve inside the mock canvas; use the files in `art/` instead. |
| `art/roles/` | 12 role portraits, 576x768, one per role, file named after the role. |
| `art/tokens/` | 10 player tokens (crow, key, moth, bell, thorn, antler, hare, lantern, spindle, scythe), 320x320, to be shown in a circle: one per seat at a table of 10. |
| `art/scenes/` | Card back, candle, table, street door, sleeping village, night village, dawn rooftops, dawn gallows. |

The mock canvas, where the product owner comments: https://claude.ai/artifact/AQ2LuLA5KkRPXHiZoGb6j9
(page "Round 4"). The product owner's verdict on these mocks: "close enough"; build them and
iterate on the real app.

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
