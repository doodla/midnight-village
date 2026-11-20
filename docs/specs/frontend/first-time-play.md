# First-time play: teach once, say little

Status: decided. This spec covers how the app teaches a first-time player and every word on every screen. Rules text lives in two places only: the role text (§3), and the night face of "You" (§3). Where this spec and the mocks disagree, this spec wins. Where it disagrees with `docs/specs/onuw/`, the rules docs win. The design-brief changes are listed in §3 under "Brief amendments" and land in the same commit.

## 1. Copy rules

1. **How words are counted.**
   - Split visible text on whitespace. A word is any piece that contains a letter. "Cleo's" and "don't" are one word each.
   - Exempt: template placeholders such as `{name}`, `{role}` and `{pos}`; the 12 role names and their plurals; "Midnight Village"; the table code; digits; glyphs.
   - A held face counts together with the screen under it.
   - A system banner (the errors table in §3) has its own budget of 6 words, including its button, and is not counted in the screen's budget.
   - Screen-reader labels are not counted, but must be 8 words or fewer.
2. **Budgets.** These were measured from the final copy in §3, as the most words visible at once.

   | Screen | 01 | 02 | 03 | 03b | 04 | 05 | 06 | 07 | 08 | 09 | 10 | 11 |
   |---|---|---|---|---|---|---|---|---|---|---|---|---|
   | Budget | 14 | 7 | 15 | 30 | 34 | 3 | 20 | 8 | 15 | 8 | 16 | 13 |

   On 11, each timeline row is also capped at 3 words.
3. **Headlines.** One headline per screen, at most 5 words.
4. **Buttons.**
   - A button label is 1 to 3 words: a verb, naming the person or card when there is one.
   - A disabled button that is waiting for input names what is missing ("Pick a name", "Need 3 players", "Add 2 cards").
   - A gate button keeps its label while locked: "Ready", "Done", "Ready to vote", "See who won", and "Choose {cards}" before "You" has been held.
   - After the action, the button shows the state in one word and stays disabled: "Chosen", "Locked", "Ready ✓".
5. **Where rules are stated.** Rules appear only in the role text (cards and 03b) and on the night face of "You". Every other screen states facts only, for example "Nobody got 2 or more votes."
6. **Gestures are never explained in text.** The only exception is the one-word cue "Hold".
7. **Reading floor.**
   - 16 px minimum, at text scale 1.0, for anything a player must read in order to act.
   - 14 px minimum for captions under cards and tokens.
   - Contrast of at least 4.5:1.
   - No uppercase, letter-spaced micro-labels on player screens.
   - `just screens 390 strict` fails on any breach.
8. **No naming in progress.** No copy names a player in connection with presence, progress, readiness, or a vote before the count. Progress is shown as "{d} of {n}" with plain pips: no tokens, no names.
9. **Sentences and banned text.**
   - At most 8 words per sentence.
   - No "!", "please", "Are you sure" or "you can".
   - The only question in the app is "Who dies today?".
   - Banned, taken from the mocks: "Holding.", "Let go", "Tap the cards while you wait", "Waiting for", "reconnect", "Your turn", "Do nothing tonight", "Night one", "Tap to add or remove", "Hold a card to read", "Each column is a player", "The red line", "untouched", "held the", "Good with", "Acts at night", "Double", "Change", "x2", "of 8 cards", "seconds to choose", "seconds of night", "left to talk", "Accused", "Voted by", "In the deck tonight", "Host · You", "I know my card", "I'm ready to vote", "One table. One night."
   - Also banned: "connection", "server", "error", "loading", "sync".
10. **Amber.**
    - One amber fill per screen, and it is always the primary button. Nothing else in the UI is amber; art is exempt.
    - On day grounds the amber button gets a 2 px ink outline, because amber on dawn grey is 1.55:1.
    - A selection is shown by lift plus an outline: bone on night grounds, ink on day grounds. This is a deviation from "bone outline", made for contrast: bone on bone rows is invisible.
    - Disabled buttons are outlined and have no fill.

## 2. The teach-once cues

**Storage.** Each learned cue is stored with `shared_preferences` (localStorage on the web) under the key `mv.learned.v1.<id>`, value `"1"`.

**Cue versus gate.** A cue is animation plus the word "Hold", and it is taught once. A gate is a game rule ("the exit stays locked until the thing is done") and applies in every game, on every phone.

**Tapping a locked gate** replays that screen's cue for 3 s on any device. This covers a newcomer using a phone that has already learned. A cue never adds waiting time: an experienced player on a new device only pays the gate itself, which is a 0.8 s hold or one tap.

**HoldToReveal timing.**
- The face shows 120 ms after the press and hides on release.
- On 06 ("You"), 07 and 08 the face hides after 5 s even if still held. 04 has no cap: everyone is on 04 at the same time, and the stage ends on everyone's Ready.
- A reveal counts once it has been visible for at least 0.8 s.
- A double tap shows the face for 2 s. Any touch hides it. It counts as a 0.8 s reveal.

**The held-face frame** is the same on every face: 04, "You" on 06, 07, and 08's My night.
- Always the same fixed size.
- Drawn above the touch point, never under the thumb.
- At most one portrait, in bone-on-indigo duotone (never red), taking 30% of the frame.
- Bone text, at most 2 lines.
- When a face has several pages, each new hold shows the next page, and page dots appear inside the frame.

**Hidden-information decision: everyone holds at the same beat.** 04 and 07 open on every phone at the same moment. On 06, every phone has to hold "You" before Choose unlocks. Every phone has a face, with the same frame and the same page count for that moment. A held thumb therefore only means "looking", and everyone looks.

| Cue (`id`) | First appears | What the player sees | Words | Unlocks | Learned when | Later games |
|---|---|---|---|---|---|---|
| `hold` | 04, the moment of the deal | The thumbprint ring on the face-down card breathes (bone colour, scale 1.00 to 1.06, 1.4 s loop), with "Hold" at 20 px under it | "Hold" | "Ready" turns amber after a 0.8 s reveal | The first 0.8 s reveal on any face | A static thumbprint glyph |
| `night_choose` | 06, the first window of the first game | When the board opens, each card lifts 8 px in a single left-to-right wave (120 ms each, 90 ms stagger) | none | — | The first successful `choose` | No wave |
| `vote_lock` | 09, the first vote | The rows nudge 6 px in a single wave | none | — | The first successful lock | No wave |

Hidden-information analysis for the cues:
- `hold` and `night_choose` appear on every phone at the same time.
- Whether a cue shows depends on the device's history, never on the role.
- `vote_lock` is a public stage, so the cue there reveals nothing.

**Accessibility.**
- When `MediaQuery.accessibleNavigation` is on, each face is a button labelled "{target}, hidden. Activate to show." Activating it shows the face for 5 s (on 04, until it is activated again), reads it aloud, and counts as learned.
- Face text is left out of semantics except on that explicit activation.
- Night cards and vote rows are selectable buttons labelled with a name, "You", "Left", "Middle" or "Right". The board's spoken headline is the same on every phone.
- Reduce motion: the ring, the wave, the count flip and the timeline animation become static or instant.
- At text scale 2.0, the board wraps to rows of at most 4 cards and names ellipsize. Faces cap their own text scale at 1.6.

## 3. Screens

### The night, second by second

Shared rules for every phone at night:
- Each phone draws the board from the player list in seat order (its own seat captioned "You"), followed by "Left", "Middle", "Right". It never draws from `valid_targets`.
- A tap shorter than 120 ms toggles a pick. You can pick up to 2 cards; a third tap replaces the oldest; tapping a chosen card unchooses it.
- Nothing flashes, nothing is refused, and there is no haptic or sound.
- Every request and response is the same for every role, as shown in the tables.

**Look stage** (window 0, `card_look_seconds` 30)

| Moment | What every phone shows | Held face | What the phone sends |
|---|---|---|---|
| Deal commits | 04: a face-down card, "Your card", "Ready" locked, pips "0 of {n}" | Role text, no cap | Opening event, then `GET /me` |
| A 0.8 s reveal | "Ready" turns amber | same | nothing |
| Ready tapped | "Ready ✓" (disabled); the pips update on every phone | same | `POST ready {true}` |
| Everyone present is ready, or the 30 s backstop fires | Every phone goes to 06 in the same broadcast. A phone still unrevealed goes too; the role text is on its "You" face. | — | `GET /me` |

**Window 1** (only when the Doppelganger card is in the deck, dealt or in the center; fixed length, Copy = 15 s)

| Moment | What every phone shows | Held face of "You" | What the phone sends |
|---|---|---|---|
| Opens | 06: "The village sleeps", the board, Choose locked, candle | The dealt role name, then the instruction. Doppelganger: "Copy 1 player's card." Everyone else: "Nothing to choose. Tap any card." | `GET /me` |
| "You" held 0.8 s and at least 1 pick | Choose turns amber: "Choose {cards}", or "Keep my card" when only "You" is picked | same | nothing |
| First Choose | The picks clear and Choose locks again (hold "You" 0.8 s again, every phone) | Doppelganger, once her result arrives: "You copied {name}.", the copied role's portrait, then its window-1 instruction (from the instruction table below) or "Nothing to choose. Tap any card." Everyone else: unchanged | `POST choose {picks}` → the same 200 for everyone |
| Second Choose | The picks stay lifted; the button reads "Chosen" | unchanged | `POST choose {picks}` → the same 200 for everyone. The server ignores it unless it is the Doppelganger's follow-up |
| Fixed deadline | Every phone goes to the window-2 board at the same moment. No 07 appears in window 1. | — | `GET /me` |

**Window 2** (always runs; closes when every present phone has chosen once, but no sooner than 8 s; otherwise at the deadline)

| Moment | What every phone shows | Held face of "You" | What the phone sends |
|---|---|---|---|
| Opens | A fresh board, Choose locked | Page 1: the role name and the instruction. Page 2, on every phone whenever window 1 ran: the window-1 result (Doppelganger: "You copied {name}." plus her follow-up result; everyone else: "You slept.") | `GET /me` |
| Hold, taps, Choose | As in window 1, then "Chosen" with the picks lifted. The board stays. | same | one `POST choose` → the same 200 for everyone |
| Window closes | Every phone shows 05 until 07's data has loaded (under 1 s), then 07 | — | `GET /me` |
| Timeout with no Choose | The same transition | — | nothing; the server applies the timeout (a Drunk gets the seeded swap) |

**What you saw** (after window 2 only)

| Moment | What every phone shows | Held face | What the phone sends |
|---|---|---|---|
| Opens | 07: a face-down card, "What you saw", "Done" locked | One page (the 07 faces table), 5 s cap | — |
| A 0.8 s reveal and 4 s since 07 opened | "Done" turns amber | same | — |
| Done | The screen for the current phase (08, or later) | — | `POST night-results/seen {len(night_results)}` |

**Drops and missed closes**

| Moment | That phone | Every other phone | Sends |
|---|---|---|---|
| Socket lost | A "One moment" banner | No change, no name. The server waits up to 25 s grace for this phone, whatever its role. | — |
| Back inside the same window | The same screen. Picks are kept while the app stays open. After a cold start: re-hold "You" (any role). | — | `GET /me` |
| Back after a close | 07 for any results past `night_results_seen`, then the current phase. In results phase it skips straight to 10. | — | `GET /me` |
| Missed the close event | 2 s after the local deadline it fetches, then follows the phase | — | `GET /me` |

**How the server reads a `choose`.** It takes the first valid action in tap order. "You" is never a valid target.

| Prompt | The pick means |
|---|---|
| Seer | The first two picks are both center cards → look at both. Otherwise, the first other player → look at that card. Otherwise → skip. |
| Robber | The first other player → swap. Otherwise → skip. |
| Troublemaker | The first two picks are two other players → swap them. Otherwise → skip. |
| Drunk | The first center card → swap. Otherwise → the server's seeded swap. |
| Lone Werewolf | The first center card → look. Otherwise → skip. |
| Doppelganger's look | The first other player → copy. Otherwise → no copy (handled as a timeout). |
| Doppelganger follow-up | As the copied role. A follow-up with no choice runs automatically. |
| No choice | Sleep. |

**Trade-off, stated plainly.** A pick that holds no valid action for your role does nothing, and 07 says so truthfully ("You did nothing."). A Seer who taps Cleo and then Left looks at Cleo. A Drunk who keeps their card is still swapped, as the rules require.

### Night instructions (face of "You")

| Prompt | Line (words) |
|---|---|
| No choice | "Nothing to choose. Tap any card." (6) |
| Seer | "Look at 1 card, or 2 center cards." (6) |
| Robber | "Swap with 1 player. See your new card." (7) |
| Troublemaker | "Swap 2 other players' cards." (4) |
| Drunk | "Swap with 1 center card. Don't look." (6) |
| Lone Werewolf | "You may see 1 center card." (5) |
| Doppelganger's look | "Copy 1 player's card." (3) |

### Role text (single source for the 04 face, 03b and the role name on faces)

Every role entry is laid out as: tag; "Night:" line; "Wins:" line; then the shared line **"You are your last card. Anyone may lie."** (8 words).

Village line: **"A Werewolf dies. No Werewolf player: nobody dies."** (6 words)

| Role | Tag | Night: | Wins: | Total words |
|---|---|---|---|---|
| Werewolf | Werewolf | See the other Werewolves. Alone: you may see 1 center card. | No Werewolf and no Tanner dies. | 23 |
| Minion | Werewolf | See the Werewolves. They don't see you. | With the Werewolves, even if you die. No Werewolf player: someone else dies, not the Tanner. | 29 |
| Mason | Village | See the other Mason. | Village line | 20 |
| Seer | Village | Look at 1 player's card, or 2 center cards. | Village line | 24 |
| Robber | Village | Swap with a player. See your new card. | Village line | 25 |
| Troublemaker | Village | Swap 2 other players' cards. Don't look. | Village line | 23 |
| Drunk | Village | Swap with a center card. Don't look. | Village line | 24 |
| Insomniac | Village | At dawn, see your own card. | Village line | 23 |
| Hunter | Village | Sleep. If you die, your pick dies. | Village line | 24 |
| Villager | Village | Sleep. | Village line | 18 |
| Tanner | Alone | Sleep. | You die. | 14 |
| Doppelganger | Copies | Copy a player's card. Act as that role. | As the role you copy. | 24 |

**Team tags** on 10 and 11 come from the server's `team`: `village` → "Village", `werewolf` → "Werewolf", `neutral` → "Alone".

**Where I chose brevity over precision** (each string was checked against `roles.md` and `voting-and-resolution.md`):
1. "You are your last card": for a Doppelganger card, "your card" means the role she copied. Her own line says this.
2. Doppelganger "Act as that role": a copied Werewolf, Mason or Insomniac acts later, not at once.
3. Minion: the rules do not cover "the Tanner and another player die" when no Werewolf is a player. The engine decides that case.
4. Hunter "your pick": an unlocked pick counts too (contract amendment), so "pick" is exact.
5. Insomniac "At dawn": this is the end of window 2.
6. "Keep my card" is not true for a Drunk (see the trade-off above).
7. Robber and Drunk carry the Village line, because the shared line covers their change of team.

### 07 faces (and the window pages in 08)

Every face has exactly one portrait slot and at most 2 lines.

| Result | Portrait | Text (words) |
|---|---|---|
| Seer, player | That card | "{name}'s card: {role}." (1) |
| Seer, center | The first card | "{pos}: {role}. {pos}: {role}." (0) |
| Robber or Insomniac | The new card | "Your card now: {role}." (3) |
| Troublemaker | Moon | "You swapped {name} and {name}." (3) |
| Drunk (chosen or seeded) | Moon | "{pos} is yours now. Unseen." (4) |
| Werewolves | Werewolf | "Werewolves: {names}." (0) |
| Lone Werewolf | Werewolf | "Only you." plus "{pos}: {role}." if it looked (2) |
| Minion | Minion | "Werewolves: {names}." or "No Werewolves." (1) |
| Masons | Mason | "Masons: {names}." or "Only you." (2) |
| Acted, but no valid pick | Moon | "You did nothing." (3) |
| No choice, or timeout | Moon | "You slept." (2) |

### Per-screen sheet

**01 Join**
- **One thing / loudest:** type a name; the empty name field, focused.
- **Locked until:** both buttons stay locked until a name is entered.
- **Copy:** hint "Your name"; "Start a table" and "Join a table", outlined and of equal weight. "Join a table" opens a hint "Code" and an amber "Join". Body text at 16 px: "{n} at tables" and "You won last game" / "You lost last game". **14 of 14 words.**
- **Removed:** the prefilled "Ana" (8). The amber "Start a table" (4). The tagline. The footer (12).
- **States:**
  - Opened from a link: the name field and an amber "Join" (3 words).
  - The name is prefilled only from this device's own guest account.
- **Pass:** "Type my name."

**02 Table**
- **One thing / loudest (host):** guests scan. Loudest is the QR code for `/join/{code}`, with the code printed under it.
- **Locked until:** "Deal to {n}" unlocks at 3 or more players.
- **Copy (host):** "Scan to join"; quiet "Share" (opens the system share sheet); deck strip with count badges "2"; quiet "Edit deck"; amber "Deal to {n}", or disabled "Need 3 players". With a custom deck that does not match the player count: disabled "Add {n} cards" / "Remove {n} cards". **7 of 7 words.**
- **Copy (guest):** "{host} deals"; the code in small type; quiet "Leave". **2 words.**
- **Removed:** "Table code", "At the table", "5 players", "Host · You", "8 cards", "x2", "Change" (10, 12, 15).
- **States:**
  - Your own row has a thicker outline.
  - A dropped member's token dims to 40%, with no words.
  - After a host handover, that phone switches to the host layout, with no words.
- **Pass:** guest says "Wait or scan"; host says "Show the code, then deal".

**03 Deck** (host, optional)
- **One thing / loudest:** nothing is required; amber "Use this deck".
- **Locked until:** amber only while the deck holds exactly players + 3 cards.
- **Copy:** "Tonight's deck"; chips "Simple", "Classic", "Chaos"; chips "Quick", "Normal", "Long"; tiles "Talk", "Vote", "Night", "Copy" ("Copy" only when the Doppelganger is in the deck). A tile opens a stepper with the tile name and "Done". Button "Use this deck", or disabled "Add {n} cards" / "Remove {n} cards". **15 of 15 words.**
- **Removed:** "8 of 8 cards", the help line, "Double", and the role-sheet cue (10, 12).
- **States:**
  - The deck stays automatic (a chip) until a card is edited; then it is custom and no chip is selected.
  - Tapping a chip returns the deck to automatic.
  - Holding a portrait opens 03b.
- **Pass:** "Use this deck."

**03b Role sheet**
- **One thing / loudest:** read it; portrait and name.
- **Copy:** the role text plus "Close". **At most 30 of 30 words.**
- **Removed:** "Take out of deck" (16), "Good with", "Acts at night".
- **States:** opens by holding any role card (03, the 02 strip, the 08 strip).
- **Pass:** "Read, then Close."

**04 Your card**
- **One thing / loudest:** hold the card; a face-down card at 60% of the screen height.
- **Locked until:** "Ready" unlocks after a 0.8 s reveal.
- **Copy:** "Your card"; "Hold" (as the cue); "Ready" then "Ready ✓"; pips "{d} of {n}". Held face: the role text. **34 of 34 words.**
- **Removed:**
  - The card arriving face up, and "Holding…" (3).
  - "I know my card" being loud (4).
  - Token pips (9).
  - The host's "Don't wait": the 30 s backstop covers it.
- **States:** see the look stage table; a phone still unrevealed when the night opens goes to 06 with the others.
- **Pass:** "Hold the card."

**05 Night, between**
- **One thing / loudest:** wait; the candle.
- **Copy:** "The village sleeps". **3 of 3 words.**
- **Removed:** "Tap the cards…" (7). "Waiting for Dev…" (6). The 05 screen after a Choose: the board now stays.
- **States:** shown only from a window's close until 07 has loaded, and on a cold start during the night while `/me` loads.
- **Pass:** "Wait."

**06 Night board**
- **One thing / loudest:** hold "You", tap a card, then Choose; the board.
- **Locked until:** Choose needs 1 or more picks and a 0.8 s hold of "You" in this window.
- **Copy:** "The village sleeps"; captions "You", "Left", "Middle", "Right"; candle and number. Button: "Choose a card" (disabled), then "Choose {cards}" or "Keep my card", then "Chosen". "Hold" appears on "You" only as a cue. Held face: role name, instruction, window-1 page. **20 of 20 words.**
- **Removed:**
  - The pre-selected Cleo (2).
  - "Your turn · Seer" and the role portrait (14).
  - "Do nothing tonight" (16): keeping your own card replaces it.
  - "Look at Cleo's card" (14).
- **States:** see the window tables. Two center cards (11): "Choose Left, Right" shows exactly what will be sent.
- **Pass:** "Hold You, tap a card, Choose."

**07 What you saw**
- **One thing / loudest:** hold the card; a face-down card.
- **Locked until:** "Done" unlocks after a 0.8 s reveal and 4 s since 07 opened.
- **Copy:** "What you saw"; "Done". Held face: the 07 faces table. **8 of 8 words.**
- **Removed:** "You looked at Cleo's card" (14). "Done" being loud before holding (4). Token pips (9).
- **States:** see the "What you saw" table.
- **Pass:** "Hold the card."

**08 Talk**
- **One thing / loudest:** talk. On the phone, the sun timer is loudest, then "My night".
- **Locked until:** "Ready to vote" stays outlined (never amber) and unlocks once My night has been held this game.
- **Copy:** "The village wakes"; timer digits; "My night"; deck strip; pips "{d} of {n} ready"; "Ready to vote", then "Ready ✓" (tap again to undo). My night pages, the same count on every phone: "Dealt: {role}"; the window-1 page if window 1 ran; the 07 face. **15 of 15 words.**
- **Removed:** "Left to talk", "Hold to peek", "In the deck tonight" (12). A loud ready button (4, 19). Tokens on the pips (9).
- **States:**
  - Never paused. No host button. No dropped-player copy.
  - Holding a deck portrait opens 03b.
- **Pass:** "Talk; hold My night."

**09 Vote**
- **One thing / loudest:** pick a name; the rows.
- **Locked until:** the button is disabled until a pick is made.
- **Copy:** "Who dies today?"; "Pick a name", then "Lock in {name}" (with a padlock glyph), then "Locked"; pips "{d} of {n} locked"; timer digits and bar. **8 of 8 words.**
- **Removed:** the pre-selected Cleo (2). The red X and the blood fill (5). Tokens on the pips (9). "Seconds to choose" (12). The ink button (18). The host's "Don't wait".
- **States:**
  - Your own row is never listed.
  - The picked row lifts and gets an ink outline. Tapping another row moves the pick.
  - After locking, every row looks the same and dims equally.
  - Normal pace gives 90 s (17).
- **Pass:** "Tap a name, then Lock in."

**10 The count**
- **One thing / loudest:** watch; the dead player's card.
- **Locked until:** "See who won" unlocks when the flips end.
- **Copy:**
  - Headline: "{name} dies." / "{names} die." / "Nobody dies.", and then "{name} dies too." for the Hunter.
  - When nobody dies: "Nobody got 2 or more votes."
  - Rows: accused name, count, and the voter names at 16 px. Then "No vote: {names}".
  - Cards: "Now" (`final_role`), plus "Dealt" with an arrow when the dealt card differs; team tag.
  - Button: "See who won".
  - **16 of 16 words.**
- **Removed:** "Dev was the" (1). "The count", "Accused", "Voted by", the voter tokens (9, 12).
- **States:**
  - The rows land with a 150 ms stagger, then a 1.2 s pause, then the flip (400 ms), on every phone at once.
  - When `final_role` is Doppelganger and the timeline has a `copy` step, the Now card shows the copied role, captioned "Doppelganger".
  - The Now card uses the same source as the results, so the two screens cannot disagree (1).
  - The Dealt→Now arrow is how a newcomer learns that cards moved.
- **Pass:** "See who died, then See who won."

**11 Results**
- **One thing / loudest:** read who won; the headline and "You won." / "You lost.".
- **Copy:**
  - Headline: "The village wins" / "The Werewolves win" / "The Tanner wins" / "The village and the Tanner win" / "The Werewolves and the Tanner win" / "Nobody wins".
  - Timeline rows: listed separately below.
  - Final row: "Won" / "Died". Then "Center: {roles}".
  - Host: amber "Play again", quiet "Edit deck". Guest: "{host} deals next.", quiet "Leave".
  - **13 of 13 words.**
- **Removed:** "Cleo held the Robber" (1). The footnote (12). "Change the deck".
- **States:** the timeline always animates (600 ms per row, or instant with reduce motion), and a tap finishes it. A wolf glyph heads the red line.
- **Pass:** host says "Play again"; guest says "Wait or Leave".

**Timeline rows on 11** (prefix "{role}:"; a Doppelganger follow-up uses the prefix "Doppelganger · {copied}:")

| Step | Row (words) |
|---|---|
| Copy | "{a} copies {b}." (1) |
| Werewolves | "{names} see each other." or "{name} wakes alone." (3) |
| Masons | "{names} see each other." or "{name} wakes alone." (3) |
| Minion | "{a} sees {names}." or "{a} sees no Werewolf." (2) |
| Seer, player | "{a} sees {b}'s card." (2) |
| Seer, center | "{a} sees {pos}, {pos}." (1) |
| Lone Werewolf | "{a} sees {pos}." (1) |
| Robber | "{a} takes {b}'s card." (2) |
| Troublemaker | "{a} swaps {b} and {c}." (2) |
| Drunk | "{a} takes {pos}." (1) |
| Insomniac | "{a} sees own card." (3) |
| Skip | "{a} does nothing." (2) |

### Banners and errors (6 words maximum each)

| Situation | Copy |
|---|---|
| `lobby_not_found` | "No table with that code." |
| `lobby_full` | "That table is full." |
| `lobby_closed` | "That table is playing now." |
| `already_in_lobby` | "You're at another table." + "Go there" |
| The table was closed | "This table has closed." + "Go home" |
| A request failed | "Not sent." + "Try again" |
| This phone is offline, any phase | "One moment" |
| Storage was wiped mid-game | "You left this game." + "Go home" |

### Deck chips (each chip uses players + 3 cards; WW means 2 Werewolves; the server builds the deck at the deal)

| Players | Simple | Classic | Chaos |
|---|---|---|---|
| 3 | WW, Seer, Robber, Troublemaker, Villager | = Simple | WW, Seer, Robber, Troublemaker, Drunk |
| 4 | WW, Seer, Robber, Troublemaker, Villager ×2 | = Simple | WW, Seer, Robber, Troublemaker, Drunk, Tanner |
| 5 | WW, Seer, Robber, Troublemaker, Villager ×3 | WW, Seer, Robber, Troublemaker, Drunk, Insomniac, Villager | WW, Minion, Seer, Robber, Troublemaker, Tanner, Villager |
| 6 | WW, Seer, Robber, Troublemaker, Insomniac, Villager ×3 | WW, Minion, Seer, Robber, Troublemaker, Villager ×3 | WW, Seer, Robber, Troublemaker, Drunk, Insomniac, Tanner, Villager |
| 7 | WW, Seer, Robber, Troublemaker, Drunk, Insomniac, Villager ×3 | WW, Minion, Seer, Robber, Troublemaker, Mason ×2, Drunk, Insomniac | WW, Minion, Tanner, Seer, Robber, Troublemaker, Mason ×2, Insomniac |
| 8 | 7's Simple + Hunter | 7's Classic + Villager | 7's Chaos + Villager |
| 9 | WW, Seer, Robber, Troublemaker, Drunk, Insomniac, Mason ×2, Villager ×3 | WW, Minion, Tanner, Hunter, Seer, Robber, Troublemaker, Mason ×2, Drunk, Insomniac | Doppelganger, WW, Minion, Seer, Robber, Troublemaker, Mason ×2, Drunk, Insomniac, Tanner |
| 10 | 9's Simple + Hunter | 9's Classic + Villager | 9's Chaos + Villager |

- Classic and Chaos are the rows of `recommended-setups.md`; this table is added to that file.
- **Deviation from the ruling:** Simple cannot avoid Masons at 9 and 10 players. Without Minion, Masons, Tanner and Doppelganger, the largest legal deck is 11 cards (2 Werewolves, Seer, Robber, Troublemaker, Drunk, Insomniac, Hunter, 3 Villagers), which only covers 8 players. The Mason pair is the gentlest addition; `recommended-setups.md` advises Masons from 8 players.

### Brief amendments (same commit)

| `design-brief.md` | Amended to |
|---|---|
| §2: amber on the "primary button only" | One amber fill per screen, with a 2 px ink outline on day grounds. Selection uses lift plus an outline. |
| §3.3: non-actors "get something to tap" | Every phone sends the same `choose`. |
| §4.5: night waiting screen | 05 only between a close and 07. |
| §4.6: a "do nothing" choice | "Keep my card", or any card that means nothing to your role. |
| §4.7: "Hides by itself" | Hold, a 5 s cap, and Done after a 0.8 s reveal and 4 s. |
| §4.8 My night: "You slept through the night." and lit tokens | "You slept." and plain pips. |
| §4.10: voters as tokens | Voters by name. |
| §4 type scale: "labels 12 uppercase, body 15 to 17" | 16 px for anything a player must read to act; 14 px for captions; no uppercase tracked labels on player screens. |
| §4: pace "Double" | "Copy". Normal Copy becomes 15 s. |
| §5.2: Werewolves and Masons may see their team when the window opens | Team shown only at 07. |
| §4.3: "Suggested decks" | The chips above, built by the server. |

## 4. Server needs

**(a) What each screen depends on in api-contract-v2.**
- S1, S2, S3, S8 and S9 are built.
- S4, S5, S6 and S7 are **not** built.

| Screen | Depends on |
|---|---|
| 01 | S9 (built), plus the join link (b7) |
| 02 | S1 and S2 (built), plus b6 |
| 03 | The S9 settings merge (built), plus b6 |
| 04 | S6 (look stage, `ready`, `progress`) |
| 06 | S7, as replaced by b1 to b5 |
| 07 | S3 ack (built) |
| 08 | S5 |
| 09 | S4 |
| 10 and 11 | S8 and the existing results fields (built) |

**(b) New needs beyond the contract.** These replace the contract's `sleep` action, `sleep_prompt` and Rule B wording.

1. **`choose` action.** `POST .../action/ {"action_type":"choose","picks":[{"player_id":14}|{"center_index":0}|{"self":true}]}`, with 0 to 2 distinct picks in order. The server interprets it per the "How the server reads a `choose`" table. Reason: the phone never decides what a pick means.
2. **Identical answers.** Every `choose` is answered `{"status":"submitted"}`. The only errors are `wrong_phase`, `already_chosen` (409) and malformed `bad_request`, and none of them depends on role. A pick that is invalid for the role is not an error. Test every role for byte-identical responses. Reason: responses must leak nothing.
3. **Choosing twice in window 1.** Window 1 accepts up to 2 `choose` from any phone and stays fixed-length. Window 2 accepts exactly 1, and its all-tap close counts `choose` submissions. Reason: every phone may Choose twice, so the Doppelganger's follow-up is not a tell.
4. **Doing nothing.** A lone Werewolf with no center pick, and a Doppelganger look with no other-player pick, both resolve as skip or timeout. A Drunk with no center pick gets the seeded swap (`made_by_server: true`). Reason: "Keep my card" must be valid for every role.
5. **Window opening.** Every phone gets the same group event `night_window {window, deadline}` in one after-commit batch. Each phone then reads its own prompt from `/me`; there are no per-role prompt events. Reason: identical traffic and timing.
6. **Automatic deck and defaults.**
   - Lobby settings carry `deck: "auto"` and `deck_chip: "simple"|"classic"|"chaos"` until the host edits cards. The deal builds the deck from the chips table for the current player count, under the Lobby lock.
   - At lobby create the server writes the defaults: Normal pace, `card_look_seconds` 30, and Normal `night_doppelganger_window_seconds` 15.
   - Reason: this removes the client writer and its races.
7. **Join link.** The web deployment serves the app for `/join/*` (a Vercel rewrite) and the app knows its public origin for the QR code. Reason: finding 15.

## 5. Build order hooks

1. `LearnedStore` (`mv.learned.v1.*`, with a reset in /debug).
2. `TeachOnce(id, cue)`, plus a locked gate that replays its cue for 3 s.
3. `HoldToReveal` timings: 120 ms, caps per screen, 0.8 s, a 2 s double tap, and the accessible activate.
4. `HeldFace` frame: fixed size, duotone portrait, pages, drawn above the thumb, text scale capped at 1.6.
5. `copy.dart` holding every string, plus `copy_budget_test.dart`: budgets, banned list, headlines, buttons, the single question, and the amber count.
6. `RoleText`: one table that feeds RoleCard, 03b and faces.
7. `NightBoard`: built from the player list, taps, and the `choose` payload.
8. **A night uniformity test**: drive every role through the look stage, window 1, window 2 and 07, and assert that the non-held widget trees, the transition times and the requests are identical.
9. QR code, the `/join/:code` route, and the share sheet.
10. Cold-read pack exported from `just screens` (host, guest, sleeper and Seer journeys).

## 6. Open risks

1. **A screen reader speaks the held face aloud**; only earphones prevent it.
2. **"Lock in {name}" is readable by a neighbour before the lock.** It was kept because naming the person tested well.
3. **The first-valid-action rule can surprise a newcomer** (a Seer who taps a player, then the center). 07 tells them the truth afterwards.
4. **A 15 s window 1** (hold, choose, hold, choose) is tight for the Doppelganger. Simple decks leave her out.
5. **Faces can still be read from the side up close.** The fixed frame removes the shape tell, but not the words.

## 7. Amendment: stages are named; nothing waits (20 November 2026)

Found by the review of the server build. These override the text above.

**Every stage-scoped request names its stage.** `/me/` carries an opaque `stage` string that
changes whenever the thing a tap would mean changes (the look stage, window 1, window 2, the
talk, the vote, each tied to the game so an old one can never match). `choose`, `ready`, `vote`
and the host's advance send it back; a request for a stage that has passed is answered
`409 wrong_stage`, the same for every role, and does nothing. A late tap can therefore never
land in the next stage (a Robber's late window-1 tap used to rob someone in window 2).

**No delays, and no assumed lengths.** Nothing in this spec adds a wait or a minimum response
time, and no timer value is assumed: every length is the table's own setting, the defaults are
the server's existing ones, and the pace presets leave the Doppelganger's time alone (the
"Copy" tile changes it). Where this spec says "15 s", "20 s" or "Normal Copy", read "the
table's setting".

**Window 1 is as in section 3** (one fixed-length window, every phone may Choose twice, the
Doppelganger's look resolves the moment she chooses). Two rules close what the review found:

- **The phone never waits for the answer to change what others can see.** On Choose the picks
  clear and the button locks at once, on every phone, before the response arrives. What the
  answer brings (her copied role, a result) only ever appears on a held face. So a slower
  answer for one role is invisible at the table. The server keeps the difference small (it
  does the same reads for every role and writes only what changed); the remainder is visible
  only to someone timing the network, which is outside what this app defends against.
- **One look.** The Doppelganger's first Choose in window 1 is her look whatever it holds. If
  it holds no other player she has not copied, and her second Choose does nothing, like
  everyone else's.

**Votes:** under the new night the server never announces who locked, only the count.
