# How the game feels: motion, touch, vibration and sound

One reference for every polish pass (issue #28) and every new screen. The owner's bar
(22 November 2026): "a game that can win awards. Micro interactions matter", "look prettier and
feel better, without costing usability", "include vibration". A builder builds from the table in
section 4; a reviewer checks against section 5. Do not invent timings or gestures a pass
needs: use the tokens here, or add one here first.

Where this page and `../specs/frontend/first-time-play.md` differ, the spec wins (its sections 7
and 8 first). A difference found later is put to the owner, not decided here. Status words, as of this
page: **exists** is built as written; **pass N** is to build in pass N of the whole-game review
in #28 (1 dusk and dawn, 2 night board, 3 your card, 4 vote and count, 5 results, 6 table, 7 join,
8 press feel; pass 1 covers deal to night and night to talk only, which corrects #28's list: vote to
count has no wipe); **no pass** is missing and no pass owns it yet.

## 1. Principles

1. **Every touch answers in the first frame.** Anything tappable shows a press the frame the
   finger lands; the commit happens on release, on the same frame. A touch that is ignored still
   answers (it presses and returns); its words already say what is missing.
2. **Motion never blocks and never waits.** A new screen takes touches from its first frame; any
   tap finishes a running motion; nothing is locked behind an animation. Every stage length is
   the table's setting. The one held beat, the count's 1.2 s, stays (decided 22 Nov 2026): a tap skips it, so it is not an added wait.
3. **Reduce motion gets the same information, instantly.** Slides, lifts, scales, wipes, staggers,
   flips and breathing become a cut to the end state. A colour or outline change still shows.
4. **Night is silent and still.** From the deal to the last night window: no vibration, no sound
   that only some phones make (the theme, the same on every phone, may play: section 6), and
   nothing that differs by role or only on the phone that acted (design brief section 3.3 and
   7, spec sections 3 and 8). Same board, same motion on every phone. Secrets show only while
   held. The one exception is the owner's: your own card's face landing on 04 gives one light
   tap (section 3), the same on every phone whatever the role.
5. **Usability never pays.** Tap targets, contrast, reading floor (14 px body, 12 px labels), taps to act and
   whole names stay the same or get better. A name is never cut, also in the middle of a motion.
6. **Paper, not glass.** Things lift, sink, drop in and turn like cut paper with a shadow. Short
   moves, one idea at a time, no bounce beyond a small settle, no recolours or filters. See
   section 1a for the material: shadows are the two-layer paper shadow (never a blur), the one
   soft thing is the faint bone glow of a card picked on the night board
   (`GroundElevation.glow`, night only).
7. **Teach a gesture once, by doing it** (the `hold`, `night_choose` and `vote_lock` cues). Then
   never again.

## 1a. Material, light and placement (the night polish)

Static: nothing here moves, so reduced motion is unaffected. All of it is in the design system,
so every screen has it; no screen asks.

**Paper is a material.** Tokens in `skin/elevation.dart`, `skin/skins/shadow_paper.dart`.

| Token | Value | What it does |
|---|---|---|
| `PaperShadow` | a tight CONTACT shadow (alpha .62, 0.5 px + 0.2 x the drop down) and a soft CAST of 5 stacked copies (spread 2.4 x the drop, fall 1.0 x the drop, alpha .075 each, leaning away from the screen's light) | Every cast shadow of a card, row, chip, button or sheet. The cast is stepped flat copies, not a blur: no blur, no saveLayer, nothing per frame. Light falls from above; a press scales the drop |
| `HardShadow(offset, ink)` | a DROP: how high the paper lies, in the ink it casts (night `#07091A`, day `#2A1D2B`, paper `#3B2E22`) | Becomes the paper shadow. `Elevation.drop` heights: badge 2, card 4, lying 5, raised 6, selected 8 (day) or 10 (night), slab and hero 12 to 14 |
| `HardShadow.edge` | a hard copy in the paper's own colour | The thickness of paper: a stack of sheets (`slab`, `heroSlab`), the plaque's backing |
| `SkinShape.radius` | 5 for every cut of paper (`radiusSmall`, `radiusTiny` are the same) | One corner |
| `PaperGrain` | a 96 px tile of speckle and fibre, drawn once from a fixed seed, tiled at alpha .5 over a paper fill | `cutPaper` puts it on every paper surface (a `BoxDecoration.image`; the image is there on the first frame, so no golden or screen ever shows a bare paper) |

**Torn edges and pins** (`primitives/deckle.dart`). `DeckleBorder`: the four sides of a piece of
paper step in by up to `depth` (2.4 px for cards, rows, scraps, the field; 3.2 for the plaque;
4.5 and long bites, `torn`, for a banner; 9 for the talk's sky) in nibbles of `step` px, seeded from
the piece's own id (`deckleSeed`), so the same piece is torn the same on every phone. Only the paint
is torn: `dimensions` is zero, the layout box and the hit target are the plain rectangle's.
`PaperPin`: a flat matte pin (9 px), its own hard shadow leaning away from the light.

**Parts.** The primary button is a PLAQUE: deckled amber paper on a darker amber paper backing
(`HardShadow.edge` 5 px) with the paper shadow, a cut line and a pin at each end, a seeded tilt;
still the only amber control. Every secondary button is a PINNED SCRAP, torn at its edge, with a
pin and a seeded tilt, sinking into its shadow under a finger as the plaque does: bone by day and
for `SecondaryButton.paper`, a darker scrap (`ground.panel`) with a bone rim on the night. Player
rows (the table, the vote) are paper slips with a pin through the top edge; the join code is a
pinned notice (two pins). The deck strip is a fan of small cards. Touch targets are as they were
(48 and up).

**Headers on paper: `PaperBanner`.** The question and the timer sit on a ribbon of torn bone
paper, a hair off square (-0.7 degrees), a pin at each end, set in the day's ink (`ground.text`
inside it): the vote's and the talk's `TimerBand`, the night board's title with the candle, your
card's title. The timer and the question keep their type roles (the timer styles, 24). The talk's
sky window is torn off along a seeded line instead of fading to a straight edge.

**One mark for picked and done.** `PaperMark` (`primitives/paper_mark.dart`): a drop of wax in
the ground's `mark` colour (bone on night, ink on day and paper; never amber), its edge uneven, a
ring stamped in it and a brush tick across it, in `onMark`. A picked vote row and a picked night
card wear it on the upper corner (`PaperMarkCorner`, 22 px, hanging 8 px over the edge, no touch);
a button that is done (`done`, "Ready ✓") wears it before its word. Picking is still lift plus the
selection outline; the mark is what says "this one".

**Light and ground per phase: `Mood`** (`primitives/mood.dart`), the layer under every
`ScreenFrame` (the screen's `mood:` overrides what its ground gives: the results take dawn). One
picture painted once (a repaint boundary: nothing per frame): a ground, the game's own village as
the scene art already in the app (`LayeredArt`: a few image layers), one light and a heavy
vignette, and shadows that fall AWAY from the light (`Mood.leanOf`, read as `PaperLight`):

| Mood | Village | Light | Vignette | Shadows lean |
|---|---|---|---|---|
| night | the night village from the top, lit in the top third (the ground over it 0% to 22%), 74% at 62% of its height, whole at its foot | the moon's cool pool (`rgba(220,226,255,.20)`) round the moon, and a cone of it falling on the table | `rgba(3,4,12,.60)` at the corners, clear in the middle third | left (moon, upper right) |
| lantern (the table, the first screen) | the night village standing at the foot, behind what the table leaves empty | a warm lantern pool (`rgba(255,190,110,.26)`) on the players; the first screen also lights its name field | the night's | straight down |
| dawn (the results) | none | the lantern's pool low on the board | the night's | straight down |
| day | the dawn gallows at the foot, clear in its middle, the day's gold over its top and its foot | a low sun on the left edge, a wide warm pool and a long beam across the screen | warm plum, 26% | right (long, from the left sun) |

A screen with a picture of its own (01's street, 04's backdrop, the talk's sky) has no village
behind it. Bare words are not set on the village: they sit on paper (banner, slip, plaque), a
backing of the ground (the deck's stepper values), or the plain ground. Contrast is held on the
ground and its lights (`mood_test.dart`, `scene: false`: 7:1 for the ground's text, 4.5:1 for the
quieter inks and faint) and on the real screens, village included, by the page tests
(`contrast_test.dart`).

**A little life in placement.** `Tilt.seededCard(id)` (at most 2.5 degrees either way: the role
cards of the deck) and `Tilt.seededRow(id)` (at most 1.2: player rows, preset chips, tags, scraps,
the plaque), from the item's own id by djb2 (`SeededTilt.unit`), so it is the same on every
build, phone and platform; nothing random. Only the paint turns: layout, hit targets and text
measures are unchanged. None on text fields, the timer or the night board's cards (which keep
their scatter tilts).

## 2. Motion tokens

`Motion` in `frontend/lib/design_system/layout/space.dart`; read them, never write a literal.

| Token | Value | Used for today |
|---|---|---|
| `press` | 90 ms | A button going down and coming back; a quiet word dimming; your card turning back to its cover and dipping under a finger (04) |
| `quick` | 160 ms | A pick: card, row or chip lifts (4 to 8 px) and its outline; a row or card dimming; your card turning to its face (04) |
| `settle` | 260 ms | A part of a screen arriving: the shell's crossfade; a count row or night step landing |
| `reveal` | 400 ms | The count's dead card turning over |
| `stagger` | 150 ms | Between one row and the next landing (the count, the night on 11) |
| `beat` | 1200 ms | The count's held beat before the flip. A tap skips it |
| `scene` | 500 ms | The dusk (deal to night) and the dawn (night to talk), nothing else: one screen moves on a paper edge for the first 85% of it, the other stays; the destination's header travels further than its screen and its layers (the moon, the clouds; the roofs, the sun, the birds) each travel their own distance (pass 1, built) |
| `signAfter` | 300 ms | A wait's sign of life comes in after this: an answer that arrives sooner shows no sign. It delays the sign only, never what is loading (issue 10) |
| `slowAfter` | 5 s | A wait that has lasted this long is named once, plainly: "Still on its way." (issue 10) |
| `waitLoop` | 1500 ms | One round of the sign of life: three paper lanterns lit one after another (issue 10) |
| `curve` | easeOutCubic | Everything above, except the count's flip (easeInOut); inside a scene, each part runs its stretch of the 500 ms in this curve |
| `Motion.within(context, d)` | `d`, or zero under reduce motion | The shell and the scene switcher use it; the other five places that check reduce motion move to it in their passes |
| `ambient` | 4 s | One round of something that idles (`Ambient`'s default period) |
| `breathe` | easeInOutSine | `Ambient`'s default curve: a breath, slow at both ends |
| `restLeast`, `restMost` | 8 s, 16 s | How long something that idles rests, still, between bursts: a length in this range taken from its own id, the same on every phone |

Every tappable part is to press through `Pressable` (`feel/press.dart`: down on the pointer-down, `press` on `curve`; up over `quick` on `land`); the parts move onto it in a later piece.
Everything that loops goes through `Ambient` (`feel/ambient.dart`), and a screen at rest is idle most of the time:
an effect is a small layer over a still picture, never a reason to draw the screen again.
- **Burst and rest**: it plays one round (or a few), then truly rests at its still look (no frame at all) for `restLeast` to `restMost`, then plays again.
  Only something whose job is to show a wait loops without rest (`Ambient.continuous`: the waiting sign's lanterns, a busy button's lantern).
- **Teaching is finite**: the hold cue breathes three times, then stands still (still the sign);
  it breathes once more only after a tap on the locked Ready before a hold, never once learned.
- **Yield to the finger**: a touch anywhere ends every burst at once (back at its still look, no animation, counted as played), and its rest starts again a `settle` after the last lift;
  so the frame that answers the press, and the frames where the tap commits and its answer arrives, draw no decoration.
  A waiting sign (`Ambient.continuous`) only holds under a finger and goes on a `settle` after the last lift.
  A lift the app never hears (a tab hidden under a finger, a device removed) lets go too.
- It runs only with the app in front, its screen not covered, and motion allowed (reduce motion: its still look).
Both are in `frontend/lib/design_system/README.md`, "Press and Ambient".

Their own constants (not `Motion`): `PaperFlip` (`primitives/paper_flip.dart`, the one card
turn-over: turning to the face `PaperFlip.turn` = `quick` 160 ms, back to the cover
`PaperFlip.turnBack` = `press` 90 ms, lift 8 px, grow 3%, the shadow falling 4 px further, a
2% dip under a finger, a settle of 3% of the turn, the paper's edge 3 px, perspective 0.001;
`HoldToReveal.flip` is its `turn`); `HoldToReveal.holdDelay` 120 ms (a touch shorter than this is
a tap, longer is a hold: the face shows after it) and `revealedAfter` 800 ms (a reveal counts once
seen this long; a count, not a wait); `CueWave` 120 ms each, 90 ms apart, lifts 8 px (night) and
6 px (vote); `HoldCue` breath 1400 ms, scale 1.06, three breaths then still; a replayed cue runs 3 s. A list that staggers
takes `stagger` × (rows − 1) + `settle` on the count, and `stagger` × steps + `settle` on the
results' night. There is no cap, so a list is short only because a table seats at most 10: 10 rows
take 1.6 s. A tap finishes them.

**To add** (only what #28 needs; the builder fixes the value in a recording, within the bound):

| Token | Start value | Pass | Why |
|---|---|---|---|
| `Motion.land` (built, pass 4a: `Curves.easeOutBack`) | a curve with at most 10% overshoot | 4, 6 | The lock stamp; a joining player's row dropping in |
| `Motion.ambient` (built with `Ambient`, its default period) | 4 s per loop | 7 | Join's lit window and drifting moon; stops once typing starts |
| the reduce-motion helper, the rest | Today six places check it (shell, the card flip, count, results, ring, wave) and, since pass 2, the night cards (dip, lift, glow, dim) and the Choose button's rise; buttons' press, rows, chips and dims ignore it. `Motion.within` exists (pass 1); passes 4 and 8 move the rest to it | 4, 8 | One check, so none is forgotten |

## 3. Vibration

Flutter's own `HapticFeedback`; no new package.

**The rule** (decided 22 Nov 2026; it governs all of this section). A vibration fires only for
something every player does openly in the day (ready, vote), or for something that happens on every
phone at the same instant. Never at night, and never in a way that could tell a neighbour who acted
or what role someone holds. Design brief section 7 ("no vibration may reveal who acted") stays
true under it: nothing here fires on a night action or a hold, and a day vibration only goes with
a public act.

Decided 22 Nov 2026: everything is light except the dead card's flip, the one medium. Nothing stronger exists.

| Name | Is | Fires |
|---|---|---|
| `tick` | `selectionClick`, light | A vote pick on 09, each time the pick moves. Taking back "Ready to vote" on 08 |
| `light` | `lightImpact` | "Ready to vote" tapped (08). "Lock in {name}" tapped (09), on the tap, not on the answer. The end board when nobody is hanged: once, as the banner unrolls in the reveal |
| `thud` | `mediumImpact`, the one medium | The end board's reveal: as each HANGED stamp lands (two deaths, two knocks), on every phone in the game. A touch that settles the reveal fires one if none had come; a phone that opens at the results feels nothing (`docs/specs/frontend/end-board.md`, section 9) |

Decided 22 Nov 2026. Where: 08, 09 and the end board, the day. "Ready" means only 08's "Ready to vote"; 04's "Ready" is in the
night and has none. The end board counts as a day screen although its ground is the night's.

No exception at night. Decided 22 Nov 2026 and withdrawn 23 Nov 2026: `light` when your own
card's face lands on 04 was built (`PaperFlip.onLanded` wired to `Haptics.light`), and the owner,
playing the live app, said: "The vibration on the card after I press to reveal it, I don't like
it so maybe get rid of it." Nothing vibrates when a card is held, turned or revealed: your
card, "You", "My night". `PaperFlip.onLanded` stays as a callback for the screen's own use; the
card on 04 passes none.

Never fires: at night (04, 05, 06, the deal's dusk); on any hold or reveal of a card; on 01 to 03; on a
banner, error, disabled tap, timer tick, reconnect or a player arriving or leaving; for anything
that only one phone gets because of its role or what it did at night; no `heavyImpact`, no long
`vibrate`.

How it is built (`frontend/lib/design_system/feel/haptics.dart`): one `Haptics` class is the one place that asks for a vibration, and nothing else calls
`HapticFeedback` (`haptics_only_here_test.dart` fails any direct call, as `fixture_sources_test.dart` does for fixtures).
`tick`, `light` and `thud` take the touched widget's context and do nothing on the night's ground (so the call must be made from under the screen's own ground);
there is no call for a card landing, and none may be added (the owner's line above).
None throws; a test listens on the platform channel to see what fired.
A
vibration goes with a visible change on the same frame and is never the only sign.

Where there is nothing to vibrate it does nothing, and the screen is complete without it: a phone
with no motor, or with touch feedback off in the system; the browser on iPhone and on desktop
(the page may not vibrate there). In Chrome on Android the web build may vibrate through the
browser: check on the real build. No app switch: the brief leaves out an app settings screen, so
the system's own setting rules.

## 4. The micro-interactions

One row per moment. "Today" says what the code does where it is not yet the target. Reduce
motion: "cut" is the end state at once; "same" is unchanged.

### Join (01)

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| Screen opens | The lit window pulses, the moon drifts a few px; both stop when a field takes focus. Today a still picture | `ambient` | Still | pass 7 |
| Typing a name | Field focused on arrival. Both buttons stay outlined and go from faint to full ink with the first letter | `press` (colour) | Same | exists |
| Press "Start a table" / "Join a table" | The outline fills with a hairline while down, clears on release | `press` | Same | exists |
| "Join a table" opens | The code field and amber "Join" arrive in place, focus moves to the code. Today a cut | `settle` | Cut | pass 7 |
| Join or Start sent | The tapped button (Join, or Start a table) shows its busy mark beside the label in the frame of the tap; the other way in and the field are dim and take nothing; the screen it leads to is up before anything is live again. A failure is "Not sent." or the server's reason above the buttons, with "Try again" where it helps | none | Same | exists |
| Opened from a join link | Name field and amber "Join" on the first frame | none | Same | exists |
| Tap the scan glyph | The glyph's outline fills with a hairline while down. The scanner arrives as the screen (no sheet, no slide), the window and its corners on the first frame, the camera's picture when the browser or phone has it ready; the camera is not touched before this tap | `press` | Same | exists |
| A code is read | The camera stops the same frame and the code stands in the window at once, on paper, with no fade through an empty window; the corners snap in from the window's inside to its edge and turn from cream to ink; the join starts at once, nothing waits for the motion. No vibration (01 to 03 have none) | `press` | Cut | exists |
| The light (Android) | The glyph shows it is on with the hairline fill and a stronger outline, never amber | `press` | Same | exists |
| The camera cannot be used | The window shows a closed, shuttered paper window (the village's, not a stock icon), one line and the amber "Type the code" under it; no dead end | none | Same | exists |
| Back from the scanner | Back, the glyph or the phone's, ends the camera and lands on 01 as it was left (name and all) | none | Same | exists |

### The table (02, 03)

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| Host opens the table | QR and code are on the first frame (art is precached) | none | Same | exists |
| The third player arrives | "Need 3 players" outline becomes the one amber "Start the game" (or "Need {n} more", "Add 1 card", "Remove 2 cards"): fill and outline change, label cuts | `press` | Cut | exists |
| Share | System share sheet; where there is none the link is copied and the screen says so | none | Same | exists |
| Tap a deck chip | The chip lifts 4 px with the selection outline; the strip's counts follow | `quick` | Cut | exists |
| A card added or removed in the editor (03) | The count badge ticks and the card lifts or settles, so "Add 2 cards" reads as cards. The editor is #8; polish waits on it | `quick` | Cut | no pass |
| Guest waits | "{host} deals" large, a quiet underlined "Leave" that dims while pressed | `press` | Same | exists |
| Host taps "Start game" | The busy mark on the button in the frame of the tap, taps ignored until the dusk lands (`LobbyNotifier.deal` returns only when `/me/table/` has named the next screen, so 02's own busy covers the gap; Leave is the same, a `Pending` until 01 is named) | none | Same | exists |

### The deal

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| The deal commits (02 or 03 to 04, on every phone together) | The dusk, 500 ms: the night falls. The card's screen is lowered over the table's from above on a paper lip with a hard shadow that shortens as it lands, over the first 425 ms; the table under it dims to half; the header (the layered village) comes down 30% further than the sheet, and in it, each in its own window of the 500 ms and on the same curve: the clouds drift 16 px (canvas px; 8 on the phone) into place from 150 to 425 ms (the dark ones from the left, the cream from the right, their shadows with them), and last, from 250 to 500 ms, the moon is lowered into its sky from above the top edge, 220 px (110 on the phone), when the sheet is already down to the eye (within 2 px of rest from about 370 ms), its paper shadow and the clouds' shadows sliding over it. Nothing is faded through anything. The Ready button is on screen from 35 ms (7% of the scene). 04 takes touches from frame one, where it rests, even while it is still above the screen. While `/me/` loads, the card's own frame (village and headline) is what is lowered. No vibration. A change that comes mid-scene swaps in place | `scene` | Cut | exists |
| The village at rest (04) | The layered village is the picture it always was, and nothing in it idles: no drifting cloud, no flicker, nothing that moves for one player's action or draws an eye to a neighbour (principle 4). Only the dusk moves it | none | Same | exists |
| The card arrives | A face-down card as large as the room under the headline allows, 3 by 4: its width is the smaller of the room's width and three quarters of its height; in a first game the ring breathes with "Hold" | breath 1400 ms | Ring still | exists |

### Your card (04)

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| Finger lands on the card | The card dips 2% from the next frame (`PaperFlip.dip`, `press`), before the 120 ms that make it a hold; a tap gives it back | `press` | No dip | exists (pass 3) |
| Hold | After 120 ms the card turns over in place like a piece of cut paper (`PaperFlip`): from its back (the game's back) it lifts 8 px and grows 3% as it goes through its edge, its shadow falls further from it, and it lands face up a few degrees past flat and settles; the face is never mirrored; it is built offstage from the moment the turn is asked for and shown only once past the edge. Measured: the turn is 160 ms; edge on at about 34 ms, the face 87% wide at about 68 ms, where the old fade was already 88% opaque at 45 ms, so the face reads about 50 ms later than the fade did. The settle peaks at 1.6% past flat, not 3%. The trade is taken because the turn reads as paper, and release hides the face within one frame. In a first game the ring fills over the 0.8 s it takes to count. One light tap as the face lands (section 3) | 120 ms, then `quick` (the frames read better than `press`'s five frames; decided in pass 3) | Cut, and the tap | exists (pass 3) |
| Release | The card turns back through its edge to its back at once, never slower than `press`; let go mid-turn it goes back from where it is, taken again it goes on from there | `press` | Cut | exists (pass 3) |
| A reveal counts (0.8 s seen) | "Ready" locked becomes amber; the ring stops for good | `press` | Cut | exists |
| The card arrives (first game) | The `hold` ring breathes three times (1.4 s each), then stands still on the card: the same ring and word, nothing drawing. A touch ends a breath under way (the ring is still at once) | 3 × 1400 ms | Ring still, visible | exists |
| A tap on "Ready" before holding | The ring breathes once more, then rests; on a phone that has learned it, "Ready" shows the ring for 3 s; the button does not move | 1400 ms; 3 s | Ring still, visible | exists |
| "Ready" tapped | "Ready ✓", settled (no fill or outline), the pips count up on the tap, not on the answer. No vibration | `press` | Cut | exists |
| Everyone ready, or the backstop | All phones go to the board together; night to night, so a plain crossfade, no wipe | `settle` | Cut | exists |

### Night action (06)

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| Board opens | The title in front of a quiet strip of the night village (under a half veil of the ground, the title above 7:1 on it), the candle and the seconds beside it, the cards using the height the phone gives them with no dead band (3 to 10 players, 320 wide and up), the Choose button waiting as a slot. Nothing moves; the same on every phone | none | Same | exists |
| Board opens (first game only) | Each card lifts 8 px in one left-to-right wave; learned at the first taken Choose, never again | 120 ms each, 90 ms apart | No wave | exists |
| Finger on a card | The frame the finger lands the card dips 2 px and its shadow stays where it was; every card, whatever the role, whether or not a pick could take it (a dimmed card, a sleeper's card too). No vibration | `press` | Cut (dip and return) | exists |
| Tap picks a card | The card lifts 8 px with the selection outline (bone), a soft bone glow and the deeper hard shadow, tweened together; the cards that cannot join dim | `quick` | Cut to the end state: the lift, the outline and the glow still show | exists |
| Tap a picked card; a third tap | The card settles back, the glow out, the shadow and ring as before; a third pick drops the oldest as the new one rises, in one frame | `quick` | Cut | exists |
| Choose button waits | "Choose a card" and "Choose 1 more" sit as a slot on purpose: the spec's outline with no fill (copy rule 10), clearly drawn, a dark lip inside its top edge and its words in full ink, 56 tall; not a faded button | none | Same | exists |
| Choose button follows the picks | The slot becomes "See Cleo" or the role's pass such as "Skip" (amber): the amber paper rises out of the slot, drawn down in it for one frame and eased up, and takes the tap from the first frame; the label cuts. Taking the pick back returns it to the slot | `quick` | Cut | exists |
| Tap the locked Choose | The wave plays again over the cards | 120 / 90 ms | No wave | exists |
| Choose pressed | "Chosen" at once, before any answer; picks stay lifted; nothing flashes. No vibration | `press` | Cut | exists |
| Hold "You" | The face is cut in above the thumb 120 ms after the press and cut out on release | 120 ms | Same | exists |
| A sleeper taps a card | The card bobs 8 px once; nothing is picked or sent; there is no button | 120 ms | No bob (the press state answers) | exists |
| Candle and seconds | The seconds tick and the paper candle (cut from the candle picture, on a ledge of the village, a warm light behind its flame) burns down with them: its wax sinks into the holder and its flame shrinks one step each second (from the server's own window), never out, no tween and no flicker, nothing between the steps; the number (the size it was on main, never smaller than the players' names, on the title's first line with the candle standing under it, in a fixed slot) is the one true carrier | 1 s steps | Same | exists |
| Doppelganger's result arrives | Her picks drop and Choose locks again; only her held face changes | `quick` | Cut | exists |

### Waiting

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| 05 "The village sleeps" (only while `/me/` loads) | The candle and the title; nothing moves, so no phone looks different | none | Same | exists |
| A sleeper's board | "The village sleeps", cards calm, "Nothing to do" quiet where the button is | none | Same | exists |

### What a wait shows, over time

One body for every place the app waits (`Waiting`), laid in the frame of the screen it waits for:
the opening (the saved account, then `/me/table/`: 01's village and its title), 04's village and "Your card", 08's sky and "The village wakes", 09's band and
"Who dies today?", 10's and 11's ground.
The screen's frame is up in the first frame;
nothing is held back.

| Wait so far | The player sees | Reduce motion |
|---|---|---|
| 0 to 300 ms | The frame only: ground, header, headline. No sign: an answer that comes now gives way with nothing having flashed | Same |
| 300 ms to 5 s | Three paper lanterns hung from the header's edge, coming in over `settle`, lit one after another over `waitLoop` | Burning steadily, in view |
| 5 s on | The same, with "Still on its way." under them (its place kept from the first frame), fading in; nothing on the screen moves | Cut in |
| A fetch failing (offline, a 5xx) | "One moment" with "Try again" (the fetch now instead of at its next turn: the opening, 04, 08 and 09 offer it), alone on one line where the lanterns hung; it is made again by itself with backoff | Same |
| The answer | The screen's content crossfades in (`settle`) over the frame; one wait is one key, so the wait is never faded into itself | Cut |
| Over a screen already shown, the phone loses the server | "One moment" settles in over the top; the screen and the seat stay | Cut in |
| A tap's request in flight | The tapped control's busy mark in the frame of the tap, busy until the next screen is up; its flame breathes for as long as the request is on its way, with no rest: its job is to show the wait (`Ambient.continuous`) | Same |
| A tap's request that failed | Words and "Try again" above the control, nothing else moves; or the server's reason with no button | Same |

### Talk (08)

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| Dawn (night to talk, all phones together) | 500 ms: the day breaks. The night sinks off the phone on its top edge over the first 425 ms (its lip's shadow thins as it goes); the talk, whole and live underneath, has its own header come into its window as layers: the hills, the middle roofs and the gallows standing on them rise as one bank from 300 px (canvas px; 114 on the phone) below, the near roofs 12 px further (the most the art's seams allow, so no edge ever shows free); the birds drift 40 px in; the sun comes up from behind the far hills to where the clock puts it; the sky stays; while "7:38", the card and Ready do not move at all. While `/me/` loads, the talk's own sky and headline are what rise. Ready is uncovered at 285 ms (57% of the scene) and takes touches from frame one. No vibration | `scene` | Cut | exists |
| The timer | Digits tick each second, and the paper sun on the talk's sky steps along its dotted arc with them, a jump with no tween (the vote's bar on 09 steps the same way). It stands just clear of the far ridge at 0 of the talk (all of the disc in view) and, at 1, 60% of the disc is still in view over the roofs (77% at 0.9, 85% at 0.75), so the picture of the time is never gone before time is up; the ends of the arc are behind the hills. While `/me/` loads the talk's own frame has the sky and the path and no sun (a player who opens the app mid-talk sees no sun leave); only the dawn lifts it into place | 1 s | Same | exists |
| My night opens by itself (once, when the night told this phone something) | The same paper card a hold shows, every word on screen; a tap puts it away | none | Same | exists |
| Hold "My night" | The face above the thumb; each hold shows the next page, dots inside | 120 ms | Same | exists |
| "Ready to vote" tapped | "Ready ✓" at once, pips up; a light vibration on the tap | `press`, `light` | Cut | pass 4 |
| Tapped again to take back | The button returns to outlined; a tick | `press`, `tick` | Cut | pass 4 |
| Everyone ready, or the timer ends | Day to day: a plain crossfade into the vote | `settle` | Cut | exists |

### Vote (09)

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| Rows arrive (first game) | The rows nudge 6 px in one wave; learned at the first taken lock | 120 / 90 ms | No wave | exists |
| Finger on a row | The row dips 2 px the frame it lands, the shadow staying where it was; it comes back on release or when the finger slides off (no pick) | `press` down, `quick` back | Tint only, no dip | exists (pass 4a) |
| Tap picks a row | The row rises 6 px into the room kept above it, with the ink outline and the deeper hard shadow; a tap on another row moves the pick (one settles as the other rises). Before pass 4a the lift was cancelled by the row's own padding and only the outline and shadow changed | `quick` | Cut | exists |
| A vote pick has a vibration | A tick each time the pick moves (day only; decided 22 Nov 2026) | `tick` | The vibration still fires | exists (pass 4a) |
| First pick | "Pick a name" (outlined) becomes the one amber "Lock in {name}" | `press` | Cut | exists |
| "Lock in {name}" tapped | A seal with a scalloped cut edge and a padlock is stamped inside the lower right corner of the pick's token (a blood-red disc with a bone padlock on the bone paper): it comes down from 1.4 times its size, growing up and left away from the name, and settles (`land` over `quick`, tilted a little), the button reads "Locked" (cut in, never blended from amber) and the other rows dim to 40%; your pick stays lifted and outlined and keeps its bone paper (`LockedFill.sealOnly`, the spec's "stays as it is"). The owner may instead choose `LockedFill.bloodFill`: the pick's paper cut in dried-blood red on the same frame with its words in bone, the seal a bone disc. A light vibration on the tap, not on the answer. A screen that opens already locked has the seal in place, no stamp | `land` over `quick`, `light` | Cut: the end state in one frame | exists (pass 4a) |
| A tap on a dimmed row | Nothing moves, nothing sounds | none | Same | exists |
| A tap on a dimmed night card | The pick switches to it (lift and outline move). Dimmed on the night board means "cannot join this pick", not switched off; a screen reader hears "Switches your pick". Nothing is dimmed until the first pick, so no role shows across the table | `quick` | Same | exists |
| Others lock | The pips count up, with no names and no vibration | none | Same | exists |
| Vote ends to the count | Day to day: no wipe, a plain crossfade; the count's own moment follows (decided 22 Nov 2026) | `settle` | Cut | exists |

### The count (10)

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| Count opens | Rows drop in whole, one after another (12 px up, never faded: paper and words at half strength read on nothing), the same on every phone. The band's verdict, each row's number and its voters are there from the row's first frame | `stagger`, `settle` | Starts finished | pass 4b |
| The votes are struck | Under each number the votes are struck as paper tally marks (four strokes and a fifth across), one after another down the rows (on a row of two votes or more; one vote is the number alone), from the first row's landing to where the cards turn: the beat is filled, nothing is added, and every mark is whole by the end, on a tap and with reduce motion too. Marks only show how the count arrives; the number is whole from the start | `quick` each, spread over the landing and `beat` | All struck | pass 4b |
| The dead card turns | Face down through the beat, then it rises a tenth in size and turns over (the face and its words cut in at the half, not faded) | `reveal` (easeInOut) | Starts finished | pass 4b |
| The card lands face up | The outline of every row the vote killed (outlined from the first frame, as the spec says) is cut in thicker, in ink (a cut, never a blend; never red: on this screen red is the Werewolf team's, and a dead Villager must not read as a wolf); a thud, once per count (not again if the screen is rebuilt or opened again on the same result), with several dead too (a tie: both rows, one thud). The vibration is the owner's: "include vibration" (22 Nov 2026, about the polish passes) | `thud` | Red at once; the vibration still fires | pass 4b |
| Tap anywhere | The motion jumps to its end (red and the thud as it lands); "See who won" worked all along | none | n/a | exists |
| Nobody dies | "Nobody dies." and the rows land with their marks, none red; no flip; a light knock as the last mark is struck (the owner's "include vibration", 22 Nov 2026: the outcome of the count is felt, and nobody dying is an outcome) | `stagger`, `light` | All struck, the light knock at once | pass 4b |
| "See who won" | Day to results: the band's scene rises. Today a crossfade | `settle` (`scene` if pass 5 needs it) | Cut | pass 5 |

### Results (11)

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| The winner arrives | The band for the win (village, Werewolves, Tanner each their own); the winners' cards lift, the losers dim; "You won." or "You lost." One light vibration as the result lands (decided 22 Nov 2026) | `settle`, `quick`, `light` | The vibration still fires | pass 5 |
| Every card, then the night | Dealt to final, "Won" or "Died"; then the red line, then the steps landing 150 ms apart from 12 px to the side; a tap finishes them | `stagger`, `settle` | Cut | exists |
| Tap the red line | The steps fold away or open again (the fold is a cut; opening lands the steps again) | `stagger` | Cut | exists |

### Play again

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| Host taps "Play again" | The busy mark on that button only ("Edit deck" and "Leave" dim and take nothing), until 02 is up; every phone then takes the same dusk as the first deal | the dusk (the deal's first row) | Cut | exists |
| Guest waits | "{host} deals next." and a quiet "Leave" word that dims while pressed; no button | `press` | Same | exists |

### Everywhere

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| Press, amber button (the plaque) | The paper shadow collapses to 20% and the plaque sinks by its drop; back on release | `press` | Cut | exists |
| Press, outlined button | A hairline fill while down. It does not sink yet; make it sink like the amber one, which already does (#28's pass 8 is to bring every other pressable to that feel) | `press` | Fill only | pass 8 |
| Press, quiet word | Dims to 40% while down | `press` | Same | exists |
| Press, any other tappable (chips, pace tiles, deck cards, panels, quiet words) | Today nothing until the tap ends (quiet words only dim). Dip 2 px the frame it lands | `press` | Colour only | pass 8 |
| Tap target size | Chips and the quiet "Leave" word are 44 px; they become 48 px wherever the layout holds at 320 wide. One that cannot fit stays 44 and is named in the pass (decided 22 Nov 2026) | none | Same | pass 8 |
| Release, or slide off | It comes back; sliding off cancels with no commit and no other sign; a scroll that starts on it cancels too | `press` | Same | exists |
| A disabled tap ("Pick a name", "Need 3 players") | Today nothing. The button dips and returns, no colour change, no shake, no vibration; its words say what is missing | `press` | Colour only | pass 8 |
| Request in flight | A tap that leads to another screen (Start, Join, Deal, Leave, Play again, Edit deck): the button sinks into its shadow and a small lantern burns in its own padding (the words never move), in the frame of the tap, a second tap sends nothing, and it stays busy until the screen it leads to is up (never live again in the gap after the answer). A tap whose result the phone shows at once (Choose, Ready, a vote, a deck or timer change) shows its done state at once (the outbox and the settings queue). Both send through `playerRequest` | none | Same | exists |
| An error | One quiet line of at most 6 words above the control that asked (no box), calm: no shake, no red, no vibration; "Not sent." with "Try again" where nothing the player did was wrong (it sends the same request again), the server's own reason ("That table is playing now.") with no button where it was refused; the screen keeps its picks. The failure belongs to the control: it goes with the screen, never shows up later on another. Today it cuts in | `settle`, 8 px | Cut | no pass |
| Empty | The ground and the one thing to do, never a message: a nearly empty table keeps the code loudest | none | Same | exists |
| Loading | The screen's own frame (ground, header, headline) is up at once, and where its content will be the one waiting body (`Waiting`): nothing for the first 300 ms (`signAfter`: an answer that comes sooner shows no sign, so a quick load never flashes one), then three paper lanterns hung on cords from the header's lower edge (the title in the opening, the band's or the picture's edge elsewhere), lit one after another over 1.5 s (`waitLoop`), then after 5 s (`slowAfter`) "Still on its way." under them (true on any ground), and, while a fetch is failing, "One moment" with "Try again" alone on one line, no lanterns (it is made again by itself). The content replaces it the frame it arrives (`SceneSwitcher`'s crossfade); nothing is held back and no time is added to real content. The opening (the app, the saved account, the first `/me/table/`) is 01's village and title with the same body | `signAfter`, `settle` in, `waitLoop`, `slowAfter` | The lanterns burn steadily, in view | exists |
| A player arrives | Their row drops in on the paper and settles, the lantern in the art flickers once; no vibration, no sound. Today it appears | `settle`, `land`, 2 x `quick` | Appears | pass 6 |
| A phone drops, or comes back | The token dims to 40% in the idle ring, or lifts back, at once; no words. Today a cut with no animation; animating it over `quick` is to build | `quick` | Cut | pass 6 |
| A player leaves | Their row fades and the rows below close up. Today a cut | `settle` | Cut | no pass |
| Host handover | That phone's layout changes in place (QR and Deal appear), no words. Today a cut | `settle` | Cut | no pass |
| This phone loses its connection | "One moment" over the top of the screen it is on, whenever the fetches that keep that screen true fail (the socket down or not); the seat and the screen stay as they are, nothing else moves; it goes when the phone is back, with no welcome-back. It comes in over `settle` and 8 px | `settle`, 8 px | Cut | exists |
| The app comes back from the background | Any held face is gone; the screen heals from `/me/` | none | Same | exists |
| A role sheet (03b) | Hold a portrait: the sheet rises over the scrim, closes with "Close" or a tap outside. It is Flutter's own sheet motion, not a token | framework | Framework | exists |
| Any other change of screen | A crossfade, input live on the new screen from frame one | `settle` | Cut | exists |
| Progress pips advance | The pip fills, a small settle. Today a cut | `quick` | Cut | no pass |
| Reduce motion: button press | The press sinks and returns over 90 ms although reduce motion is on. It should cut | the helper | Cut | pass 8 |
| Reduce motion: quiet word and chip | The quiet word's dim and a chip's lift and outline still tween. They should cut | the helper | Cut | pass 8 |
| Reduce motion: vote row | The row's lift, press, dim, paper colour and seal cut to the end state (`Motion.within`) | the helper | Cut | exists (pass 4a) |
| Reduce motion: night card lift | A card's dip, lift, glow and dim cut to their end state | the helper | Cut | exists |
| Reduce motion: deck role card dim | The portrait's dim still fades. It should cut | the helper | Cut | no pass |

## 5. How to judge it

**What a builder shows.** For each moment the pass changes, at phone size (390 x 844, and 360 x
640 for anything near the foot), in motion: either a short recording of the running web build, or
a strip of 6 to 10 frames laid side by side: the frame before the touch, the touch frame, +1
frame, `press`, `quick`, `settle` and the end. The screen catalogue can already be pumped to a
moment (`pumpCountOpening` in `frontend/test_screens/end_fixtures.dart`). Show the same moment
with reduce motion on. Hand over before and after with the pictures from `just screens`, as the
frontend rules say; the owner sees them before the pass merges.

**What a reviewer checks.** Yes or no on each:

1. The touch answers in the first frame (press), and the commit lands on release in one frame.
2. Every duration and curve is a token in section 2 (or a new one added to this page and to
   `Motion` in the same change).
3. Nothing waits: the new screen takes touches at frame one; any tap finishes the motion; no
   minimum time was added.
4. With reduce motion the same information shows at once, with no movement.
5. Night: no vibration, no sound but what every phone plays alike, same layout and motion on every role's phone; faces held above
   the thumb are cut in and out, never faded half-seen.
6. Vibration: only the three names, only where section 3 allows, always with a visible change.
7. Usability held: targets (48 px, 44 only where named in the pass), 14 and 12 px floors, contrast,
   taps to act, and every name whole at 10 players and 320 wide.
8. One look: original Shadow paper art, no recolour or filter; new art shown to the owner.
9. The row for the moment in section 4 is updated in the same change (status, timings).

## 6. Sound

The owner asked for sound on 24 November 2026: "Use 11labs for the audio... I want something
nice, eery and it should be loopable for the main theme... Proper sfx as well." The same day:
"Every tap was delayed... I need a focus on performance". So the rule: **sound never delays a
start, a tap or a frame.**

**Built (the mechanism; nothing is heard yet).** `Sounds` (`frontend/lib/design_system/feel/sounds.dart`)
is the one place a screen asks for a sound, as `Haptics` is for a vibration
(`sounds_only_here_test.dart`): `Sounds.play(Sfx.x)` for a cue, and for the stage's piece of the
theme a `ThemeDriver` (`Sounds.claimTheme()`, then `set(ThemeVariant.night)`). Neither throws nor
waits. The logic is `SoundEngine`
(`frontend/lib/core/audio/`, pure Dart, tested over a fake backend); on the web it plays through
Web Audio, elsewhere it is silent for now (Android's own backend is a later piece).

- **The theme has ONE owner**: the shell that maps the stage to its variant claims it once and
  drives it. Screens never call it, and nothing sets it from a `dispose`: the scene switcher keeps
  the arriving and the leaving screen alive together, so two drivers would fight and the last call
  would win. A second claim throws.
- **What plays is data**: `Sounds.catalogue`, a `SoundSet` of cue and theme-variant names to their
  files (one or more encodings, `.ogg` before `.m4a`: the first the platform decodes). It is
  empty, and with it empty the app creates nothing: no listener, no audio context.
- **After the first picture**: started from `main.dart` once the skin's art is in. The cues are
  fetched ahead; nothing is decoded before the first touch.
- **The first touch unlocks** (browsers refuse sound before a user activation): a passive listener
  on the page makes the audio context on the first event that is an activation. On a phone that is
  the finger's lift (pointerup, then touchend and click), not its pointerdown: Android does not
  count a touch's pointerdown, and a context made there starts suspended. A mouse's press and a
  key count at once. Every later gesture that finds the output stopped asks it to run again
  (`resume()` is cheap; one asked on a pointerdown may stay pending, and nothing waits on it). A
  cue asked for before then is dropped; the theme asked for is remembered and starts on that
  touch.
- **A cue** is decoded ahead and started in the same call as the tap, never late: it plays only
  when the output is running, or when that very gesture asked it to run from inside an activation
  (Flutter's tap fires on the same pointerup). Any other (before the unlock, muted, hidden, not
  decoded, the output stopped) is dropped, never stored to burst out with the others. A file whose
  fetch or decode failed is given up on for the visit (one log line).
- **The theme** is one loop in stage variants (table, night, vote, reveal), the same length, so a
  switch starts the new variant where the music is and crossfades in phase. A variant is decoded
  on its first need, one at a time and only the one wanted; until it is ready the music already
  playing goes on. At most two play at once and two stay decoded, counting the one decoding: a
  third asked for mid-crossfade waits for the outgoing voice to end. A switch is scheduled from the
  audio clock read at the start call, at least the output's own latency ahead (to be confirmed on
  a real phone). A file may carry loop points (from the WAV master, in samples or
  seconds), which also cut an encoder's padding: an mp3 or m4a looped whole has a gap.
- **Hidden is silent**: the context is suspended while the page or app is hidden and the loop
  continues on return.
- **The battery**: the output is never opened while muted, and is suspended when nothing can sound
  (muted, or no theme wanted once its fade out and the longest cue are over: `SoundTiming.idle`);
  the next gesture or theme wakes it. If the browser closes it, it is dropped and the next touch
  makes a new one (said once in the log, not on every tap).
- **Muted and the volume** are remembered on the device (`SoundSettings`, listenable; no control
  is built yet). Mute ramps the master to silence (no click); muted, nothing new is decoded.

Lengths (`SoundTiming`, `frontend/lib/core/audio/audio_backend.dart`): crossfade 1.5 s, theme in
0.8 s, theme out 1.2 s, mute 60 ms, volume 40 ms, a cut voice 15 ms, the theme scheduled 20 ms
ahead or the output's own latency if more (so a switch lands on an exact sample; a cue starts at
once), the longest cue 3 s, idle 4.2 s before an output with nothing to play sleeps.

In a browser (`frontend/tool/audio_proof/`, last result in `result.json` beside it): headless
Chromium as an Android phone (a touch profile, 412 wide, `page.touchscreen.tap`), launched with
the autoplay rule `--autoplay-policy=document-user-activation-required`. It enforced the rule: a
context made on load stays suspended, and one made and resumed on a touch's pointerdown stays
suspended through the lift and the click (its resume never settles), which is why the engine
waits for the lift. The engine's context is made on the first pointerup, running; the cue's
`start()` is called 0.1 to 0.2 ms after the pointerup the tap handler fires on ("the call"),
apart from what the device adds after it (base latency 10 ms, output latency 32 ms in headless,
which renders to no real speaker); after the browser suspends the context, the next tap resumes
it and its own cue starts; the theme renders sample-exact across loop ends and a switch. Not shown
there: hiding the page (headless keeps it visible; simulated), Chrome on a real phone suspending
on its own, Safari's interrupted state, and a real phone's latency and lead, which a phone must
confirm.

**Still to choose (the owner, by ear):** which cues exist and where they fire (a soft knock when
the dead card turns over, the seal, the dawn were among the candidates); which stages take which
variant and whether the night has the theme at all; the default volume; where a mute control
sits. Until then nothing calls `Sounds`.
