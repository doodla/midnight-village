# How the game feels: motion, touch and vibration

One reference for every polish pass (issue #28) and every new screen. The owner's bar
(22 November 2026): "a game that can win awards. Micro interactions matter", "look prettier and
feel better, without costing usability", "include vibration". A builder builds from the table in
section 4; a reviewer checks against section 5. Do not invent timings or gestures a pass
needs: use the tokens here, or add one here first.

Where this page and `../specs/frontend/first-time-play.md` differ, the spec wins (its sections 7
and 8 first). A difference found later goes to section 6, not decided here. Status words, as of this
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
4. **Night is silent and still.** From the deal to the last night window: no vibration, no sound,
   and nothing that differs by role or only on the phone that acted (design brief section 3.3 and
   7, spec sections 3 and 8). Same board, same motion on every phone. Secrets show only while
   held. The one exception is the owner's: your own card's face landing on 04 gives one light
   tap (section 3), the same on every phone whatever the role.
5. **Usability never pays.** Tap targets, contrast, reading floor (16 and 14 px), taps to act and
   whole names stay the same or get better. A name is never cut, also in the middle of a motion.
6. **Paper, not glass.** Things lift, sink, drop in and turn like cut paper with a shadow. Short
   moves, one idea at a time, no bounce beyond a small settle, no recolours or filters. Shadows are
   hard; the one soft thing is the faint bone glow of a card picked on the night board
   (`GroundElevation.glow`, night only).
7. **Teach a gesture once, by doing it** (the `hold`, `night_choose` and `vote_lock` cues). Then
   never again.

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

Their own constants (not `Motion`): `PaperFlip` (`primitives/paper_flip.dart`, the one card
turn-over: turning to the face `PaperFlip.turn` = `quick` 160 ms, back to the cover
`PaperFlip.turnBack` = `press` 90 ms, lift 8 px, grow 3%, the shadow falling 4 px further, a
2% dip under a finger, a settle of 3% of the turn, the paper's edge 3 px, perspective 0.001;
`HoldToReveal.flip` is its `turn`); `HoldToReveal.holdDelay` 120 ms (a touch shorter than this is
a tap, longer is a hold: the face shows after it) and `revealedAfter` 800 ms (a reveal counts once
seen this long; a count, not a wait); `CueWave` 120 ms each, 90 ms apart, lifts 8 px (night) and
6 px (vote); `HoldCue` breath 1400 ms, scale 1.06; a replayed cue runs 3 s. A list that staggers
takes `stagger` × (rows − 1) + `settle` on the count, and `stagger` × steps + `settle` on the
results' night. There is no cap, so a list is short only because a table seats at most 10: 10 rows
take 1.6 s. A tap finishes them.

**To add** (only what #28 needs; the builder fixes the value in a recording, within the bound):

| Token | Start value | Pass | Why |
|---|---|---|---|
| `Motion.land` (built, pass 4a: `Curves.easeOutBack`) | a curve with at most 10% overshoot | 4, 6 | The lock stamp; a joining player's row dropping in |
| `Motion.ambient` | 4 s per loop | 7 | Join's lit window and drifting moon; stops once typing starts |
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
| `light` | `lightImpact` | "Ready to vote" tapped (08). "Lock in {name}" tapped (09), on the tap, not on the answer. 11 Results: once, when the result lands (every phone, the same instant). 10 when nobody dies: once, as the last mark is struck |
| `thud` | `mediumImpact`, the one medium | The dead card landing face up (10): once per count, with several dead too, on every phone at the same moment. A tap that finishes the flip fires it once, as it lands. Wired in pass 4b (`light` too, once, when nobody dies) |

Decided 22 Nov 2026. Where: 08, 09, 10 and 11, the day. "Ready" means only 08's "Ready to vote"; 04's "Ready" is in the
night and has none. 11 counts as a day screen although its ground is the night's.

The one exception at night (decided 22 Nov 2026, the owner asked for it): `light` when your own
card's face lands on 04 (`HoldToReveal` in place, through `PaperFlip.onLanded`). It is a hold of
your own card in your own hand, the same on every phone and every role (everyone looks at the
deal), once per turn that lands (a hold let go before the face lands gives none; a cut under
reduce motion still gives it), and never when the card goes back. Holds of "You" and "My night"
stay silent.

Never fires: at night (05, 06, the deal's dusk, and 04 but for that one); on any other hold or
reveal; on 01 to 03; on a
banner, error, disabled tap, timer tick, reconnect or a player arriving or leaving; for anything
that only one phone gets because of its role or what it did at night; no `heavyImpact`, no long
`vibrate`.

How it is built (`frontend/lib/design_system/feel/haptics.dart`): one `Haptics` class is the one place that asks for a vibration, and nothing else calls
`HapticFeedback` (`haptics_only_here_test.dart` fails any direct call, as `fixture_sources_test.dart` does for fixtures).
`tick`, `light` and `thud` take the touched widget's context and do nothing on the night's ground (so the call must be made from under the screen's own ground); `landed` is the card's face landing on 04, the one vibration at night (the owner's), and takes no context. None throws; a test listens on the platform channel to see what fired. A
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
| The third player arrives | "Need 3 players" outline becomes the one amber "Deal to {n}": fill and outline change, label cuts | `press` | Cut | exists |
| Share | System share sheet; where there is none the link is copied and the screen says so | none | Same | exists |
| Tap a deck chip | The chip lifts 4 px with the selection outline; the strip's counts follow | `quick` | Cut | exists |
| A card added or removed in the editor (03) | The count badge ticks and the card lifts or settles, so "Add 2 cards" reads as cards. The editor is #8; polish waits on it | `quick` | Cut | no pass |
| Guest waits | "{host} deals" large, a quiet underlined "Leave" that dims while pressed | `press` | Same | exists |
| Host taps "Deal to {n}" | The busy mark on the button in the frame of the tap, taps ignored until the dusk lands (`LobbyNotifier.deal` returns only when `/me/table/` has named the next screen, so 02's own busy covers the gap; Leave is the same, a `Pending` until 01 is named) | none | Same | exists |

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
| Tap "Ready" before holding | The `hold` ring breathes for 3 s; the button does not move | 3 s | Ring still, visible | exists |
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

One body for every place the app waits (`Waiting`), laid in the frame of the screen it waits for: the opening (the saved account, then `/me/table/`: 01's village and its title), 04's village and "Your card", 08's sky and "The village wakes", 09's band and "Who dies today?", 10's and 11's ground. The screen's frame is up in the first frame; nothing is held back.

| Wait so far | The player sees | Reduce motion |
|---|---|---|
| 0 to 300 ms | The frame only: ground, header, headline. No sign: an answer that comes now gives way with nothing having flashed | Same |
| 300 ms to 5 s | Three paper lanterns hung from the header's edge, coming in over `settle`, lit one after another over `waitLoop` | Burning steadily, in view |
| 5 s on | The same, with "Still on its way." under them (its place kept from the first frame), fading in; nothing on the screen moves | Cut in |
| A fetch failing (offline, a 5xx) | "One moment" with "Try again" (the fetch now instead of at its next turn: the opening, 04, 08 and 09 offer it), alone on one line where the lanterns hung; it is made again by itself with backoff | Same |
| The answer | The screen's content crossfades in (`settle`) over the frame; one wait is one key, so the wait is never faded into itself | Cut |
| Over a screen already shown, the phone loses the server | "One moment" settles in over the top; the screen and the seat stay | Cut in |
| A tap's request in flight | The tapped control's busy mark in the frame of the tap, busy until the next screen is up | Same |
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
| Press, amber button | The shadow collapses to 20% and the paper sinks by its offset; back on release | `press` | Cut | exists |
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
5. Night: no vibration, no sound, same layout and motion on every role's phone; faces held above
   the thumb are cut in and out, never faded half-seen.
6. Vibration: only the three names, only where section 3 allows, always with a visible change.
7. Usability held: targets (48 px, 44 only where named in the pass), 16 and 14 px floors, contrast,
   taps to act, and every name whole at 10 players and 320 wide.
8. One look: original Shadow paper art, no recolour or filter; new art shown to the owner.
9. The row for the moment in section 4 is updated in the same change (status, timings).

## 6. Open question

For the owner. Everything else raised while writing this page was decided on 22 November 2026 and
sits in the body above.

1. Should the game ever make a sound? Today it makes none, and this page assumes none. Say so if
   you want some, for example a soft knock when the dead card turns over.
