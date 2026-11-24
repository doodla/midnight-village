# First-time play: teach once, say little

Status: decided. This spec covers how the app teaches a first-time player and every word on every screen. Rules text lives in two places only: the role text (§3), and the night face of "You" (§3). Where this spec and the mocks disagree, this spec wins. Where it disagrees with `docs/specs/onuw/`, the rules docs win. The design-brief changes are listed in §3 under "Brief amendments" and land in the same commit.

## 1. Copy rules

1. **How words are counted.**
   - Split visible text on whitespace. A word is any piece that contains a letter. "Cleo's" and "don't" are one word each.
   - Exempt: template placeholders such as `{name}`, `{role}` and `{pos}`; the 12 role names and their plurals; "Midnight Village"; the table code; digits; glyphs.
   - A held face counts together with the screen under it.
   - A system banner (the errors table in §3) has its own budget of 6 words, including its button, and is not counted with the screen's words.
   - Screen-reader labels are not counted, but must be 8 words or fewer.
2. **Say little, and say when you say more.** A screen has no fixed number of words. A change that adds words a player reads says so and why: when a copy class has more words than it had on the main the change was built on, the pull request's description holds a line for it under "Words added" (`tool/words_added.py`; `just handover` prints the line with the words before and after). Fewer words, or the same number, needs nothing.
3. **Headlines.** One headline per screen, at most 5 words.
4. **Buttons.**
   - A button label is 1 to 3 words: a verb, naming the person or card when there is one. A night button says what will happen with the picks ("See Cleo", "Swap Ana, Ben"), and a pass button is true for its role (rule 11).
   - A disabled button that is waiting for input names what is missing ("Pick a name", "Need 3 players", "Add 2 cards").
   - A locked main button says what unlocks it (changed 23 November 2026, art director: a locked "Ready" with no live button beside it read as live and did not say why): 04's "Ready" is "Look first" until the card has been looked at, then "Ready". The night board's Choose waits for a whole pick ("Choose a card", "Choose 1 more"). "Done" and "Ready to vote" are never locked.
   - After the action, the button shows the state in one word and stays disabled: "Chosen", "Locked", "Ready ✓".
5. **Where rules are stated.** Rules appear only in the role text (cards and 03b) and on the night face of "You". Every other screen states facts only, for example "Nobody got 2 or more votes."
6. **Gestures are never explained in text.** The only exception is the one-word cue "Hold".
7. **Reading floor.**
   - 14 px minimum, at text scale 1.0, for anything a player must read in order to act (body, buttons at 15, names at 16). Set by the owner on 23 November 2026 ("Tight sizes, but keep the serif names"; was 16).
   - 12 px minimum for small labels: captions under cards and tokens, tags, badges (was 14, same decision).
   - Contrast of at least 4.5:1; words that say something true or are read to follow the game ("✓ Nothing to do", "✓ Locked", every count, "Now" and "Dealt" on 10, the night on 11, a quiet "Leave") in full ink, not the quiet one (playtest, 21 November 2026: "small and pale"). Counts are set a step larger than body text (15, bold).
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

**The held-face frame** is the same on every face: 04, "You" on 06, 07, and 08's My night (held, and shown on the board only while held: see 08).
- Always the same fixed size.
- Drawn above the touch point, never under the thumb.
- At most one portrait, in bone-on-indigo duotone (never red), taking 30% of the frame.
- Bone text, at most 2 lines.
- When a face has several pages, each new hold shows the next page, and page dots appear inside the frame.

**Hidden-information decision: everyone holds at the same beat.** 04 and 07 open on every phone at the same moment. On 06, every phone has to hold "You" before Choose unlocks. Every phone has a face, with the same frame and the same page count for that moment. A held thumb therefore only means "looking", and everyone looks.

| Cue (`id`) | First appears | What the player sees | Words | Unlocks | Learned when | Later games |
|---|---|---|---|---|---|---|
| `hold` | 04, the moment of the deal | A plain ring on the face-down card, "Hold" in it at 20 px, breathes (bone colour, scale 1.00 to 1.06, 1.4 s loop); while the card is held the ring fills, in the 0.8 s a reveal takes to count (no thumbprint: product owner, 20 November 2026). Taught once: the same ring is on My night (08) (not on "You" on 06 since 23 November 2026: that card is face up) only on a device that has never held a face (playtest, 21 November 2026: one lesson, not three) | "Hold" | "Ready" turns amber after a 0.8 s reveal | The first 0.8 s reveal on any face | Nothing: the card is a card |
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
| Deal commits | 04: a face-down card, "Your card", "Look first" locked, pips "0 of {n}" | Role text, no cap | Opening event, then `GET /me` |
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
| Back after a close | 07 for any results past `night_results_seen`, then the current phase. In results phase it lands on the end board, settled (the reveal plays only for a phone in the game as the results came). | — | `GET /me` |
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

Every role entry is laid out as (owner, 24 November 2026: "I'd like the copy updated with different formatting so it's easier to parse"): the tag above the name; then rows, each a small label ("Night", the Hunter's "Vote", "Wins") in a column of its own beside short lines, one line per case; then, after more room and across the whole width, the shared line **"You are your last card."** (5 words; "Anyone may lie." was cut on review, 21 November 2026, so the card reads at full size on small phones), a rule of the game rather than of the role. Where the lines' column would be too narrow for its words (a small phone at large text), each label sits above its lines. Form parts them, not words: no role has more words than before.

**Tag** (owner, 24 November 2026: "There's a double label as well."): a team's tag beside a role's name never repeats the name: the Werewolf team's is "Werewolf team" (red: the Werewolf and the Minion), the Village's "Village", the Tanner's "Alone", the Doppelganger's "Copies".

Village Wins lines: **"A Werewolf dies."** / **"No Werewolf player: nobody dies."** (6 words)

| Role | Tag | Night | Wins | Total words (was) |
|---|---|---|---|---|
| Werewolf | Werewolf team | At dawn, see the other Werewolves. / Alone: you may see 1 center card. | No Werewolf and no Tanner dies. | 23 (24) |
| Minion | Werewolf team | At dawn, see the Werewolves. / They don't see you. | With the Werewolves, even if you die. / No Werewolf player: another dies, not the Tanner. | 28 (28) |
| Mason | Village | At dawn, see the other Mason. | Village lines | 19 (19) |
| Seer | Village | See 1 player's card or 2 center cards. | Village lines | 20 (21) |
| Robber | Village | Swap with a player. See your new card. | Village lines | 22 (22) |
| Troublemaker | Village | Swap 2 other players' cards. Don't look. | Village lines | 20 (20) |
| Drunk | Village | Swap with a center card. Don't look. | Village lines | 21 (21) |
| Insomniac | Village | At dawn, see your own card. | Village lines | 20 (20) |
| Hunter | Village | Sleep. Then a "Vote" row: Your pick dies with you. | Village lines | 21 (21) |
| Villager | Village | Sleep. | Village lines | 15 (15) |
| Tanner | Alone | Sleep. | You die. | 11 (11) |
| Doppelganger | Copies | Copy a player's role. Act as that role. | As the role you copy. | 21 (21) |

**Team tags** on the end board come from the server's `team`: `village` → "Village", `werewolf` → "Werewolf" ("Werewolf team" beside a role's name), `neutral` → "Alone".

**Where the team shows** (issue 37): the other Werewolves, the Minion's Werewolves and the other Mason are shown only at dawn, when the talk opens, in My night's picture story (your card, the cards you touched, the one sentence: "You and {names} are the Werewolves."; section 3, "Brief amendments": team shown only there), never at night; so these role texts say "At dawn", as the Insomniac's does, and a sleeper's night face says only "Nothing to do tonight." A lone Werewolf's center look is at night ("Alone at night").

**Where I chose brevity over precision** (each string was checked against `roles.md` and `voting-and-resolution.md`):
1. "You are your last card": for a Doppelganger card, "your card" means the role she copied. Her own line says this.
2. Doppelganger "Act as that role": a copied Werewolf, Mason or Insomniac acts later, not at once.
3. Minion: with no Werewolf player, `voting-and-resolution.md` (Minion special rules) has the Minion win when a player other than the Minion and the Tanner dies, and lose when the Tanner dies; "another dies, not the Tanner" says that ("another": not you).
4. Hunter "your pick": an unlocked pick counts too (contract amendment), so "pick" is exact. It is under "Vote", not "Night": the Hunter sleeps; his rule acts at the vote.
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
- **Locked until:** both ways in lead to the name until one is entered (the scan glyph is the one exception, below); the amber plaque stays amber (one plaque, below). None of them looks dead (23 November 2026, review): a tap on "Start a table" or "Join a table" with no name takes the cursor to the name field and gives it a short shake (reduced motion: a colour flash). A locked amber "Join" (from a link, or with the code typed) is never silent (23 November 2026, the app's rule for primary buttons): a tap on it takes the cursor to the empty name field, or to the code field when only the code is missing.
- **One plaque** (24 November 2026, the coordinator's decision, 01 dressed in paper): exactly one amber plaque at any moment. While the code field holds a whole code (typed, scanned, or the link's) it is "Join" and "Start a table" is a small bone scrap; otherwise it is "Start a table", and "Join a table" is a bone scrap (closed) or, beside a code not yet whole, Join in the locked form saying "Code" (a tap takes the cursor to the name, then the code). The buttons keep their places when it flips: only the paper changes. With no name the plaque is still amber; a tap leads to the name (never a dead button).
- **Copy:** hint "Your name"; "Start a table" and "Join a table" (one of them the amber plaque, above). "Join a table" opens a hint "Code" and an amber "Join". Body text at 16 px: "{n} at tables" and "You won last game" / "You lost last game".
- **Removed:** the prefilled "Ana" (8). The amber "Start a table" (4). The tagline. The footer (12).
- **States:**
  - Opened from a link: the name field and an amber "Join" (3 words).
  - The name is prefilled only from this device's own guest account.
  - The scan action (22 November 2026, issue 14): a glyph beside "Join a table" (and beside the code field once it is open), an outlined square of the buttons' height, no word, "Scan the code" to a screen reader. It is not locked by an empty name (scanning is the natural first move for a guest told "scan to join"): the name is asked for after the scan if it is empty. It is not offered on a table's link (that already names the table).
  - The words on 01 are unchanged.
  - The app's download (22 November 2026): in an Android browser only (the web build on Android; never inside the Android app, on iOS or a desktop, and on no other screen), one quiet link "Get the app" on the "N at tables" row, right-aligned (alone on that row, right-aligned, when the line is absent): dimmed bone, underlined, the same size and face as that line, never amber and never louder than the dimmed buttons, 48 to touch. It opens `/app`, which the host sends on to the Android file (`docs/dev/deploy-vercel.md`, "Android app download"). No banner, no dialog, no other words. In that browser 01 is (its own allowance in `screen_states.dart`, as the practice states have).
- **Pass:** "Type my name."

**01b Scan** (the camera 01's scan action opens; a place of 01 with its own Back rule: Back, the glyph or the phone's, closes it to 01, as it was)
- **One thing / loudest:** the camera, in a paper window with the viewfinder's four corners, the village faint behind the empty upper half; nothing to read while it looks.
- **Copy:** none while it looks (a Back glyph; a light glyph where the camera has one: Android; the web has none). Where the camera cannot be used (permission refused, no camera, a page that may not use one): the window shows a shuttered window cut from paper (the camera is off), one line "The camera is off.", and an amber "Type the code", which closes the scanner and opens 01's code field, focused. Screen reader: "Scan the code", "Looking for the table's code", "Back", "Light".
- **Reads:** a table's link (`<origin>/join/<code>`, any origin) or a bare code, in any case and with spaces, in the server's alphabet and length (six of the capitals and digits without 0, O, I, 1 and L). Anything else is ignored, silently. The camera is never touched before the tap and stops the moment the screen leaves (a code read, Back, the app moving on or to the background).
- **A code read:** the camera stops, the code stands in the window at once (no fade through an empty window) and the corners snap in round it, and the join starts the same frame, by the same path as typing the code (no beat is waited out). With no name typed yet, 01 is back with the code in its field and the name field asking. A refused join leaves the scanner for 01 with its banner and the code still in its field (a typed join the same). The scanner belongs to the 01 that opened it: leaving 01 ends it, and the camera starts only on a tap, never when 01 is built.
- **Pass:** "Type the code."

**02 Table**
- **One thing / loudest (host):** guests scan. Loudest is the QR code for `/join/{code}`. Two blocks: the QR code with "Scan to join" on it (its label only), and, past a hairline, the code with its own label "Code" (01's word for it) and Share. An app build that knows no web address has no QR code: no "Scan to join", the code block alone.
- **Locked until:** "Start the game" (the owner, 23 November 2026: "Just say 'Start the game' or whatever"; it said "Deal to {n}", which the owner read as a dimmed button with no reason) unlocks exactly when the server says the deal would go (`deal.ok`). Until then the one main button says what to do and a tap does it, never the same words dimmed, the reasons in the order the host can act on them: "Need 3 players" at an open table under three and "Need {n} more" at a table set for a number with {n} places empty (outlined; a tap shares the table's link; the number always the phone's current one), then, when the deck holds the wrong number of cards, "Add 1 card" / "Remove 2 cards" (amber; a tap opens 03; the server's current `need`). Players come before the deck: a host alone with a big deck reads "Need 3 players". A refusal the phone cannot name leaves it live: the deal's own answer says why. While this phone's own change is on its way (under a second) it keeps "Start the game", outlined.
- **Copy (host):** "Scan to join" (the QR code's label); "Code" (the code's); quiet "Share" (a glyph); at a number "{d} of {n}" with a small empty circle for each place not taken (one wrapping line, so the deck and Leave stay in view), above the rows; with 3 or more here but fewer than the number, "Play with {n}" (one tap sets the number to who is here; with a deck of the host's own, the tap opens 03 with its count showing, never throwing the deck away); the set-up: the deck chip, "Talk {length}", every role in the deck face up with count badges in the deck builder's order, in balanced lines (no card alone on a line); a deck that does not fit is said once, by the one main button ("Add 1 card", "Remove 2 cards"), with no second count on 02, and "Edit" is hidden then (one way in); otherwise quiet "Edit"; amber "Start the game", or "Need 3 players", "Need {n} more" or the deck's fix (above); a quiet "Leave" at the main button's side, left of it (it asks first); "Leave" shows it is on its way at once. ("Start the game" is the owner's own, one over the earlier 13).
- **Copy (guest):** "{host} deals"; the same card, the same "{d} of {n}" and empty places, the same set-up face up (a tap or a hold on a role reads it); quiet "Leave". Waiting is said by the shape, not a sentence (playtest, 21 November 2026: Leave read as the one thing to do): "{host} deals" at the headline size (32; was the hero title, 46: the owner, 22 November 2026, found the names too big), "Leave" a quiet underlined word right under the set-up (23 November 2026: not alone at the foot of an empty screen), no outlined button.
- **The deck is always face up** (owner, 21 November 2026: "everybody should see what characters have been selected"): the roles the table would deal, for host and guests, in every state; no card arithmetic on 02 for a guest, and the host's one button says "Add 1 card" / "Remove 2 cards" when the deck is off (23 November 2026).
- **Removed:** "Table code", "At the table", "5 players", "Host · You", "8 cards", "x2", "Change" (10, 12, 15).
- **States:**
  - Your own row has a thicker outline.
  - A dropped member's token dims to 40%, with no words.
  - After a host handover, that phone switches to the host layout, with no words.
  - A practice player's row (a seat the server plays, below at 03) has its own token, the thing it is named for (a teapot for Teapot), and "Practice" on the name's line in every row, quieter than "You" (the word alone, no outline; "You" stays the one outlined tag), for host and guests; it is never dimmed (no phone to drop) and counts in "{d} of {n}" and "Start the game" (a practice change on its way included). A table set for a number with fewer come shows "Play with {n}" beside them like any other: that state is 15 words, one over 14, its own allowance (the tag is one word, the same on each practice row), reached only by a host who held "Players".
- **Pass:** guest says "Wait or scan"; host says "Show the code, then deal".

**03 Tonight's game** (host; the set-up page, editable before anyone joins and until the deal; amended 21 November 2026 after the owner got stuck in the deck editor, and after review)
- **One thing / loudest:** nothing is required; amber "Done".
- **Locked until:** never locked, and always "Done" (amended 23 November 2026, after the owner left this page with 12 cards for 8 and found a dimmed button on 02; reworked after review): with the right number of cards "Done" leaves; with the wrong number the first "Done" or Back stays, brings the count line into view and gives it a short shake (reduced motion: a colour flash), and the second leaves, so the host is never trapped (the table's code, to let friends in, is on 02, and its button leads back). The count line says what to do, in the player's words and one face: "14 of 12 · Remove 2 cards", "10 of 11 · Add 1 card". A host who changed only a timer is never stuck, and a deck is always fixable in one tap (a chip, a card in or out, or the number). The server stays the authority (the deal refuses a deck that is not players + 3; `deal.need` and `deal.have` are its numbers): the phone only shows the distance. Discarding the changes is not offered (they are saved as they are made).
- **Copy:** "Tonight's game"; "Players" with a stepper (within the server's range: never below who is here, never above what the table holds; "Any", an open table, only with an automatic deck) and, at a number, "{d} of {n}" with every seat drawn; chips "Simple", "Classic", "Chaos"; with a count to meet, the count line ("11 of 11", "14 of 12 · Remove 2 cards", "10 of 11 · Add 1 card") over a pip for each card needed (the cards over in the danger ink, no gap); every role face up in a grid (names exempt), a tap puts one in, a lit card's minus takes one out (spoken "Take one {role} out"); every length the server has, each its name and a stepper over its value, in this order: "Talk", "Vote", "Night", the Doppelganger's (the role's name; the row is there only while the deck holds a Doppelganger), "Look", "Night minimum", "Dropped phone", "Host away"; values "{n} s", "{n} min"; 0 is "No clock" for the talk and the vote (no deadline: it ends when everyone is ready) and "Off" for the rest. Under each name but Talk and Vote a caption of two or three words says what the timer is (the owner, 23 November 2026: "The timers aren't really explained"; caption face, full ink, set once, no help screen): Look "See your card", Night "Time to act", the Doppelganger's "Acts first", Night minimum "Shortest night", Dropped phone "Wait before skipping", Host away "Then another hosts". Button "Done"; with practice players switched on (hidden, below), "Practice" with a stepper under Players. **37 of 37 words (22 and the six captions' 15); the practice state (below) has its own allowance, 38, and the deck-does-not-fit state 43 (the count's line).**
- **Removed:** the pace chips "Quick", "Normal", "Long" and their tiles (the owner: "I just need the things to be editable"), the face-down deck and "Edit" (the deck is always face up), "Use this deck" (now "Done").
- **States:**
  - The deck stays automatic (a chip) until a card is changed; then it is the host's own, from the cards shown, for the number (an open table takes who is here, at least 3), and no chip is selected. Tapping a chip returns it to automatic.
  - Every change is saved as it is made; a new table shows the server's own lengths. What shows while a change is on its way is the server's state with only that change taken from the phone. A change the server refuses (the table moved under it) is dropped and the page read again, never "Not sent."
  - No length the page offers can freeze a game: with "Dropped phone" at 0, Talk, Vote and Night each need a clock, and with any of them at 0, "Dropped phone" is at least 1 s (the server's rule; the steppers' ranges are the server's).
  - Holding a portrait opens 03b.
  - Dealing without opening 03 stays three taps.
  - **Practice players** (owner, 22 November 2026: "hidden enable so it's not visible to everyone"). Holding the word "Players" itself (not the room beside it) switches them on for this table; once on, a "Practice" stepper under Players (its name in the action face) sets how many sit, 0 to the most the server says may, and the row answers the hold at once. With none seated, holding "Players" again switches them off and the row goes; with some seated a hold does nothing (they are taken away one by one with the minus first), so a thumb resting on the word never removes everyone. Nothing on any screen offers or names the gesture, and a tap on "Players" does nothing. The word "Practice" is one more at a table set for a number: that state has its own allowance of 38, seen only by a host who held "Players"; every other state of 03 stays within 37. A practice change shares the settings' lane: it shows at once, Deal waits for it, and "Try again" never undoes a newer change. What to tell the owner: "On the set-up page, press and hold the word Players."
- **Pass:** "Set it for eight, then wait."

**03b Role sheet**
- **One thing / loudest:** read it; portrait and name.
- **Copy:** the role text plus "Close".
- **Removed:** "Take out of deck" (16), "Good with", "Acts at night".
- **States:** opens by holding any role card (03, the 02 strip, the 08 strip).
- **Pass:** "Read, then Close."

**04 Your card**
- **One thing / loudest:** hold the card; a face-down card at 60% of the screen height.
- **Locked until:** "Ready" unlocks after a 0.8 s reveal; until then the button says "Look first" (23 November 2026: a locked button says what unlocks it).
- **Copy:** "Your card"; "Hold" (as the cue); "Look first", then "Ready", then "Ready ✓"; pips "{d} of {n} ready" (playtest: a bare "1 of 5" read as cards). Held face: the role text.
- **Removed:**
  - The card arriving face up, and "Holding…" (3).
  - "I know my card" being loud (4).
  - Token pips (9).
  - The host's "Don't wait": the 30 s backstop covers it.
- **States:** see the look stage table; a phone still unrevealed when the night opens goes to 06 with the others.
- **Pass:** "Hold the card."

**05 Night, between**
- **One thing / loudest:** wait; the candle.
- **Copy:** "The village sleeps".
- **Removed:** "Tap the cards…" (7). "Waiting for Dev…" (6). The 05 screen after a Choose: the board now stays.
- **States:** shown only from a window's close until 07 has loaded, and on a cold start during the night while `/me` loads.
- **Pass:** "Wait."

**06 Night board**
- **One thing / loudest:** hold "You", tap a card, then Choose; the board.
- **Locked until:** Choose needs 1 or more picks and a 0.8 s hold of "You" in this window.
- **Copy:** the board's title ("The village sleeps" for a sleeper, else the prompt's, see "The board's title" above); captions "You", "Left", "Middle", "Right", and "Center" on the strip (the Seer's board: "1 player", "or" and "2 center cards" instead); candle and number. Button: "Choose a card" (disabled), "Choose 1 more", then what will happen ("See Cleo", "Swap Ana, Ben") or the role's pass ("Skip", "Keep my card", "Choose for me": "You" alone picked), then "Chosen". "Hold" no longer appears on "You" (its card is face up; the hold lesson is 04's and My night's). Held face: role name, instruction, window-1 page.
- **Layout (product owner, 20 November 2026):** the other players' cards in balanced rows; the player's own card ("You") is not among them but in front of them, on a paper place beside the table's three cards, in the same place and size on every phone.
- **Own card face up (owner, 23 November 2026):** "I think on this screen show who the player is in their card, face up, so that they know their role. Keeping that face down makes no sense here." The "You" card shows the role this phone was DEALT (`your_role.original_role`: the card it already saw on 04), its portrait and its name on a slip of paper across the card's foot, above its token; the caption under it is still "You". Never a role the night changed: a Doppelganger who copied someone still shows the Doppelganger, and what the night told (a look, a swap, a copy) stays on the held face and in My night. The card is still the "do nothing" choice for every role that has one (a tap anywhere on its paper place picks it, lift and ring as before; the button says "Skip", "Keep my card" or "Choose for me"); the hold still opens the held face but takes no hold ring over the portrait. The screen is dressed up (paper, one lantern of light, the village behind the board): the title and the seconds on one banner with the candle inside the slip. No word is added (the role's name is the role's own). A screen reader speaks the dealt role for the own card ("You", then the role, as the hint on the card): a known and accepted consequence of showing it face up. The slip's name is set at the caption size with the text size (up to 1.6), smaller only to fit the card, never under 12 and never cut; while the card is held the slip is hidden under the held face.
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
- **Copy:** "What you saw"; "Done". Held face: the 07 faces table.
- **Removed:** "You looked at Cleo's card" (14). "Done" being loud before holding (4). Token pips (9).
- **States:** see the "What you saw" table.
- **Pass:** "Hold the card."

**08 Talk**
- **One thing / loudest:** talk. On the phone, the sun timer is loudest, then "My night".
- **The square (owner's choice, 23 November 2026; overrides the lines below where they differ):** the clock (40) in a strip of night sky with the lantern; a board holding the deck in play (one pile per role, "2 Werewolves", the Werewolf team's red) and every player as a name tag with their sigil; "My night" sealed at the board's foot, its night shown on the board from the top ONLY WHILE HELD (no sheet; taught once by doing it: the seal stirs until the first hold; no words); "Ready to vote" is the screen's one amber action with the count under its words ("2 of 6 ready"), "Ready ✓" in navy once tapped, tapped again to take it back. No marks on the tags and no list of who is ready. "The village wakes" is spoken, not drawn. The night's ground, never the day's.
- **Locked until:** "Ready to vote" is never locked.
- **Copy:** "The village wakes"; timer digits (the unit "s" set smaller than the number); "My night"; deck strip; pips "{d} of {n} ready"; "Ready to vote", then "Ready ✓" (tap again to undo). My night is one picture, not pages: your card on top, what you touched below it (a face-up card is one you saw, a face-down card one you did not), threads between them, and one sentence ("You copied {name}, then saw 2 center cards."), the same on every phone. (the longest sentence is the Doppelganger's).
- **Opening (playtest, 21 November 2026: "never saw my result"):** a phone whose night told it something (a result other than "You slept." or "You did nothing.", or the Doppelganger's copy) that the server has not had acknowledged opens the talk with My night UP, once, on the board (the square, above): every word on screen. The ack (`night-results/seen`) goes as it shows; the first touch anywhere (only that: it presses nothing), "Close" for a screen reader, or Back puts it away (changed 23 November 2026: it used to be a sheet over the screen). A phone that slept opens nothing; a restart after the ack opens nothing. No server change, no wait.
- **My night is held, and shows on the board (owner, 23 November 2026: "The 'My night' thing seems like it floats: depending on where I tap it, it shows up in a different spot"; decided the same day, and sections 7 and 8 say the same):** press and hold the sealed note on the discussion screen, and the player's night shows on the board, from its top, in the same place wherever the note is held, ONLY WHILE HELD (it is not a sheet, and no tap opens it); the ack goes the first time it shows. The count of who is ready sits on the "Ready to vote" button, under its words. A screen reader, a switch or the keyboard activates the note instead: it shows until activated again, and is put away by a change of screen, another route over it or the app leaving the foreground. Nothing about it vibrates. The one rule for where extra information appears (a role's sheet) is in `lib/design_system/README.md`, "Where information a player asks for appears".
- **Deck:** in columns, sized to the room under My night (two at the acting size, then the caption size, then three; then the names alone): every chip whole and on screen at 320 wide, text x1 and x1.3, never under a fade. The large My night box only where the deck still fits under it.
- **Removed:** "Left to talk", "Hold to peek", "In the deck tonight" (12). A loud ready button (4, 19). Tokens on the pips (9).
- **States:**
  - Never paused. No host button. No dropped-player copy.
  - Holding a deck portrait opens 03b.
- **Pass:** "Talk; hold My night."

**09 Vote**
- **One thing / loudest:** pick a name; the rows.
- **Shadow paper (24 November 2026; overrides the lines below where they differ):** the square's world: the vote's clock (its own size) in 08's strip of night sky with the lantern; a board with `VoteCopy.headline` at its top and every player as a slip of paper in seat order; your own name is never listed; the pick lifts with the paper mark; on the cobbles the one plaque with the count (`VoteCopy.progress`) under its words, where the pips were. The night's ground, never the day's; no bar under the clock.
- **Locked until:** a pick is made: until then the plaque is the locked form and says `VoteCopy.pickName`; a tap on it nudges the names.
- **Copy:** "Who dies today?"; "Pick a name", then "Lock in {name}" (with a padlock glyph), then "Locked"; "{d} of {n} locked" under the plaque's words; timer digits.
- **Removed:** the pre-selected Cleo (2). The red X (5); the blood fill too, until the owner brought it back for a locked vote only (22 November 2026: "B: red row and seal": the pick's row turns dried-blood red with the seal on 09; the count's killed rows stay outline-only). Tokens on the pips (9). "Seconds to choose" (12). The ink button (18). The host's "Don't wait".
- **States:**
  - Your own row is never listed.
  - The picked row lifts and gets an ink outline. Tapping another row moves the pick.
  - After locking, the player's own pick stays lifted and outlined and the other rows dim; the button reads "Locked". (Owner, 20 November 2026: a neighbour could already read "Lock in Cleo" before the lock; hiding the pick afterwards only costs the player the sight of their own choice.)
  - A practice player's row carries "Practice" after the name, as on 02: "Who dies today?", "Lock in {name}", "{d} of {n} locked" and "Practice" are 8 of 8 words.
  - The vote's length is the table's "Vote" (03; 2 min unless the host changes it).
- **Pass:** "Tap a name, then Lock in."

**10: the end board** (one screen since 23 November 2026)
- **One thing / loudest:** who was hanged and whether you won, on one notice board; the reveal plays once on a
  phone that was in the game, and one touch settles it.
- **Copy, layout, motion and states:** `docs/specs/frontend/end-board.md` (it wins for this screen): the banner's
  two lines, the cards and vote tags, "What happened" replayed on the board, host "Edit deck" and the amber "Play
  again", guest "Leave" and "{host} deals next.".
- **Requests:** as before: Play again, Edit deck (play again, then 03) and Leave are `Pending`: busy on the
  control tapped, "Not sent." with "Try again" on the foot when no answer came, the server's reason when it refused.
- **Pass:** host says "Play again"; guest says "Wait or Leave".

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
| §4 type scale: "labels 12 uppercase, body 15 to 17" | Body 14, buttons 15, names 16, labels 12 (the owner's choice of 23 November 2026, `docs/design/type-audit.md`); no uppercase tracked labels on player screens. |
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
5. `copy.dart` holding every string, plus `copy_budget_test.dart`: banned list, headlines, buttons, the single question, and the amber count.
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
server). "My night" on 08 is the box that shows it (a hold, and since 23 November 2026 shown on the board only while it is held: press and hold, see 08): one picture of the player's own night (your card, what you touched, a face-up card is one you saw, one sentence), the same shape on every phone, no pages (review, 20 November 2026; a picture since 23 November 2026). "Ready to vote"
stays locked until it has been held once this game, as already specified. The results ack is
sent the first time "My night" has been opened. Screen 07 and its copy ("What you
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
| "Ready to vote" locked until "My night" was held | Never locked. ("My night" is held, shown on the board only while held, 23 November 2026; the seal stirs until the first hold, with no `hold` cue and no words. The count of who is ready is on the button.) |
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
