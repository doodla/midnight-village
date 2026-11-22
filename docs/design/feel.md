# How the game feels: motion, touch and vibration

One reference for every polish pass (issue #28) and every new screen. The owner's bar
(22 November 2026): "a game that can win awards. Micro interactions matter", "look prettier and
feel better, without costing usability", "include vibration". A builder builds from the table in
section 4; a reviewer checks against section 5. Do not invent timings or gestures a pass
needs: use the tokens here, or add one here first.

Where this page and `../specs/frontend/first-time-play.md` differ, the spec wins (its sections 7
and 8 first). Differences are listed in section 6, not decided here. Status words, as of this
page: **exists** is built as written; **pass N** is to build in pass N of the whole-game review
in #28 (1 dusk and dawn, 2 night board, 3 your card, 4 vote and count, 5 results, 6 table, 7 join,
8 press feel); **no pass** is missing and no pass owns it yet.

## 1. Principles

1. **Every touch answers in the first frame.** Anything tappable shows a press the frame the
   finger lands; the commit happens on release, on the same frame. A touch that is ignored still
   answers (it presses and returns); its words already say what is missing.
2. **Motion never blocks and never waits.** A new screen takes touches from its first frame; any
   tap finishes a running motion; nothing is locked behind an animation. Every stage length is
   the table's setting. The one held beat (the count's 1.2 s) is skippable.
3. **Reduce motion gets the same information, instantly.** Slides, lifts, scales, wipes, staggers,
   flips and breathing become a cut to the end state. A colour or outline change still shows.
4. **Night is silent and still.** From the deal to the last night window: no vibration, no sound,
   and nothing that differs by role or only on the phone that acted (design brief section 3.3 and
   7, spec sections 3 and 8). Same board, same motion on every phone. Secrets show only while
   held.
5. **Usability never pays.** Tap targets, contrast, reading floor (16 and 14 px), taps to act and
   whole names stay the same or get better. A name is never cut, also in the middle of a motion.
6. **Paper, not glass.** Things lift, sink, drop in and turn like cut paper with a shadow. Short
   moves, one idea at a time, no bounce beyond a small settle, no recolours or filters.
7. **Teach a gesture once, by doing it** (the `hold`, `night_choose` and `vote_lock` cues). Then
   never again.

## 2. Motion tokens

`Motion` in `frontend/lib/design_system/layout/space.dart`; read them, never write a literal.

| Token | Value | Used for today |
|---|---|---|
| `press` | 90 ms | A button going down and coming back; a quiet word dimming; the face fading in place (04) |
| `quick` | 160 ms | A pick: card, row or chip lifts (4 to 8 px) and its outline; a row or card dimming |
| `settle` | 260 ms | A part of a screen arriving: the shell's crossfade; a count row or night step landing |
| `reveal` | 400 ms | The count's dead card turning over |
| `stagger` | 150 ms | Between one row and the next landing (the count, the night on 11) |
| `beat` | 1200 ms | The count's held beat before the flip. A tap skips it |
| `curve` | easeOutCubic | Everything above, except the count's flip (easeInOut) |

Their own constants (not `Motion`): `HoldToReveal.holdDelay` 120 ms (a touch shorter than this is
a tap, longer is a hold: the face shows after it) and `revealedAfter` 800 ms (a reveal counts once
seen this long; a count, not a wait); `CueWave` 120 ms each, 90 ms apart, lifts 8 px (night) and
6 px (vote); `HoldCue` breath 1400 ms, scale 1.06; a replayed cue runs 3 s. Lists that stagger
finish within about 2 s whatever their length (10 rows: 1.6 s), and a tap finishes them.

**To add** (only what #28 needs; the builder fixes the value in a recording, within the bound):

| Token | Start value | Pass | Why |
|---|---|---|---|
| `Motion.scene` | 500 ms, never over 600 | 1 | The dusk and dawn wipe replacing the 260 ms crossfade. Input is live from frame one |
| `Motion.land` | a curve with at most 10% overshoot (`easeOutBack`) | 4, 6 | The lock stamp; a joining player's row dropping in |
| `Motion.ambient` | 4 s per loop | 7 | Join's lit window and drifting moon; stops once typing starts |
| a reduce-motion helper | `Motion` durations that are zero under reduce motion | 1 | Today six places check it (shell, hold flip, count, results, ring, wave); buttons, rows, chips, cards and dims ignore it |

## 3. Vibration

Flutter's own `HapticFeedback`; no new package. Only these, only lightly (the owner: "light").

| Name | Is | Fires |
|---|---|---|
| `tick` | `selectionClick` | Taking back "Ready to vote" (08). Proposed, off until the owner agrees: moving a vote pick (09) |
| `light` | `lightImpact` | "Ready to vote" tapped (08). "Lock in {name}" tapped (09), on the tap, not on the answer |
| `thud` | `mediumImpact` | The dead card landing face up (10): once per count, with several dead too, on every phone at the same moment. A tap that finishes the flip fires it once, as it lands |

Never fires: at night (04, 05, 06, the deal's dusk); on any hold or reveal; on 01 to 03; on a
banner, error, disabled tap, timer tick, reconnect or a player arriving or leaving; for anything
that only one phone gets because of its role or what it did at night; no `heavyImpact`, no long
`vibrate`. 11 Results: none until the owner says (section 6).

How it is built (pass 4): one `Haptics` class with these three names and nothing else calls
`HapticFeedback` (a test fails any direct call, as `fixture_sources_test.dart` does for fixtures).
It does nothing in the night phase whoever calls it, nothing under test, and never throws. A
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
| Join or Start sent | A spinner beside the label; further taps ignored; nothing else moves | none | Same | exists |
| Opened from a join link | Name field and amber "Join" on the first frame | none | Same | exists |

### The table (02, 03)

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| Host opens the table | QR and code are on the first frame (art is precached) | none | Same | exists |
| The third player arrives | "Need 3 players" outline becomes the one amber "Deal to {n}": fill and outline change, label cuts | `press` | Cut | exists |
| Share | System share sheet; where there is none the link is copied and the screen says so | none | Same | exists |
| Tap a deck chip | The chip lifts 4 px with the selection outline; the strip's counts follow | `quick` | Cut | exists |
| A card added or removed in the editor (03) | The count badge ticks and the card lifts or settles, so "Add 2 cards" reads as cards. The editor is #8; polish waits on it | `quick` | Cut | no pass |
| Guest waits | "{host} deals" large, a quiet underlined "Leave" that dims while pressed | `press` | Same | exists |
| Host taps "Deal to {n}" | Spinner on the button, taps ignored, then the dusk (next group) | none | Same | exists |

### The deal

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| The deal commits (02 to 04, on every phone together) | The table's village sinks, night rises; 04 takes touches from frame one. No vibration. Today a crossfade | `scene` | Cut | pass 1 |
| The card arrives | A face-down card at 60% of the height; in a first game the ring breathes with "Hold" | breath 1400 ms | Ring still | exists |

### Your card (04)

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| Finger lands on the card | The card dips about 2% the same frame (before the 120 ms that make it a hold) | `press` | Colour only, no dip | pass 3 |
| Hold | After 120 ms the card turns over in place, readable from the start of the turn; in a first game the ring fills over the 0.8 s it takes to count. Today a 90 ms fade | 120 ms, then `quick` | Cut | pass 3 |
| Release | The face is gone at once, never slower than `press` | `press` | Cut | pass 3 |
| A reveal counts (0.8 s seen) | "Ready" locked becomes amber; the ring stops for good | `press` | Cut | exists |
| Tap "Ready" before holding | The `hold` ring breathes for 3 s; the button does not move | 3 s | Ring still, visible | exists |
| "Ready" tapped | "Ready ✓", settled (no fill or outline), the pips count up on the tap, not on the answer. No vibration | `press` | Cut | exists |
| Everyone ready, or the backstop | All phones go to the board together; night to night, so a plain crossfade, no wipe | `settle` | Cut | exists |

### Night action (06)

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| Board opens (first game only) | Each card lifts 8 px in one left-to-right wave; learned at the first taken Choose, never again | 120 ms each, 90 ms apart | No wave | exists |
| Finger on a card, and a picked card | Touch-down dips the card 2 px; the picked card lifts with a glow. Same for every role | `press`, `quick` | Colour and outline only | pass 2 |
| Tap picks a card | The card lifts 8 px with the selection outline (bone) | `quick` | Cut | exists |
| Tap a picked card; a third tap | The card settles back; a third pick drops the oldest as the new one rises, in one frame | `quick` | Cut | exists |
| Choose button follows the picks | "Choose a card" (outlined) to "Choose Cleo" or "Keep my card" (amber); the label cuts | `press` | Cut | exists |
| Tap the locked Choose | The wave plays again over the cards | 120 / 90 ms | No wave | exists |
| Choose pressed | "Chosen" at once, before any answer; picks stay lifted; nothing flashes. No vibration | `press` | Cut | exists |
| Hold "You" | The face is cut in above the thumb 120 ms after the press and cut out on release | 120 ms | Same | exists |
| A sleeper taps a card | The card bobs 8 px once; nothing is picked or sent; there is no button | 120 ms | No bob (the press state answers) | exists |
| Candle and seconds | The seconds tick; the candle's flame shrinks with the number. Today a still candle picture | 1 s ticks | Same | pass 2 |
| Doppelganger's result arrives | Her picks drop and Choose locks again; only her held face changes | `quick` | Cut | exists |

### Waiting

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| 05 "The village sleeps" (only while `/me/` loads) | The candle and the title; nothing moves, so no phone looks different | none | Same | exists |
| A sleeper's board | "The village sleeps", cards calm, "Nothing to do" quiet where the button is | none | Same | exists |

### Talk (08)

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| Dawn (night to talk, all phones together) | Dawn rooftops rise as night sinks; the sun timer shows. No vibration. Today a crossfade | `scene` | Cut | pass 1 |
| The timer | Digits tick each second; the bar steps with them (no tween) | 1 s | Same | exists |
| My night opens by itself (once, when the night told this phone something) | The same paper card a hold shows, every word on screen; a tap puts it away | none | Same | exists |
| Hold "My night" | The face above the thumb; each hold shows the next page, dots inside | 120 ms | Same | exists |
| "Ready to vote" tapped | "Ready ✓" at once, pips up; a light vibration on the tap | `press`, `light` | Cut | pass 4 |
| Tapped again to take back | The button returns to outlined; a tick | `press`, `tick` | Cut | pass 4 |
| Everyone ready, or the timer ends | Day to day: a plain crossfade into the vote | `settle` | Cut | exists |

### Vote (09)

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| Rows arrive (first game) | The rows nudge 6 px in one wave; learned at the first taken lock | 120 / 90 ms | No wave | exists |
| Finger on a row | The row dips 2 px the frame it lands. Today nothing until the tap ends | `press` | Colour only | pass 4 |
| Tap picks a row | The row lifts 6 px with the ink outline; a tap on another row moves the pick (one settles as the other rises) | `quick` | Cut | exists |
| First pick | "Pick a name" (outlined) becomes the one amber "Lock in {name}" | `press` | Cut | exists |
| "Lock in {name}" tapped | The label lands like a stamp (scale 1.12 to 1) and reads "Locked"; the other rows dim to 40%; your pick stays lifted. A light vibration on the tap. Today a label change and the dim | `land` over `quick`, `light` | Cut | pass 4 |
| A tap on a dimmed row | Nothing moves, nothing sounds | none | Same | exists |
| Others lock | The pips count up, with no names and no vibration | none | Same | exists |
| Vote ends to the count | Pass 1 names this a dusk and dawn moment (open question 4) | `scene` | Cut | pass 1 |

### The count (10)

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| Count opens | Rows land one after another (12 px up, fading in), the same on every phone | `stagger`, `settle` | Starts finished | exists |
| The held beat, then the dead card turns | Nothing moves for 1.2 s, then the face-down card turns over | `beat`, `reveal` (easeInOut) | Starts finished | exists |
| The card lands face up | A thud, once per count, as the flip ends; with several dead they turn together, one thud | `thud` | The vibration still fires | pass 4 |
| Tap anywhere | The motion jumps to its end; "See who won" worked all along | none | n/a | exists |
| Nobody dies | "Nobody dies." and the rows land; no flip, no vibration | `stagger` | Starts finished | exists |
| "See who won" | Day to results: the band's scene rises. Today a crossfade | `settle` (`scene` if pass 5 needs it) | Cut | pass 5 |

### Results (11)

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| The winner arrives | The band for the win (village, Werewolves, Tanner each their own); the winners' cards lift, the losers dim; "You won." or "You lost." No vibration until the owner says | `settle`, `quick` | Cut | pass 5 |
| Every card, then the night | Dealt to final, "Won" or "Died"; then the red line, then the steps landing 150 ms apart from 12 px to the side; a tap finishes them | `stagger`, `settle` | Cut | exists |
| Tap the red line | The steps fold away or open again (the fold is a cut; opening lands the steps again) | `stagger` | Cut | exists |

### Play again

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| Host taps "Play again" | Spinner on the button; every phone then takes the same dusk as the first deal | the dusk (the deal's first row) | Cut | exists |
| Guest waits | "{host} deals next." and a quiet "Leave" word that dims while pressed; no button | `press` | Same | exists |

### Everywhere

| Moment | The player sees and feels | Token / timing | Reduce motion | Status |
|---|---|---|---|---|
| Press, amber button | The shadow collapses to 20% and the paper sinks by its offset; back on release | `press` | Cut | exists |
| Press, outlined button | A hairline fill while down. It does not sink yet; make it sink like the amber one | `press` | Fill only | pass 8 |
| Press, quiet word | Dims to 40% while down | `press` | Same | exists |
| Press, any other tappable (chips, pace tiles, deck cards, panels) | Today nothing until the tap ends. Dip 2 px the frame it lands | `press` | Colour only | no pass |
| Release, or slide off | It comes back; sliding off cancels with no commit and no other sign; a scroll that starts on it cancels too | `press` | Same | exists |
| A disabled tap ("Pick a name", "Need 3 players") | Today nothing. The button dips and returns, no colour change, no shake, no vibration; its words say what is missing | `press` | Colour only | pass 8 |
| Request in flight | A spinner beside the label; taps ignored | none | Same | exists |
| An error | A banner of at most 6 words above the button (with "Try again" where it helps), calm: no shake, no red, no vibration; the screen keeps its picks. Today it cuts in | `settle`, 8 px | Cut | no pass |
| Empty | The ground and the one thing to do, never a message: a nearly empty table keeps the code loudest | none | Same | exists |
| Loading | Today the ground with nothing on it, "3 or 4 seconds with no idea what is happening" (owner). It needs a moving sign of life that is not a spinner over text. #10 owns it | none yet | Still sign | no pass |
| A player arrives | Their row drops in on the paper and settles, the lantern in the art flickers once; no vibration, no sound. Today it appears | `settle`, `land`, 2 x `quick` | Appears | pass 6 |
| A phone drops, or comes back | The token dims to 40% in the idle ring, or lifts back; no words. Today a cut | `quick` | Cut | exists |
| A player leaves | Their row fades and the rows below close up. Today a cut | `settle` | Cut | no pass |
| Host handover | That phone's layout changes in place (QR and Deal appear), no words. Today a cut | `settle` | Cut | no pass |
| This phone loses its connection | "One moment" over the top; nothing else moves; it goes when the phone is back, with no welcome-back. Today it cuts in and out | `settle`, 8 px | Cut | no pass |
| The app comes back from the background | Any held face is gone; the screen heals from `/me/` | none | Same | exists |
| A role sheet (03b) | Hold a portrait: the sheet rises over the scrim, closes with "Close" or a tap outside. It is Flutter's own sheet motion, not a token | framework | Framework | exists |
| Any other change of screen | A crossfade, input live on the new screen from frame one | `settle` | Cut | exists |
| Progress pips advance | The pip fills, a small settle. Today a cut | `quick` | Cut | no pass |
| Reduce motion, small tweens | Buttons, rows, chips, card lifts and dims still move under reduce motion today. They should cut | the helper | Cut | pass 1 |

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
5. Night: no vibration, no sound, same layout and motion on every role's phone; faces held above
   the thumb are cut in and out, never faded half-seen.
6. Vibration: only the three names, only where section 3 allows, always with a visible change.
7. Usability held: targets (44 px at least today; see question 6), 16 and 14 px floors, contrast,
   taps to act, and every name whole at 10 players and 320 wide.
8. One look: original Shadow paper art, no recolour or filter; new art shown to the owner.
9. The row for the moment in section 4 is updated in the same change (status, timings).

## 6. Open questions

For the owner or the coordinator. Where they touch the spec, the spec is followed until answered.

1. "Ready" in #28 pass 4: the only Ready on a day screen is 08 "Ready to vote". 04 "Ready" is in
   the night phase, so it gets no vibration. Right?
2. Is 11 Results a day screen for vibration? It is on the night ground but after the night.
   None for now.
3. Is `thud` (medium) for the dead card too strong for "light"? The other option is `light`
   for all three.
4. #28 pass 1 lists vote to count as a dusk and dawn wipe, but both are day screens. Which scene,
   or a plain crossfade? (This page also assumes night to night, 04 to 06, is a plain crossfade.)
5. Design brief section 7 says no vibration may reveal who acted. A vote-lock vibration fires on
   the locking phone only. This page reads section 7 as night only (it cites rule 3, "Nobody
   stands out at night"). Confirm.
6. #28 pass 8 says targets of 48 px at least. Today chips and the quiet "Leave" word are 44, the
   outlined button 48. Raise them to 48?
7. Is the 1.2 s held beat before the dead card turns acceptable under "no added waits"? Any tap
   skips it and nothing is locked behind it. Keep it?
8. Add `tick` on every vote pick, and any sound? None of either is asked for; this page has
   neither.
