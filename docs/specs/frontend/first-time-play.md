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
   | Budget | 14 | 7 | 15 | 30 | 34 | 3 | 24 | 8 | 15 | 8 | 16 | 13 |

   On 11, each timeline row is also capped at 3 words.
3. **Headlines.** One headline per screen, at most 5 words.
4. **Buttons.**
   - A button label is 1 to 3 words: a verb, naming the person or card when there is one. A night button says what will happen with the picks ("See Cleo", "Swap Ana, Ben"), and a pass button is true for its role (rule 11).
   - A disabled button that is waiting for input names what is missing ("Pick a name", "Need 3 players", "Add 2 cards").
   - A gate button keeps its label while locked: "Ready", "Done", "Ready to vote", "See who won". The night board's Choose waits for a whole pick ("Choose a card", "Choose 1 more").
   - After the action, the button shows the state in one word and stays disabled: "Chosen", "Locked", "Ready ✓".
5. **Where rules are stated.** Rules appear only in the role text (cards and 03b) and on the night face of "You". Every other screen states facts only, for example "Nobody got 2 or more votes."
6. **Gestures are never explained in text.** The only exception is the one-word cue "Hold".
7. **Reading floor.**
   - 16 px minimum, at text scale 1.0, for anything a player must read in order to act.
   - 14 px minimum for captions under cards and tokens.
   - Contrast of at least 4.5:1; words that say something true or are read to follow the game ("✓ Nothing to do", "✓ Locked", every count, "Now" and "Dealt" on 10, the night on 11, a quiet "Leave") in full ink, not the quiet one (playtest, 21 November 2026: "small and pale"). Counts are set larger than body text (17, bold).
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
11. **Which, how many, where** (issue 37: "See 1 or 2 cards is ambiguous"). A reviewer applies this to every night title, button and pass. Cover the face of "You" and read the title together with the labels on the board: can the player say which cards, how many, and from where, in words a card or label on the board also carries?
    - The board's words: a player's name (so "player"), "You", "Center", "Left", "Middle", "Right", the Seer's three labels ("1 player", "or", "2 center cards"), and the game's own nouns "card" and "role" (a held face names a role).
    - A title fails if it uses a word no card or label shows ("table", "deck", "pile"), or if the role may pick two kinds of card and neither the title nor the board's labels name both ("See 1 or 2 cards": which cards?). A title may leave the which, how many and where to the board when the board says them where the cards are: the Seer's does ("Look at cards", with "1 player" over the seats, a rule with "or" and "2 center cards" on the strip). The owner chose that on 22 November 2026, knowing hers is the one board that carries labels the others do not.
    - The screen carries what it can before a word does: once a pick has begun, a card it cannot take is dimmed, from the server's `shapes`; before the first tap the board is identical for every role (section 3, "The board's title").
    - A pass button must be true for its role. "Keep my card" is the Robber's alone (the one role whose pass leaves their card where it was). A Drunk who passes is still swapped, so his says "Choose for me". Every other actor's says "Skip".
    - No question marks: "Who dies today?" stays the only question (rule 9).

## 2. The teach-once cues

**Storage.** Each learned cue is stored with `shared_preferences` (localStorage on the web) under the key `mv.learned.v1.<id>`, value `"1"`.

**Cue versus gate.** A cue is animation plus the word "Hold", and it is taught once. A gate is a game rule ("the exit stays locked until the thing is done") and applies in every game, on every phone.

**Tapping a locked gate** replays that screen's cue for 3 s on any device. This covers a newcomer using a phone that has already learned. A cue never adds waiting time: an experienced player on a new device only pays the gate itself, which is a 0.8 s hold or one tap.

**HoldToReveal timing.**
- The face shows 120 ms after the press and hides on release.
- On 06 ("You"), 07 and 08 the face hides after 5 s even if still held. 04 has no cap: everyone is on 04 at the same time, and the stage ends on everyone's Ready.
- A reveal counts once it has been visible for at least 0.8 s.
- A tap is never a reveal (review, 20 November 2026: the double tap is withdrawn, so a tap on "You" picks at once). The path without a hold is the accessible activate below.

**The held-face frame** is the same on every face: 04, "You" on 06, 07, and 08's My night.
- Always the same fixed size.
- Drawn above the touch point, never under the thumb.
- At most one portrait, in bone-on-indigo duotone (never red), taking 30% of the frame.
- Bone text, at most 2 lines.
- When a face has several pages, each new hold shows the next page, and page dots appear inside the frame.

**Hidden-information decision: everyone holds at the same beat.** 04 and 07 open on every phone at the same moment. On 06, every phone has to hold "You" before Choose unlocks. Every phone has a face, with the same frame and the same page count for that moment. A held thumb therefore only means "looking", and everyone looks.

| Cue (`id`) | First appears | What the player sees | Words | Unlocks | Learned when | Later games |
|---|---|---|---|---|---|---|
| `hold` | 04, the moment of the deal | A plain ring on the face-down card, "Hold" in it at 20 px, breathes (bone colour, scale 1.00 to 1.06, 1.4 s loop); while the card is held the ring fills, in the 0.8 s a reveal takes to count (no thumbprint: product owner, 20 November 2026). Taught once: the same ring is on "You" (06) and My night (08) only on a device that has never held a face (playtest, 21 November 2026: one lesson, not three) | "Hold" | "Ready" turns amber after a 0.8 s reveal | The first 0.8 s reveal on any face | Nothing: the card is a card |
| `night_choose` | 06, the first window of the first game | When the board opens, each card lifts 8 px in a single left-to-right wave (120 ms each, 90 ms stagger) | none | — | The first successful `choose` | No wave |
| `vote_lock` | 09, the first vote | The rows nudge 6 px in a single wave | none | — | The first successful lock | No wave |

Hidden-information analysis for the cues:
- `hold` and `night_choose` appear on every phone at the same time.
- Whether a cue shows depends on the device's history, never on the role.
- `vote_lock` is a public stage, so the cue there reveals nothing.

**Accessibility.**
- When `MediaQuery.accessibleNavigation` is on, each face is a button labelled "{target}, hidden. Activate to show." Activating it shows the face for 5 s (on 04, until it is activated again), reads it aloud, and counts as learned.
- Face text is left out of semantics except on that explicit activation.
- Night cards and vote rows are selectable buttons labelled with a name, "You", "Left", "Middle" or "Right". The board's spoken headline is its title: the prompt's (section 8, accepted tells).
- Reduce motion: the ring, the wave, the count flip and the timeline animation become static or instant.
- With large text the board's words grow to 1.3 times and its button's to 1.6; names are never cut (they wrap between words, or the board takes fewer cards to a row). Faces cap their own text scale at 1.6.

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
| Opens | 06: "The village sleeps", the board, Choose locked, candle | The dealt role name, then the instruction. Doppelganger: "Copy 1 player's card." Everyone else: "Nothing to do tonight." (section 8) | `GET /me` |
| "You" held 0.8 s and at least 1 pick | Choose turns amber and says what will happen: "See Cleo", "Swap Ana, Ben", "Copy Cleo", or the role's pass ("Skip") when only "You" is picked | same | nothing |
| First Choose | The picks clear and Choose locks again (hold "You" 0.8 s again, every phone) | Doppelganger, once her result arrives: "You copied {name}.", the copied role's portrait, then its window-1 instruction (from the instruction table below) or "Nothing to do tonight." Everyone else: unchanged | `POST choose {picks}` → the same 200 for everyone |
| Second Choose | The picks stay lifted; the button reads "Chosen" | unchanged | `POST choose {picks}` → the same 200 for everyone. The server ignores it unless it is the Doppelganger's follow-up |
| Fixed deadline | Every phone goes to the window-2 board at the same moment. No 07 appears in window 1. | — | `GET /me` |

**Window 2** (always runs; closes when every present phone with a choice has chosen once (section 8), but no sooner than the table's minimum; otherwise at the deadline)

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
| Back after a close | 07 for any results past `night_results_seen`, then the current phase. In results phase it lands on 10, or on 11 if this phone had already gone on to it (kept on the device). | — | `GET /me` |
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
| No choice | "Nothing to do tonight." (4; section 8: a phone with nothing to choose is asked nothing, "Nothing to do" quiet where the button was) |
| Seer | "Look at 1 player's card, or 2 center cards." (7; cold read: "1 card" did not say whose) |
| Robber | "Swap with 1 player. See your new card." (7) |
| Troublemaker | "Swap 2 other players' cards." (4) |
| Drunk | "Swap with 1 center card. Don't look." (6) |
| Lone Werewolf | "You may see 1 center card." (5) |
| Doppelganger's look | "Copy 1 player's role." (3; agrees with her title) |

**The board's title** (06's headline, two lines of room on every phone) is the prompt's: the role's night line in a few words on a phone with a choice, "The village sleeps" on a sleeper's (playtest, 21 November 2026: "The village sleeps" read as wrong while acting). Seer "Look at cards" (3; her board says the rest, below); Robber "Swap with 1 player" (3); Troublemaker "Swap 2 other players' cards" (4); Drunk "Swap with a center card" (4); Lone Werewolf "See 1 center card" (3; its "Skip" carries the "may"); Doppelganger's look "Copy a player's role" (4). Each passes rule 11 in section 1. The face of "You" says the rest.

**The Seer's board names her two kinds of pick where they are** (the owner chose this on 22 November 2026, from "A: the title says it" and "B: the board says it"): "1 player" above the seats, a thin rule with "or" between the seats and the table's cards, and "2 center cards" on the strip in place of "Center"; the same buttons. The board's geometry is the same for every role: every board keeps the room above its seats and in the gap above the band for these words and leaves it empty (`BoardLayout.seatLabelRoom`, `ruleRoom`), so no card sits elsewhere on any phone. What gave: the row gap and the band's padding are 4 px tighter on every board, and the header's gap to the board is the label room; the table's cards and "You" reach 8 px down into the band's padding for a tap (`FaceDownCard.tapExtra`), so on the smallest phone with ten players (320 x 568) every tap target stays 4 px over the 48 px floor (`board_sweep_test.dart`). A Seer's board shows two labels the others do not: an accepted tell (the Seer's title already told).

**The board shows what can be picked** (issue 37). **The board is identical for every role until the first tap: nothing is dimmed.** Once a pick has begun, a card that cannot join it is dimmed (the card back and token; its name stays in full ink), read from the prompt's `shapes` only, and a tap on a dimmed card still switches the pick (a screen reader hears "Switches your pick": dimmed here is not switched off, as it is on the vote's locked rows). The strip of the table's three cards carries the word "Center".

| Prompt | At the start | After the first pick |
|---|---|---|
| Robber, Doppelganger's look | Nothing dims | One player: the center and the other players dim |
| Troublemaker | Nothing dims | One player: the center dims; two: the other players dim too |
| Drunk, lone Werewolf | Nothing dims | One center card: the players and the other two center cards dim |
| Seer | Nothing dims | One player: everything else dims. One center card: the players dim, the other two center cards stay lit. Two: the third dims too |
| A phone with nothing to choose | Nothing dims | Nothing dims |

"You" is never dimmed, and picking "You" alone leaves the board as at the start. The layout is the same for every role (section 8). Dimming at the start was tried and dropped: a dark block of players on a Drunk's phone is readable across the table, where before only the small title differed.

**A kind or shape the server adds later never throws in a player's hand**: an unknown prompt `kind` is the plain generic board ("Choose a card", then "Choose {cards}" or "Skip"), an unknown `shape` is left out (a prompt left with none takes any one card), and each is logged.

**The title has room for two lines at the full title size** on every board, the same height whatever the role, with the seconds level with its first line; it wraps between words and is set smaller only if two lines are not enough (a title is never drawn under 0.8 of the title size at 360 wide: `board_sweep_test.dart`).

| Prompt | Button with the picks whole | Pass ("You" alone) |
|---|---|---|
| Seer | "See {cards}" | "Skip" |
| Robber | "Swap with {cards}" | "Keep my card" |
| Troublemaker | "Swap {cards}" | "Skip" |
| Drunk | "Swap with {cards}" | "Choose for me" |
| Lone Werewolf | "See {cards}" | "Skip" |
| Doppelganger's look (and a follow-up, as the copied role) | "Copy {cards}" | "Skip" |

A name is never cut: if two long names do not fit on one line ("Swap Rosalind Fairweather, Bartholomew Longname" at 320 wide), the label wraps between words onto two lines, then is set smaller; the board takes the height.

### Role text (single source for the 04 face, 03b and the role name on faces)

Every role entry is laid out as: tag; "Night:" line; "Wins:" line; then the shared line **"You are your last card."** (5 words; "Anyone may lie." was cut on review, 21 November 2026, so the card reads at full size on small phones).

Village line: **"A Werewolf dies. No Werewolf player: nobody dies."** (6 words)

| Role | Tag | Night: | Wins: | Total words |
|---|---|---|---|---|
| Werewolf | Werewolf | At dawn, see the other Werewolves. Alone at night: you may see 1 center card. | No Werewolf and no Tanner dies. | 24 |
| Minion | Werewolf | At dawn, see the Werewolves. They don't see you. | With the Werewolves, even if you die. No Werewolf player: someone else dies, not the Tanner. | 28 |
| Mason | Village | At dawn, see the other Mason. | Village line | 19 |
| Seer | Village | Look at 1 player's card, or 2 center cards. | Village line | 21 |
| Robber | Village | Swap with a player. See your new card. | Village line | 22 |
| Troublemaker | Village | Swap 2 other players' cards. Don't look. | Village line | 20 |
| Drunk | Village | Swap with a center card. Don't look. | Village line | 21 |
| Insomniac | Village | At dawn, see your own card. | Village line | 20 |
| Hunter | Village | Sleep. If you die, your pick dies. | Village line | 21 |
| Villager | Village | Sleep. | Village line | 15 |
| Tanner | Alone | Sleep. | You die. | 11 |
| Doppelganger | Copies | Copy a player's role. Act as that role. | As the role you copy. | 21 |

**Team tags** on 10 and 11 come from the server's `team`: `village` → "Village", `werewolf` → "Werewolf", `neutral` → "Alone".

**Where the team shows** (issue 37): the other Werewolves, the Minion's Werewolves and the other Mason are shown only at dawn, when the talk opens, on My night ("Werewolves were: {names}."; section 3, "Brief amendments": team shown only there), never at night; so these role texts say "At dawn", as the Insomniac's does, and a sleeper's night face says only "Nothing to do tonight." A lone Werewolf's center look is at night ("Alone at night").

**Where I chose brevity over precision** (each string was checked against `roles.md` and `voting-and-resolution.md`):
1. "You are your last card": for a Doppelganger card, "your card" means the role she copied. Her own line says this.
2. Doppelganger "Act as that role": a copied Werewolf, Mason or Insomniac acts later, not at once.
3. Minion: with no Werewolf player, `voting-and-resolution.md` (Minion special rules) has the Minion win when a player other than the Minion and the Tanner dies, and lose when only the Tanner dies; "someone else dies, not the Tanner" says that.
4. Hunter "your pick": an unlocked pick counts too (contract amendment), so "pick" is exact.
5. Insomniac "At dawn": this is the end of window 2.
6. "Keep my card" is not true for a Drunk (see the trade-off above): his pass reads "Choose for me".
7. Robber and Drunk carry the Village line, because the shared line covers their change of team.

### 07 faces (and the window pages in 08)

Every face has exactly one portrait slot and at most 2 lines. Each line is a fact of the night, in the past: what this phone saw or did then, never what a card is now, since cards move after a look (playtest, 21 November 2026: "Cleo's card: Werewolf." read at the talk as Cleo's card today). The Insomniac's is the one line still true at the talk: she looks last.

| Result | Portrait | Text (words) |
|---|---|---|
| Seer, player | That card | "{name}'s card was: {role}." (2) |
| Seer, center | The first card | "{pos} was: {role}. {pos} was: {role}." (2): the server names each card's place (`center_indices`, contract third amendment) |
| Robber | The new card | "You took {name}'s card: {role}." (3) |
| Insomniac | Her card | "Your card now: {role}." (3) |
| Troublemaker | Moon | "You swapped {name} and {name}." (3) |
| Drunk (chosen or seeded) | Moon | "You took {pos}, unseen." (3) |
| Werewolves | Werewolf | "Werewolves were: {names}." (1) |
| Lone Werewolf | Werewolf | "Only you." plus "{pos} was: {role}." if it looked (3) |
| Minion | Minion | "Werewolves were: {names}." or "There were no Werewolves." (3) |
| Masons | Mason | "Masons were: {names}." or "Only you." (2) |
| No choice, or timeout | Moon | "You slept." (2) |
| Chose, nothing happened (the viewer's own `skip`, marked `nothing_chosen`, also the Doppelganger's look with no other player; a Drunk's server-made swap and a lone Werewolf who looked at nothing keep their own rows) | Moon | "You did nothing." (3) |

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
- **One thing / loudest (host):** guests scan. Loudest is the QR code for `/join/{code}`. Two blocks: the QR code with "Scan to join" on it (its label only), and, past a hairline, the code with its own label "Code" (01's word for it) and Share. An app build that knows no web address has no QR code: no "Scan to join", the code block alone.
- **Locked until:** "Deal to {n}" unlocks exactly when the server says the deal would go (`deal.ok`); until then the same words, locked. At a table set for a number, {n} is that number; at an open table, the players here ("Need 3 players" under three).
- **Copy (host):** "Scan to join" (the QR code's label); "Code" (the code's); quiet "Share" (a glyph); at a number "{d} of {n}" with a small empty circle for each place not taken (one wrapping line, so the deck and Leave stay in view), above the rows; with 3 or more here but fewer than the number, "Play with {n}" (one tap sets the number to who is here; with a deck of the host's own, the tap opens 03 with its count showing, never throwing the deck away); the set-up: the deck chip, "Talk {length}", every role in the deck face up with count badges in the deck builder's order, in balanced lines (no card alone on a line); a deck that does not fit shows its count ("11 / 10", digits) to the host only, and tapping the set-up opens 03; quiet "Edit"; amber "Deal to {n}", or the same words locked, or "Need 3 players"; "Leave" shows it is on its way at once. **13 of 13 words.**
- **Copy (guest):** "{host} deals"; the same card, the same "{d} of {n}" and empty places, the same set-up face up (a tap or a hold on a role reads it); quiet "Leave". Waiting is said by the shape, not a sentence (playtest, 21 November 2026: Leave read as the one thing to do): "{host} deals" at the headline size (32; was the hero title, 46: the owner, 22 November 2026, found the names too big), "Leave" a quiet underlined word at the foot, no outlined button.
- **The deck is always face up** (owner, 21 November 2026: "everybody should see what characters have been selected"): the roles the table would deal, for host and guests, in every state; never card arithmetic, never "Add {n} cards" / "Remove {n} cards".
- **Removed:** "Table code", "At the table", "5 players", "Host · You", "8 cards", "x2", "Change" (10, 12, 15).
- **States:**
  - Your own row has a thicker outline.
  - A dropped member's token dims to 40%, with no words.
  - After a host handover, that phone switches to the host layout, with no words.
- **Pass:** guest says "Wait or scan"; host says "Show the code, then deal".

**03 Tonight's game** (host; the set-up page, editable before anyone joins and until the deal; amended 21 November 2026 after the owner got stuck in the deck editor, and after review)
- **One thing / loudest:** nothing is required; amber "Done".
- **Locked until:** never: "Done" is always live (the page holds the players and the lengths too; a host who changed only a timer is never stuck). A deck that does not fit is shown on 02, to the host, with Deal locked.
- **Copy:** "Tonight's game"; "Players" with a stepper (within the server's range: never below who is here, never above what the table holds; "Any", an open table, only with an automatic deck) and, at a number, "{d} of {n}" with every seat drawn; chips "Simple", "Classic", "Chaos"; at a number the cards picked over the cards needed ("7 / 11", digits) with a slot each, the players' then the centre's three; every role face up in a grid (names exempt), a tap puts one in, a lit card's minus takes one out (spoken "Take one {role} out"); every length the server has, each its name and a stepper over its value, in this order: "Talk", "Vote", "Night", the Doppelganger's (the role's name; the row is there only while the deck holds a Doppelganger), "Look", "Night minimum", "Dropped phone", "Host away"; values "{n} s", "{n} min"; 0 is "No clock" for the talk and the vote (no deadline: it ends when everyone is ready) and "Off" for the rest. Button "Done". **22 of 22 words.**
- **Removed:** the pace chips "Quick", "Normal", "Long" and their tiles (the owner: "I just need the things to be editable"), "Add {n} cards" / "Remove {n} cards" (the deck's state is the count and the slots, never words of direction), the face-down deck and "Edit" (the deck is always face up), "Use this deck" (now "Done").
- **States:**
  - The deck stays automatic (a chip) until a card is changed; then it is the host's own, from the cards shown, for the number (an open table takes who is here, at least 3), and no chip is selected. Tapping a chip returns it to automatic.
  - Every change is saved as it is made; a new table shows the server's own lengths. What shows while a change is on its way is the server's state with only that change taken from the phone. A change the server refuses (the table moved under it) is dropped and the page read again, never "Not sent."
  - No length the page offers can freeze a game: with "Dropped phone" at 0, Talk, Vote and Night each need a clock, and with any of them at 0, "Dropped phone" is at least 1 s (the server's rule; the steppers' ranges are the server's).
  - Holding a portrait opens 03b.
  - Dealing without opening 03 stays three taps.
- **Pass:** "Set it for eight, then wait."

**03b Role sheet**
- **One thing / loudest:** read it; portrait and name.
- **Copy:** the role text plus "Close". **At most 30 of 30 words.**
- **Removed:** "Take out of deck" (16), "Good with", "Acts at night".
- **States:** opens by holding any role card (03, the 02 strip, the 08 strip).
- **Pass:** "Read, then Close."

**04 Your card**
- **One thing / loudest:** hold the card; a face-down card at 60% of the screen height.
- **Locked until:** "Ready" unlocks after a 0.8 s reveal.
- **Copy:** "Your card"; "Hold" (as the cue); "Ready" then "Ready ✓"; pips "{d} of {n} ready" (playtest: a bare "1 of 5" read as cards). Held face: the role text. **34 of 34 words.**
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
- **Copy:** the board's title ("The village sleeps" for a sleeper, else the prompt's, see "The board's title" above); captions "You", "Left", "Middle", "Right", and "Center" on the strip (the Seer's board: "1 player", "or" and "2 center cards" instead); candle and number. Button: "Choose a card" (disabled), "Choose 1 more", then what will happen ("See Cleo", "Swap Ana, Ben") or the role's pass ("Skip", "Keep my card", "Choose for me": "You" alone picked), then "Chosen". "Hold" appears on "You" only as a cue. Held face: role name, instruction, window-1 page. **24 of 24 words.**
- **Layout (product owner, 20 November 2026):** the other players' cards in balanced rows; the player's own card ("You") is not among them but in front of them, on a paper place beside the table's three cards, in the same place and size on every phone.
- **Removed:**
  - The pre-selected Cleo (2).
  - "Your turn · Seer" and the role portrait (14).
  - "Do nothing tonight" (16): keeping your own card replaces it.
  - "Look at Cleo's card" (14).
- **States:** see the window tables. Two center cards (11): "See Left, Right" shows exactly what will be sent.
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
- **Locked until:** "Ready to vote" stays outlined (never amber) and is never locked.
- **Copy:** "The village wakes"; timer digits (the unit "s" set smaller than the number); "My night"; deck strip; pips "{d} of {n} ready"; "Ready to vote", then "Ready ✓" (tap again to undo). My night pages, the same count on every phone: the result face; the window-1 page if window 1 ran; "Dealt: {role}". **15 of 15 words.**
- **Opening (playtest, 21 November 2026: "never saw my result"):** a phone whose night told it something (a result other than "You slept." or "You did nothing.", or the Doppelganger's copy) that the server has not had acknowledged opens the talk with My night OPEN, once: the same paper card a hold shows, no hold, every word on screen. The ack (`night-results/seen`) goes as it shows; a tap puts it away into the My night box; "Ready to vote" works under it at once. A phone that slept opens nothing; a restart after the ack opens nothing. No server change, no wait.
- **Deck:** in columns, sized to the room under My night (two at the acting size, then the caption size, then three; then the names alone): every chip whole and on screen at 320 wide, text x1 and x1.3, never under a fade. The large My night box only where the deck still fits under it.
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
  - After locking, the player's own pick stays lifted and outlined and the other rows dim; the button reads "Locked". (Owner, 20 November 2026: a neighbour could already read "Lock in Cleo" before the lock; hiding the pick afterwards only costs the player the sight of their own choice.)
  - The vote's length is the table's "Vote" (03; 2 min unless the host changes it).
- **Pass:** "Tap a name, then Lock in."

**10 The count**
- **One thing / loudest:** watch; the dead player's card.
- **Locked until:** nothing. "See who won" works at once; any other tap finishes the motion (section 8).
- **Copy:**
  - Headline: "{name} dies." / "{names} die." / "Nobody dies.", and then "{name}, {hunter}'s pick, dies too." for each player the server says the Hunter took (`hunter_chain`).
  - When nobody dies: "Nobody got 2 or more votes."
  - Rows: accused name, count, and the voter names at 16 px. Then "No vote: {names}".
  - Cards: the player's name and "Now" (`final_role`), plus "Dealt" with an arrow when the dealt card differs; team tag ("Werewolf team" beside the role's name, "Village", "Alone"). With several dead, "Dealt" and "Now" are said on the first card only.
  - Button: "See who won".
  - **16 of 16 words.**
- **Removed:** "Dev was the" (1). "The count", "Accused", "Voted by", the voter tokens (9, 12).
- **States:**
  - The dead card comes first, then the rows. The rows land with a 150 ms stagger, then a 1.2 s beat, then the flip (400 ms), on every phone at once; nothing waits on it.
  - Only the rows of players killed by the vote are outlined; the Hunter's pick is not.
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
  - Host: amber "Play again", quiet "Edit deck", side by side, or stacked when a label would not fit on one line. Guest: "{host} deals next." (only when the host is at the table) as the message, "Leave" a quiet word beside it, never a button (cold read: a non-reader tapped the only button and left).
  - **13 of 13 words.**
- **Removed:** "Cleo held the Robber" (1). The footnote (12). "Change the deck".
- **States:** after the band, every player's card (dealt → final) with "Won" / "Died", one compact line each, and the center; then the night, open (starting on the first screen at five players and 390 wide): first the red line, each Werewolf card from where it was dealt to where it ended ("Cara → Bob"), headed by the Werewolf's portrait; then the steps, arriving 150 ms apart (instant with reduce motion; a tap finishes them), on a spine that is red where a werewolf card was looked at or moved; a tap on the red line folds the steps. Red is the server's `werewolf` flag on a card, everywhere. (Review of the rebuild, 20 November 2026.) The whole night is reachable: scrolled to its end, its last step is fully above the pinned line, at five and ten players, 390 x 844 and 360 x 640; the steps, their numbers and "Center: {roles}" are in full ink (playtest, 21 November 2026: the story read as small, pale and cut off).
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
| This phone is offline, any phase | "One moment" (with "Try again" where a load is waiting on it) |
| A wait that has lasted 5 s, nothing failed | "Still on its way." |
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
| §3.3: non-actors "get something to tap" | Every phone with a choice sends a `choose`; a phone with nothing to choose sends nothing and is not waited for (section 8). |
| §4.5: night waiting screen | 05 only between a close and 07. |
| §4.6: a "do nothing" choice | Picking "You": the button says what passing is for the role ("Skip", the Robber's "Keep my card", the Drunk's "Choose for me"), or any card that means nothing to your role. |
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
2. **Identical answers.** Every `choose` is answered `{"status":"submitted"}`, a resend of one already taken included (the request carries the prompt's `chosen`; `docs/specs/onuw/api-contract-v2.md`, section 9). The only errors are `wrong_phase`, `already_chosen` (409) and malformed `bad_request`, and none of them depends on role. A pick that is invalid for the role is not an error. Test every role for byte-identical responses. Reason: responses must leak nothing.
3. **Choosing twice in window 1.** Window 1 accepts up to 2 `choose` from any phone and stays fixed-length. Window 2 accepts exactly 1, and closes once every phone with a choice has chosen (section 8: a phone with nothing to choose sends nothing). Reason: the server answers any phone's choose alike; who taps at all is an accepted tell (section 8).
4. **Doing nothing.** A lone Werewolf with no center pick, and a Doppelganger look with no other-player pick, both resolve as skip or timeout. A Drunk with no center pick gets the seeded swap (`made_by_server: true`). Reason: "Keep my card" must be valid for every role.
5. **Window opening.** Every phone gets the same group event `night_window {window, deadline}` in one after-commit batch. Each phone then reads its own prompt from `/me`; there are no per-role prompt events. Reason: identical traffic and timing.
6. **Automatic deck and defaults.**
   - Lobby settings carry `deck: "auto"` and `deck_chip: "simple"|"classic"|"chaos"` until the host edits cards. The deal builds the deck from the chips table for the table's size (`seats`, the number the host set; else the players at the table), under the Lobby lock.
   - At lobby create the server writes `card_look_seconds` 30 and the Simple chip; every other length is the server's default, sent in the lobby body (`lengths`) and shown on 03. No pace presets (removed 21 November 2026).
   - Reason: this removes the client writer and its races.
7. **Join link.** The web deployment serves the app for `/join/*` (a Vercel rewrite) and the app knows its public origin for the QR code. Reason: finding 15.

## 5. Build order hooks

1. `LearnedStore` (`mv.learned.v1.*`, with a reset in /debug).
2. `TeachOnce(id, cue)`, plus a locked gate that replays its cue for 3 s.
3. `HoldToReveal` timings: 120 ms, 0.8 s, and the accessible activate (no caps, section 8; no double tap, the review).
4. `HeldFace` frame: fixed size, duotone portrait, pages, drawn above the thumb, text scale capped at 1.6.
5. `copy.dart` holding every string, plus `copy_budget_test.dart`: budgets, banned list, headlines, buttons, the single question, and the amber count.
6. `RoleText`: one table that feeds RoleCard, 03b and faces.
7. `NightBoard`: built from the player list, taps, and the `choose` payload.
8. **A night uniformity test**: drive every role through the look stage, window 1, window 2 and 07, and assert that the non-held widget trees, the transition times and the requests are identical.
9. QR code, the `/join/:code` route, and the share sheet.
10. Cold-read pack exported from `just screens` (host, guest, sleeper and Seer journeys, and a host setting up a table for eight).

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

**Window 1 is as in section 3** (one fixed-length window, the server takes two chooses from any phone, the
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

**"What you saw" is not a separate screen, and has no timed gate.** The 4-second wait before
"Done" (section 3, 07) was an added delay and is withdrawn, and without it a separate 07
screen would show who had little to read. So when the last night window closes every phone
goes straight to 08 Talk at the same moment (the talk's clock is already running on the
server). "My night" on 08 is the hold box that shows it: page 1 is the last window's result
face from the "07 faces" table (what a player holds it for), then window 1's page when it ran,
then "Dealt: {role}", the same number of pages on every phone (review, 20 November 2026). In a player's first game the `hold` cue breathes on "My night"; "Ready to vote"
stays locked until it has been held once this game, as already specified. The results ack is
sent the first time "My night" has been held for 0.8 s. Screen 07 and its copy ("What you
saw", "Done") are removed; 05 is shown only while `/me/` loads.

## 8. Fun first (20 November 2026): where secrecy stops

Product owner: do not over-index on secrecy; the game must hang together and be fun, and
nobody waits. This section overrides anything above that costs a player time, taps or a
wasted turn in order to hide something. The test for any rule: would a table of friends
notice the protection, or only the friction?

**Kept (free for players):** secrets (your card, what you may do tonight, what you saw, your
team) show only while held; every player has a card to tap at night; progress is counts, never
names; a request names its stage; one look for the Doppelganger; no sound or vibration at
night.

**Relaxed:**

| Was | Now |
|---|---|
| Choose locked until "You" is held 0.8 s, every window, every phone | No gate at night. Holding "You" shows what you may do; the `hold` cue points at it in a first game only. |
| Any taps accepted; a pick that means nothing to your role silently does nothing | The phone reads the SERVER's prompt (which cards and how many your role may pick) and the button follows it: "Choose a card" (disabled) / "Choose 1 more" (disabled) / "See Cleo" / "See Left, Right" / the role's pass (section 3, "The board's title"). The cards a pick cannot take are dimmed. A turn cannot be wasted by a slip. Players with nothing to choose have no button (next row). Deliberately doing nothing is picking "You". The phone holds no rules: it compares picks with the prompt's shapes. |
| Every phone chooses at night, a sleeper by tapping any card, and every window waits for every phone | A phone with nothing to choose (its prompt is `none`) is not asked to do anything (playtest on the real screens, 20 November 2026: "Choose a card" contradicted "Night: Sleep."). Its board says the village sleeps and shows the table calmly; a tap lifts a card and lets it settle (cover for anyone who wants to fidget), nothing is picked or sent; there is no button. The server never waits for it: a window closes once every phone WITH a choice has chosen (no sooner than the table's minimum) or at its deadline. A player with a choice still picks, then presses; "Keep my card" stays the pass. |
| Every phone chooses twice in window 1 | A phone with a choice chooses once per window. Only the Doppelganger, after her look, gets a second pick in window 1 (her board re-arms when her result arrives). |
| A held face hides after 5 s | No cap anywhere. It hides on release. |
| "Ready to vote" locked until "My night" was held | Never locked. In a first game the `hold` cue breathes on "My night". |
| A tap on a locked gate replays the cue | Unchanged, but the only gates left are 04 "Ready" (you must have seen your card) and buttons waiting for a valid pick. |
| One fixed frame, one portrait, no red, 2 lines for every face | A face is drawn above the thumb and may use the full role card (portrait and colour included). Keep faces a similar size; do not police their content. |
| Cross-role identical widget trees for the night board | The board's LAYOUT and motion are the same for every role (same cards, same lift, same button position). Button text and enabled state follow the player's own picks. |

**Pace.** Every length is the table's setting; nothing here adds to it. Each stage ends the
moment everyone present has done their part (looked, chosen, readied, locked); the timers are
backstops. No animation blocks input: the count's flips and the results timeline finish on a
tap.

**Accepted tells** (the card game has them too): an actor may take a little longer than a
sleeper; a neighbour who reads your button can see how many cards you are picking; the
Doppelganger taps twice; who taps at night (only a phone with a choice sends one, and only
its board has a button), never what they chose; a glance at a board's title (an actor's
says what the role does tonight, a sleeper's "The village sleeps") or at the Seer's three labels. None of these is worth a wait or a wasted turn.
