# Mock to skin

Every element of every mock (`mocks/S*.dc.html`; S11 from `mocks/11-results.png`, which has no
markup), mapped to the primitive that draws it and the roles it reads, so a screen builder needs
no literal size, colour, font or radius. Each mock is rebuilt this way in
`frontend/test/helpers/component_sheet.dart` (pages `join` to `results`); `just screens` puts each
next to its mock, and the contrast and fit tests measure them.

**The first-time play spec (`docs/specs/frontend/first-time-play.md`) wins over the mocks.** Rows
it changed say so: its copy (every word is in `lib/design_system/copy/copy.dart`), the amber rule
(one amber fill per screen, the primary button, ink-edged by day; a selection is lift plus an
outline, never amber or a fill), the reading floor (16 px to act, 14 px captions, no uppercase
tracked labels: the `label` and `micro` roles and `SectionLabel` are gone), plain progress pips,
the held face (`HeldFace`: every secret in one frame, a similar size, the whole role card
with its portrait in colour), the one night board (`NightBoard`, reading the server's prompt
as `PickRule`) and section 7: 07 is gone, its faces are My night's pages on 08. The component sheet's pages are rebuilt to the spec, not to the mock.

How to read the tables:

- **Type** names a `SkinType` role (`context.skin.typography.<role>`), **colour** a `Ground`
  role on the element's ground (`context.ground.<role>`), **space** a `Space` constant
  (`frontend/lib/design_system/layout/space.dart`). Spacing and motion are the same in every
  skin; art, colour, type and shape come from the skin.
- **Snap**: where the mock uses an odd value, the nearest step is used and the row says so
  (e.g. a 5 px gap is `Space.xs`, 6). These are 1 to 2 px.
- A primitive's own geometry (a row's height, a badge's offset) lives in the primitive as a
  named size; the row says which.

Common to all screens: the screen is a `ScreenFrame(ground: ...)`; side margins are
`Space.gutter` (24); the pinned actions sit `Space.screenBottom` (28) above the bottom, with
`actionGap` between them (default `Space.mdPlus`, 14; S04 `Space.lg`, S06 `Space.md`); a screen
with no top picture or band starts `Space.screenTop` (40) down, plus the status bar.

## S01 Join (night)

| Element | Primitive / role |
|---|---|
| Street-door picture, 330 tall, focus 50% 12%, fading from 160 | `ScreenFrame(topArt: skin.art.streetDoor, topArtLayout: TopArtLayout.scene)`; focus from `ArtSet.sceneFocus` |
| "Midnight Village" 46, -0.02em | `FitLine` in `type.heroTitle` (hero line) |
| Subtitle 16/500 quiet | `type.lede`, `ground.quietText`; gap `Space.xs` |
| Column gaps 18 | `Space.lgPlus` |
| "Your name" label 13/700 +0.12em | **Cut** by the first-time play spec (no labels; the field's hint "Your name" says it) |
| Name field: paper, 56 tall, radius 6, 4,4 shadow, Gloock 26 | `SkinField.paper` (`ground.paper`, `elevation.raised`, `type.title`) |
| "Start a table" 60 tall, 21 px, 6,6 shadow | `PrimaryButton(size: ButtonSize.large)` |
| Gap 14 between the button and the code row | `Space.mdPlus` |
| Code field: 52 tall, 2 px outline in quiet, 17/700 +0.12em | `SkinField.code` (`ground.outline`, `shape.stroke`, `type.code`) |
| "Join": paper, 104 x 52, Gloock 19, 4,4 shadow | `SecondaryButton.paper` (`ButtonSize.compact`: min 104 wide, 52 tall, `type.buttonLabelSmall`, `elevation.raised`) |
| Row gap 10 | `Space.smPlus` |
| Footer rule 2 px hairline, padding-top 14 | `Divider(height: Space.mdPlus)` (theme: `ground.hairline`, `shape.stroke`), in `actions` |
| Footer lines 14/600 quiet, gap 6 | `type.lede` (16: body text a player reads, copy rule 7), `ground.text`, `Space.xs` |

## S02 The table (night)

| Element | Primitive / role |
|---|---|
| Table picture, 180 tall, focus 50% 55%, fading from 80 | `ScreenFrame(topArt: skin.art.table, topArtLayout: TopArtLayout.banner)` |
| Code panel: paper, padding 12/16, slab shadow (0 5 paperEdge, 0 10 deep) | `PaperCard(lift: PaperLift.slab, padding: Space.md / Space.lg)` |
| "Table code" 12/700 +0.14em, paper quiet | **Cut** by the first-time play spec ("Table code"); the code is printed under the QR, in `type.code` |
| "K7QX4M" 46, +0.08em | `FitLine` in `type.heroCode` (hero line) |
| "At the table · 5 players" | **Cut** by the first-time play spec ("At the table", "5 players") |
| Player row: 52 tall, radius 26/6, padding 0 12 0 8, gap 12, 3,3 shadow, Gloock 21 | `PlayerRow(size: PlayerRowSize.compact)` (`type.name`, `elevation.card`, `shape.rowLeadRoundness`) |
| Token 38, ring 2 indigo | `PlayerToken` at `TokenSize.row`; ring `shape.ring` in the row's ink |
| "Host · you" 12/700 +0.14em paper quiet | **Cut** by the first-time play spec ("Host · You"); your own row is `PlayerRow(own: true)`, a thicker ink outline |
| Deck link: outline 2 px hairline, padding 10/12, radius 6 | `OutlinePanel(onTap: ...)` |
| Thumbnails 30 x 40, radius 4, ring 2 bone, gap 7 | `RoleCard(size: RoleCardSize.thumbSmall)` (`shape.radiusSmall`, ring `ground.text`); gap `Space.sm` (snap 7) |
| "×2" badge 20, 12/700, at -6/-6 | `CountBadge(2)` ("2", not "×2"; `BadgeSize.small`, `type.badge` 14, `ground.mark`/`onMark`: bone on night, ink by day), placed by `RoleCard` |
| "8 cards" / "Change" 13/700 lh 1.3, "Change" amber | **Cut** by the first-time play spec ("8 cards", "Change"); the strip's quiet "Edit" in `type.action` |
| "Deal the cards" 56 tall, 20 px, 5,5 | `PrimaryButton` (`ButtonSize.regular`) |

## S03 Build the deck (night)

| Element | Primitive / role |
|---|---|
| "Tonight's deck" 32 | `FitLine` in `type.headline` |
| "8 of 8 cards" chip: paper, padding 6/10, radius 4, 14/700, check icon 16 | **Cut** by the first-time play spec ("8 of 8 cards") |
| Header gap 12, column gap 14 | `Space.md`, `Space.mdPlus` |
| Presets: 44 tall, padding 0 14, radius 4, selected paper / others 2 px quiet outline, 14/700 | `PresetChip` (`type.action` 16; the selected one lifts and takes `ground.selection` at `shape.selectedRing`, never a fill); gap `Space.sm` |
| Grid: 4 columns, gaps 14/12, margin-top 4 | `GridView` with `Space.mdPlus` / `Space.md`, `Space.xxs` |
| Role card: portrait 100 tall, radius 5, ring 3 amber when in the deck, 2 hairline and 0.4 opacity when not | `RoleCard` (`RoleCardSize.small`; three columns, so the names stay at 14): `shape.radius`, lit `ground.selection`/`shape.selectedRing` (bone, not amber), `ground.hairline`/`shape.ring`, `skin.dimmed` |
| Count badge 24, 14/700, at -5/-7, 0 2 shadow | `CountBadge(n, size: BadgeSize.large)` (`type.badge`, `elevation.badge`), shown above 1, placed by `RoleCard` |
| Name under the card 12/700, gap 5, dimmed names #8a90b4 | `type.badge`, `ground.text` / `ground.faintText`; gap fixed in `RoleCard` |
| Hint 13/600 quiet | `type.caption`, `ground.quietText` |
| "Pace" label | **Cut** by the first-time play spec ("Pace"); the pace chips "Quick", "Normal", "Long" are `PresetChip`s |
| Pace tiles: 4 across, gap 8, padding 9/10, 2 px hairline, radius 6; label 11/700 +0.1em quiet; value Gloock 24 | `PaceTile` (its name in `type.caption` 14, sentence case; `type.heading`, `ground.hairline`) in a `Row` of `Expanded`, `Space.sm` |
| "Use this deck" | `PrimaryButton` |

## S03b Role sheet (over S03)

| Element | Primitive / role |
|---|---|
| Scrim rgba(7,9,26,0.72) | `skin.scrim` (`showSkinSheet` sets it) |
| Sheet: paper, radius 14 top, padding 18/24/28, amber edge 6 px | `SheetScaffold` via `showSkinSheet` (`ground.paper`, `shape.sheetRadius`, the covered ground's `selection`; `Space.lgPlus`, `Space.gutter`, `Space.screenBottom`) |
| Portrait 132 x 176, radius 4, ring 2 indigo, 5,5 blood shadow | `RolePortrait(width: RolePortrait.sheet, framed: true)` (paper `elevation.heroSlab`, ring `ground.text`) |
| "Village team" tag: padding 5/10, radius 3, 12/700 | `TagChip('Village team', small: true)` (`type.badge`, `shape.radiusTiny`) |
| "Troublemaker" 32 | `FitLine` in `type.headline` (set smaller rather than broken; the mock hyphenates) |
| "Acts at night" | **Cut** by the first-time play spec ("Acts at night") |
| Paragraph 17/500 lh 1.4 | `type.bodyLarge` (lh 1.35) |
| Info box: #dcd4bf, padding 12/14, radius 6, 14/600, bold words in indigo | **Cut** by the first-time play spec: the role text's "Night:", "Wins:" and shared lines, in `type.bodyLarge` (`RoleSheetBody`) |
| Gaps 16, 8 | `Space.lg`, `Space.sm` |
| "Take out of deck": 52 tall, 2 px indigo outline, 15/700 | `SecondaryButton(size: ButtonSize.compact)` in `Expanded` |
| "Close": 104 x 52, indigo, Gloock 19, 4,4 blood | `PrimaryButton(size: ButtonSize.compact)` (paper's `accent`, `elevation.primary` x0.8) |
| Button gap 10 | fixed in `SheetScaffold` (`Space.smPlus`) |

## S04 Your card (night)

| Element | Primitive / role |
|---|---|
| Night-village picture 520 tall, focus 50% 0%, fading from 300; content from 52 | `ScreenFrame(topArt: skin.art.nightVillage, topArtLayout: TopArtLayout.backdrop)` |
| Pill: 36 tall, padding 0 16, radius 4, 14/700, 0 3 shadow, moon icon | **Cut** by the first-time play spec ("Night one · your card"); the headline "Your card" in `type.screenTitle`, set left, clear of the moon in the picture |
| Column gap 18, centred | `Space.lgPlus` |
| Card: 310 wide, padding 12/12/20, gap 12, heroSlab (0 5 paperEdge, 0 11 amber, 0 17 deep) | Your card is face down: `FaceDownCard(size: FaceDownSize.hero, hold: teaching)` under a `TeachingHold`; the role text is its held face (`HeldFace`). The amber layer of `heroSlab` is cut (amber is the primary button's alone) |
| Portrait 318 tall, radius 3, inset ring 2 px at 12%, focus 50% 12% | On the held face: `HeldFace` draws the portrait in colour beside the name and tag (`shape.radiusSmall`, `ArtSet.portraitFocus`) |
| "Seer" 58, -0.02em, lh 0.9 | **Cut** by the first-time play spec: the role name is on the held face, in `type.heading` (`heroRole` is gone) |
| "Village team" tag padding 7/12, 13/700 | `TagChip` (regular: `type.tag`; padding `Space.xs`/`Space.smPlus`, snap) |
| Description 17/500 lh 1.35, padding 0 8 | `type.bodyLarge`, `Space.sm` |
| Status dot 12 amber with a 5 px 25% halo | **Cut** by the first-time play spec ("Holding…") |
| "Holding..." 15/600, gap 10, margin-top 22 | `type.body`, `Space.smPlus`; margin `Space.xxs` + the column's `Space.lgPlus` |
| "I know my card": 60 tall, 21 px, 6,6 | `PrimaryButton(size: ButtonSize.large)` |
| Pips: 12 dots, gap 8, bone / hairline, label 14/600 at margin 6 | `ProgressPips(done:, total:, label: "{d} of {n}", centred: true)` (`shape.pip`, `ground.text`/`hairline`, `type.body` 16, `Space.xs`) |
| Gap 16 between button and pips | `actionGap: Space.lg` |

## S05 Night, waiting (night)

| Element | Primitive / role |
|---|---|
| Sleeping-village picture 330, focus 50% 0%, fading from 200; title at 286 | `ScreenFrame(topArt: skin.art.sleepingVillage)` (`TopArtLayout.scene`; snap: fade from 160, body from 282) |
| "The village sleeps" 34, lh 1.05, centred | `type.screenTitle` |
| Candle panel: #1d2145, 2 px hairline ring, radius 6, padding 10/22/10/10, gap 16 | `WorldTimer.candle` (`ground.panel`, `ground.hairline`, `shape.ring`, `shape.radius`) |
| Candle 66 x 88, radius 4, focus 50% 62% | inside it (`WorldTimer.candleSize`, `shape.radiusSmall`, `ArtSet.sceneFocus`); shrinks on a narrow phone |
| "19" 64 lh 1 | `type.timerSmall` |
| "seconds / of night" 12/700 +0.14em lh 1.4 | **Cut** by the first-time play spec ("seconds of night"): the digits stand alone |
| Three cards 84 x 112, radius 6, 0 4 deep + 2 hairline ring, rotated -4 / 1 / 5 deg, gap 18 | `FaceDownCard(size: FaceDownSize.scatter, tilt: Tilt.scatter(i))` (`elevation.lying`, `SkinTilt.scatter`); not on 05 any more (05 is only the title and the candle) |
| "Tap the cards while you wait" 15/600 quiet | **Cut** by the first-time play spec (05 is only the title and the candle) |
| Waiting token 26 at 0.35 with a quiet ring | **Cut** by the first-time play spec (no names in progress); a dropped member's token on 02 is `PlayerToken(away: true)` at `skin.dimmed` |
| "Waiting for Dev to reconnect" 14/600 quiet, gap 10 | **Cut** by the first-time play spec ("Waiting for Dev to reconnect"); this phone's banner "One moment" |

## S06 Night, your action (night)

| Element | Primitive / role |
|---|---|
| Role thumbnail 44 x 58, radius 4, ring 2 bone | **Cut** by the first-time play spec (the role thumbnail and "Your turn": the board looks the same on every phone) |
| "Your turn" 12/700 +0.14em quiet | **Cut** by the first-time play spec ("Your turn") |
| "Seer" Gloock 26 lh 1.1 | **Cut**: the board's headline is "The village sleeps" on every phone (`type.screenTitle`, `FitWords`); the role is on the held face of "You" |
| Header gap 10 | `Space.smPlus` |
| Corner timer: candle 44 x 58 with hairline ring, gap 10, "14" 34 lh 1, "s" 13/700 quiet at 3 | `WorldTimer.candleCompact` (`compactCandleSize`, `type.timerCompact`), set as one unit `NightBoard.timerLines` (1.3) title lines high; the "s" is cut. Beside it the title on one line (`FitWords(maxLines: 1)`, set smaller only where it must); the board's words grow with the text size to `NightBoard.labelScale` (1.3) |
| Prompt 26 lh 1.15, margin-top 4 | **Cut**: what this phone may do is on the held face of "You" (the `hold` ring is on it only on a device that has never held a face) |
| Player cards 78 x 106, radius 6, ring 2 hairline, 0 4 deep; margin-top 14 | `FaceDownCard(owner:, ownerName:)` (`elevation.lying`), placed by `BoardLayout`: balanced rows, never one card alone on a row, the largest cards that keep every name at its floor and every row on screen, up to `FaceDownSize.board`; columns as wide as a card and `Space.lg`, or the widest name; `Space.sm` between columns, `Space.lg` between rows |
| Picked card: ring 3 amber, 0 8 deep, up 8 | `selected: true`: lifts `Space.sm` and takes `ground.selection` (bone) at `shape.selectedRing`; never amber or a fill |
| Mark disc 40 amber at top 38, eye icon 26, 0 2 deep | **Cut** by the first-time play spec: the mark said what a pick would do, which tells the role |
| Owner token 36 overlapping by 18, ring bone (amber when picked) | `TokenSize.card`, placed by `FaceDownCard`; smaller on a small card (`ownerTokenShare` of its width) |
| Name Gloock 18 at 4, amber when picked | `type.nameSmall`, `ground.text` (the name does not change when picked); every name on the board at one size, the largest that fits every column (on two lines between words where it must; never below 14 px drawn while a split allows it), never cut |
| (not in the mock) the viewer's own card | **Added**: not among the seats but in front of them, at the left of the band above the button: `FaceDownCard(owner:, ownerName: "You")` on a `PaperCard` (paper ground: ink name, ink ring when picked), one size with the table's cards (`BoardLayout.bandCard`); its first-game cue is `HoldCue`, a plain ring with "Hold" in it that breathes and fills while held (no thumbprint) |
| Rule 2 px hairline, margin-top 6, padding-top 14 | A strip of the table instead, beside "You" in the band: `ground.panel`, `shape.radius`, `Space.md` above and below, `Space.sm` beside; `Space.xl` under the seats, with what is to spare split half above the seats and half above the band; the board never scrolls (`ScreenFrame(fitsHeight: true)`) |
| "Center" centred label | Back (issue 37: the titles say "center cards", so the word is on the board): a `caption` line in full ink at the top of the strip, `NightCopy.centerLabel`, the place leaving the same room above its card so the four cards sit level; Left, Middle and Right follow the players on the same board |
| Center cards 62 x 84, radius 5, 0 3 deep, 0.75 opacity, gap 22 | `FaceDownCard(caption:, tilt: Tilt.scatter(i))` at the band's size (`BoardLayout.bandCard`, at most a seat's), dropped at S05's slants, `Space.sm` apart on the strip; no opacity (the captions keep their contrast) |
| "Left / Middle / Right" 12/700 quiet, gap 6 | `caption:` (`type.caption` 14, `ground.quietText`) |
| "Look at Cleo's card" 56 | `PrimaryButton`: "Choose a card" and "Choose 1 more" `.locked` (a tap replays the wave), then what will happen ("See {cards}", "Swap with {cards}", "Copy {cards}") or the role's pass ("Skip", "Keep my card", "Choose for me"), then `.done` "Chosen"; a send that gets no answer adds `Notice` "Not sent." with "Try again" (a `409` is done, not a failure; any other `4xx` arms the board again); a phone whose turn the server already has (`chosen`) opens at "Chosen" |
| "Do nothing tonight" 48, 2 px quiet outline, 15/700 | **Cut** by the first-time play spec: doing nothing is picking "You" (the role's pass: "Skip", "Keep my card", "Choose for me") |
| Gap 12 | `actionGap: Space.md` |

## S07 Night, what you saw (night)

**Removed** by the first-time play spec (section 7): there is no 07 screen. Its card and hold are
08's My night (`PeekBox` under a `TeachingHold`), and each result is a page of My night's
`HeldFace`. The rows below say where each element went.

| Element | Primitive / role |
|---|---|
| "You looked at" centred | **Cut** ("You looked at"), and 07 with it |
| Token 44 + "Cleo's card" 36 lh 1, gap 12 | **Cut** by the first-time play spec (the target's token and name: they are on the held face) |
| Card: 270 x 362, padding 10, paper, heroSlab | On 04: `FaceDownCard(size: FaceDownSize.hero)` (`ground.paper`, `elevation.heroSlab`; back at `shape.radiusTiny`) |
| Hold disc 132, night at 86%, ring 3 amber, icon 34 amber, "Hold to flip" 15/700 | `FaceDownCard(hold: teaching)`: `HoldCue`, a plain bone ring on the night at 86% with "Hold" (`type.cue`, 20) in it, breathing, that fills while held, until this device has learned the hold; then nothing (the thumbprint is cut: product owner, 20 November 2026) |
| Press and hold to turn it over | `HoldToReveal(cover:, face: FaceContent)`: the face is a `HeldFace` drawn above the touch point, for as long as it is held |
| "Done" | **Cut** with 07 (its 4 s gate was an added wait) |
| Token pips 26, done ring bone, waiting 0.35 quiet ring; "2 of 5 done" 14/700 | `ProgressPips` is plain on every screen (copy rule 8); 07 has none |

## S08 Talk (day)

| Element | Primitive / role |
|---|---|
| Sky 250 tall, full bleed, gallows picture focus 50% 40%, night behind | `ScreenFrame(topSlot: TimerBand.sun(...))` (`TimerBand.skyHeight`, `skin.art.dawnGallows`) |
| Dotted arc 2 px at 55%, sun r19 amber with a 3 px indigo stroke | painted by `TimerBand.sun` (`ground.text`; the pale sun in `night.text`, not amber; `shape.ring`, `shape.selectedRing`) |
| 70 px fade into the day | `TimerBand.sun` (the last 28% of the sky) |
| "4:12" 84 lh 0.9 -0.02em, margin-top -8; "left to talk" 12/700 quiet, gap 12, baseline | `type.timer`; "left to talk" is **Cut** by the first-time play spec; in its place beside the number, the headline "The village wakes" (`TimerBand.sun(title:)`, `type.screenTitle`, two lines at most; under the number where the two do not fit side by side) |
| Sun's place on the arc | the share of the talk left from the server's `stage_started_at` and `deadline` (`StageShare`); without `stage_started_at`, the sun rests at `TimerBand.restingSun` |
| "My night" box: night ground on day, padding 10/16/10/10, gap 14, radius 6, 4,4 day shadow | `PeekBox(title:, teaching:, large: true)` (`night.ground`, day `elevation.raised`; large: a 76 x 103 card, `type.display`, `Space.lg` inset: the one thing on the talk's body), the cover of a `TeachingHold` |
| Card back 50 x 68, ring 2 amber, rotated -4 | inside `PeekBox` (`ground.mark`: bone, `Tilt.thumb`), with the `HoldCue` on it |
| "My night" Gloock 24, "Hold to peek" 14/600 quiet | `type.heading`; "Hold to peek" is cut; until My night has been held on this device the cue's "Hold" (`type.cue`) sits under the title |
| "In the deck tonight" 12/700 day quiet, gap 10 | **Cut** by the first-time play spec ("In the deck tonight") |
| Deck thumbnails 50 x 68, ring 2 indigo, "×2" badges, gap 10 | `RoleCard(size: RoleCardSize.mini)` in `Flexible` (they shrink: the mock's six overrun 342) |
| Token pips 30, waiting ring #8f8a99 at 0.35; "2 of 5 ready to vote" 14/700 day quiet | `ProgressPips` plain, "{d} of {n} ready" (`type.body`) |
| "I'm ready to vote": indigo, 5,5 blood | `PrimaryButton.quiet`, never locked (section 8): outlined, never amber (08 must not shout "end the talk") |

## S09 Vote (day)

| Element | Primitive / role |
|---|---|
| Night band, full bleed, padding 26 24 0 | `ScreenFrame(topSlot: TimerBand.bar(...))` (`Space.xl` + 2 and the status bar) |
| "18" 76 lh 0.9 -0.02em; "seconds to choose" 12/700 +0.14em in bone; gap 10 baseline | `type.timerVote`; "seconds to choose" is **Cut** by the first-time play spec; in its place beside the number, "Who dies today?" (`TimerBand.bar(title:)`, in bone), so the band is not empty and the rows get the room |
| Bar 8 px full bleed, track hairline, 30% danger line | `TimerBand.bar(remaining:)` (`TimerBand.barHeight`, `night.hairline`, `night.dangerLine`); the share from `stage_started_at` (`StageShare`), unlit without it |
| "Who dies today?" 34 lh 1.05, margin-top 6 | `type.screenTitle`, in the band (above) |
| Rows 68 tall, radius 34/6, padding 0 16 0 8, gap 14, token 52, Gloock 26; gap 12 | `PlayerRow(size: PlayerRowSize.large, onTap:)`; `Space.md`. Sized to the room (`VoteRows`, measuring each name at the text size): `PlayerRowSize.compact` with `Space.sm` when the tall rows do not fit, scrolling with the fade (`FadingScroll`) only when nothing does. Each row keeps `Space.xs` for the lift, out of the gap, so a lifted row leaves the gaps even |
| Picked: blood fill, 4,4 indigo, bone ring | `picked: true`: lifts and takes `ground.selection` (ink) at `shape.selectedRing`; the blood fill is cut. Once locked the pick stays as it is and every other row is `dimmed: true` (owner, 20 November 2026) |
| X icon 26, stroke 3.5, "Your pick" | "Lock in {name}": `PrimaryButton(icon: Icons.lock_outline)`; the X is cut (it read as "remove") |
| Token pips, "3 of 5 locked in" | `ProgressPips` plain, "{d} of {n} locked" |
| "Lock in Cleo" | `PrimaryButton` |

## S10 The count (day)

| Element | Primitive / role |
|---|---|
| Night band, full bleed, padding 30 24 20, gap 16 | `ScreenFrame(topSlot: Band(child: ...))`; `Space.lg` |
| Dead player's token 64, ring 2 danger line | `PlayerToken(size: TokenSize.band, ringColor: ground.dangerLine)` |
| "The count" label; "Dev dies." 44 lh 0.95 | "The count" is **Cut** by the first-time play spec; `FitLine` in `type.heroVerdict` (hero line) |
| "Accused · Voted by" | **Cut** by the first-time play spec ("Accused", "Voted by") |
| Rows 64 tall, radius 32/6, padding 0 14 0 8, gap 12, token 48, Gloock 24 | `PlayerRow(size: PlayerRowSize.count)` (`type.heading`) |
| Name column 62 wide | the name is `Expanded` instead, so long names fit; the voters still sit at the end |
| Voters' tokens 34, gap 6 | The voters by name under the accused's: `PlayerRow(detail: "Ana, Ben, Cleo")` in `type.body` 16 |
| Count Gloock 28, right-aligned | `Tally(n)` (`type.tally`) |
| The dead player's row: blood, 4,4 indigo | `picked: true` |
| Dead card: paper, padding 10, gap 16, 0 5 paperEdge + 0 10 blood | `PaperCard(lift: PaperLift.heroSlab, padding: Space.smPlus)` (day heroSlab) |
| Portrait 120 x 160, radius 3 | `RolePortrait(width: RolePortrait.count)` |
| "Dev was the" label; "Werewolf" 36 lh 0.95; "Werewolf team" tag 13/700 blood | "Dealt" and "Now" portraits (`RolePortrait`, captions in `type.caption`) with an arrow when the card moved; `type.display`; the team tag `TagChip` / `TagChip.danger`. "Dev was the" is cut |
| "See who won" | `PrimaryButton` |

## S11 Results (night; from the picture)

| Element | Primitive / role |
|---|---|
| Blood band, full bleed, curved foot with a darker edge | `ScreenFrame(topSlot: Band(tone: BandTone.danger, child: ...))` (`night.danger`, the primary shadow's colour for the edge; the curve's depth follows `shape.archRoundness`) |
| Winner's portrait in an arched paper frame, tilted about -3 deg | `RolePortrait.arched(width: RolePortrait.winner)` (`ground.paper`, `elevation.slab`, `Tilt.hero`) |
| "Cleo held the Robber": indigo chip, bone 13/700 | `TagChip(..., tone: TagTone.ground)` |
| "The Werewolf wins" about 40, lh about 0.95 | `FitWords` in `type.heroWinner` (hero line; wraps between words, set smaller before a word would break) |
| Night timeline: player columns (name Gloock 18, dealt role 12/700 quiet, the Werewolf's in red), numbered steps ("1" Gloock 18, "Werewolf." 14/700, the rest 14/600 quiet), column lines 2 px, the Werewolf card's path 3 px red, swap curves in bone, look marks (ringed dots) | a screen widget for the results (data-driven painter) built from roles only: names `type.nameSmall`, roles `type.badge` in `ground.quietText` / `ground.dangerText`, steps `type.smallStrong` + `type.small`, lines `ground.hairline` at `shape.ring`, the Werewolf path `ground.dangerLine` at `shape.selectedRing`, swaps `ground.text`, marks `ground.text` ring. Not a primitive: one screen draws it |
| Final roles under the columns, "Werewolf" chip, "WON" amber, "DIED" quiet | `type.body` names, "Won" / "Died" in `type.caption` (`ground.quietText` / `ground.dangerText`); "WON" amber is cut (amber is the primary button's alone) |
| Footnote 13/600 quiet | `type.caption`, `ground.quietText` |
| "Play again" 60 tall amber; "Change the deck" 60 tall outline, side by side | `PrimaryButton(size: ButtonSize.large)` and `SecondaryButton(size: ButtonSize.large)` in a `Row` of `Expanded`, `Space.md` |

## What could not be mapped one to one

- **S11 has no markup**: its values are read off the picture (band, portrait, winner line,
  timeline) and are approximate.
- **The S11 timeline** is drawn by one screen, so it is not a primitive; every value it needs is a
  role (above).
- **S04's soft glow** under the card (`0 34px 44px`) is not drawn: the brief allows hard
  shadows only.
- **S03b's hyphenated "Trouble-maker"**: names are never broken (`FitLine` sets them smaller).
- **S10's fixed 62-wide name column** is an `Expanded` name that wraps between words and is set
  smaller to fit two lines (`FitWords`), rather than overrunning the voters; no name is ever cut
  short (the fit sweep and `just screens ... strict` fail on text drawn cut).
- **Snaps** of 1 to 2 px: 5 to 6 (grid and center-card radius, grid name gap is kept at 5 inside
  `RoleCard`), 7 to 8 (deck-link gap), 22 to 24 (center-card gap), 26 to 24 + 2 (vote band top),
  13 to 12 (S01's field label, to the brief's 12 px labels), S04's tag padding 7/12 to 6/10.
