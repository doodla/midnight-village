# Midnight Village — Design Brief

This is the whole design reference for the app. It replaces the earlier set of 19 design files, which were deleted because they contradicted each other and described a look that was not chosen. Game rules live in `../onuw/`. Where this brief and the rules disagree, the rules win.

Mock screens: `../../design/mocks/` in this repository (all 11 screens, with the art in `../../design/art/`), and the canvas they came from, https://claude.ai/artifact/AQ2LuLA5KkRPXHiZoGb6j9 (page "Round 4"). The mocks are the reference for look and layout. They are pictures, not the app.

## 1. What the app is

A phone companion for One Night Ultimate Werewolf played around one table. Each phone shows that player's secret card, their night action and their vote. A server runs every rule. The table is where the game happens; the phone stays out of the way unless it is needed.

- 3 to 10 players, about 10 minutes a game.
- Guests only. No accounts.
- Version 1 is for phones held upright, including a phone's browser. On a wider screen the phone layout is shown centered. Tablet and landscape layouts are later.

## 2. The look

**Chosen: "Shadow paper" (mock row D).** Cut-paper shadow theatre with menace. It is the one look. A future look would be a separate design with its own layouts, components and original art, not a recolouring of these screens.

| | Shadow paper (version 1) |
|---|---|
| Ground, night | Indigo `#14172f` |
| Ground, day and vote | Cold dawn grey `#cfcbd6` |
| Paper and light text | Bone `#e9e2d0` |
| Danger, Werewolf, your pick | Dried blood `#8f2a24` (use `#c2413a` for thin lines on dark) |
| The one warm accent | Lantern amber `#e3a13a`: one amber fill per screen, the primary button, with a 2 px ink outline on day grounds. A selection is lift plus an outline (bone on night, ink on day), never amber or a fill. (Amended by `first-time-play.md`.) |
| Quiet text on dark | `#aab0cf` |
| Hairlines on dark | `#2c3160` |
| Headline type | Gloock |
| Body type | Figtree |
| Shapes | Squared corners (3 to 6px). Hard offset shadows, no soft glows. |

Rules for the look:

- Night screens are dark, day screens are light. Anyone can tell the phase from across the table.
- Two colours do most of the work. No pastel player colours. A player is a name and a **token**: a small round cut-paper emblem (crow, key, moth, bell, thorn and so on) given at the table, so people are recognisable at a glance without colour.
- Timers should come from the world (a candle burning down, the pale sun climbing over the rooftops) with the number kept small beside it.
- Drifting specks are kept, redrawn as paper scraps and ash. Never more than 60 on screen at once. Test early on a mid-range Android phone in the browser and lower the count there if it stutters.
- **Values come from the skin.** Screens read every colour, face, size and shape from the skin, never a literal, so nothing is hard-coded. Spacing and motion are shared layout and motion constants, not part of the skin.

### Role art

All 12 role pictures are generated from one style reference, then one illustrator tidies the set so they look like one hand made them.

Style used for the mocks: *cut-paper shadow theatre illustration for a folk horror tale, layered cut paper with sharp angular edges and deep hard shadows between layers, visible paper grain, restricted palette of midnight indigo, bone white, dried-blood red and a little lantern amber, elongated severe faces with narrow eyes and no smile, eerie and tense, not cute, not childlike, centered portrait bust, no text, no border.*

Art is original to this app. Do not copy the published game's card art.

## 3. Rules every screen follows

1. **A player sees only what their role allows.** The host sees nothing extra.
2. **Every phone looks the same until held.** Secret information (your card, what you saw, your teammates) is behind press-and-hold and hides on release.
3. **Nobody stands out at night.** Every phone sends the same `choose`, from the same board. No sound or vibration may play on only the acting player's phone. (Amended by `first-time-play.md`.)
4. **Use the game's own words.** "Center" cards. Players "die". Masons are added as a pair. Nobody can choose not to vote.
5. **Errors say what happened in plain words.** A themed headline is fine if a plain second line follows.
6. **Lay screens out as a stack**, each part starting where the one above ends. Text is larger on some phones; nothing may rely on a fixed position to avoid overlapping.

## 4. The screens

| # | Screen | What it does |
|---|---|---|
| 1 | Join | Enter a name. Start a table or join one with a code. Shows how many players are online and your recent games. |
| 2 | The table (lobby) | The code, large enough to read aloud. Who is here. Tonight's deck. The host deals. |
| 3 | Build the deck (host) | Add and remove roles. Shows cards needed against cards chosen. Three deck chips (Simple, Classic, Chaos), built by the server for the player count (`first-time-play.md`). |
| 4 | Your card | Press and hold to see your role. Night starts when everyone has looked. |
| 5 | Night, between | Only while the next screen loads (`first-time-play.md`). |
| 6 | Night, your action | Pick a player or center cards. The button follows the server's prompt, so a slip cannot waste the turn; "Keep my card" does nothing, and a player with nothing to do picks any card (`first-time-play.md`, section 8). |
| 7 | Night, what you saw | Removed (`first-time-play.md`, section 7): what you saw is a page of "My night" on 8. When the night ends every phone goes straight to 8. |
| 8 | Talk | A large timer and little else. "My night" box. Cards in this game. A count of players ready to vote. |
| 9 | Vote | One name per row. Pick, then lock in. |
| 10 | The count | Who voted for whom, then who dies. Flip the dead player's card. |
| 11 | Results | Who won. Then the night in order, as a picture. Play again. |

Decisions that shape those screens:

- **Voting.** Pick a player, then tap "Lock in". Votes are revealed when everyone has locked in. The timer is only a backstop.
- **"My night" box.** One identical press-and-hold box for every player during the talk. It shows your dealt card, what you saw, and who your teammates were. A player who had no action sees "You slept." Progress is plain pips, with no tokens (`first-time-play.md`).
- **Results.** Columns are players, rows are the night in wake order. Each step shows what happened and where the cards moved. The Werewolf card's path is drawn in red. (Mock: D · Results.)
- **Play again.** The host taps it and everyone still connected returns to the lobby with the same players and the same deck. Anyone else taps "Leave".
- **The Doppelganger is in version 1.** It needs its own versions of screen 6 and of the "My night" pages for each role it can copy, and its result must say what it became.
- **Home screen extras.** Online count and recent games are in version 1. Photo avatars are last.

### Decided in the second mock round (19 November 2026)

- **Pictures over lists.** Wherever a player picks a card or a person, they tap a picture: role cards in the deck builder, face-down cards with the owner's token at night, token rows in the vote. Names always stay visible.
- **Build the deck** is a grid of the 12 role portraits. Tap adds or removes; chosen cards are lit with a count, the rest dimmed. **Press and hold a role card** to open a sheet that explains it (portrait, team, what it does, how it wins).
- **Pace** lives on the deck screen: talk, vote, night and Copy (the Doppelganger window) lengths; every length is the table's setting (`first-time-play.md`). The server already takes these as table settings.
- **Night, your action** shows the other players' face-down cards and the three center cards; the player taps the card to look at or swap.
- **No explanatory copy.** Screens say what to do in a few words. Lines that explain the design to the player are cut.
- **Type scale.** Headings 26 to 36, timers 64 to 84 (a compact one beside a picture 34), vote counts 28, 16 px for anything a player must read to act (body 16 to 17; names, buttons and the cue 16 to 24), 14 px for captions under cards and tokens, and no uppercase tracked labels on player screens (amended by `first-time-play.md`, which also drops the hero role name: your card is read in the held face). Nothing larger, except one **hero line** per screen, which follows its mock: the app's name on Join (46), the table code (46, tracked +0.08em), who dies (44) and who won (40). Every skin is held to this scale, heroes included.
- **The count** lists who voted for whom by name beside the accused (`first-time-play.md`).

## 5. How the night runs

**Decided: one shared window.** The server is still built the old way, one group of roles at a time, until this is done.

1. **Doppelganger window**, only if that card is in the deck. The Doppelganger looks at a player, copies the role, and if that role acts (Seer, Robber, Troublemaker, Drunk) does the action straight away. This window always lasts the same 10 seconds, whatever she does and even if the card is in the center, so its length gives nothing away. Anything she has not done in that time is skipped.
2. **Shared window.** Every player chooses at once. Every phone has the same board and sends the same `choose` (`first-time-play.md`).
   - When the window closes the server works through the choices in the official order: team views, Seer, Robber, Troublemaker, Drunk.
   - Only then is each player shown their result: Werewolves, Minion and Masons their team, a lone Werewolf the center card they picked, the Seer what they looked at, the Robber the card they took. Nobody is shown a result while others are still choosing. A team is shown only on "My night", never when the window opens (`first-time-play.md`).
   - A window never closes sooner than 8 seconds after it opens, even if everyone has chosen, and it always runs, even if nobody at the table has a choice.
3. **Dawn.** The Insomniac (and a Doppelganger who copied it) is shown their own card. Every phone shows a dawn screen so theirs does not stand out.

Who wakes as a Werewolf or Mason is decided by the card a player was **dealt**, plus a Doppelganger who copied that role. A player who was handed a Werewolf card during the night does not wake as one, and a player whose Werewolf card was taken still does.

This was tested before it was chosen: 200,000 random games across all 12 roles, every card the Doppelganger can copy, and 3 to 10 players gave identical cards and identical views under the shared window and under the role-by-role night. The games in `../onuw/reference-games.md` agree too.

The Daybreak expansion is not covered. Some of its roles put something on the table that others must see before choosing, and each of those would need its own window first.

## 6. When a phone drops or locks

- Keep the screen awake during a game.
- Wait 20 to 30 seconds before treating a player as gone.
- Never pause the talk. It happens at the table, not on the phones.
- At night and during the vote, the game waits for a missing player only up to that grace period.
- The host can carry on without a player who has left.
- If the host's phone drops for a minute, the host role passes to the next player who is connected, and goes back to the original host the moment they rejoin. It works in a game and at the table between games.

## 7. Sound

- **No narrator voice in version 1.** The narrator's lines appear as text.
- The design keeps one narrator slot so a single voice can be added later. When it is, it plays from the host's phone only and its lines contain no player names.
- No sound effect or vibration may reveal who acted (rule 3).

## 8. Left out on purpose

- Trivia, quizzes, rumours and mini-games while waiting.
- Tablet and landscape layouts.
- A settings screen for the app (volume and the like).
- Remote play as a designed mode. It may work, but nothing is built for it.

## 9. Still to decide

| Question | Until decided |
|---|---|
| **Game length controls.** Three pace presets, or separate timer sliders. | Three presets. |

Decided on 18 November 2026:

- **After a game** the host's "Play again" is the only way to restart. There is no "I'm staying" button.
- **Minion when only the Tanner dies** and no player is a Werewolf: the Tanner wins alone.
- **A Drunk who runs out of time** (or whose phone dropped): the server swaps their card with a random center card, as the card game requires. The pick is seeded and logged.
- **Hosting:** Vercel. The server must therefore work as short-lived copies: no countdowns or presence held in memory.

## 10. What this needs from the server

Built (see `backend/CLAUDE.md` and `docs/dev/debug-harness/contract.md`):

- The shared-window night (section 5), replacing the four separate steps.
- The Werewolf / Mason team fix: teams come from the cards dealt, not the cards held.
- **Play again:** a lobby can hold more than one game. `POST /api/lobbies/<code>/play-again/` (host only, after the results); the game socket sends `play_again`.
- **Countdowns survive a server restart:** timers are rebuilt from the stored deadlines at start-up and whenever a player fetches the game.
- **The host role passes on:** after a minute without the host's phone (`host_handover_seconds`, 0 to 600, 0 turns it off) the next connected player becomes the acting host; the original host gets it back the moment they reconnect. The server sends `host_changed`; the lobby and `/me/` say who holds the role.
- **Dropped players:** the server counts each player's open sockets, sends `player_presence` and shows `connected` in the player list. The grace period is the `disconnect_grace_seconds` setting (default 25 seconds, 0 to 60, 0 turns it off). Night and the vote carry on without a player gone longer than that; the talk never waits.
- **A missed night result:** `GET /me/` has `night_results`, so a phone that was offline when a window closed shows what it would have been told.
- A "do nothing" night action.
- A minimum length for each night window, so a fast window gives nothing away.

Not built yet (or not touched by the work above):

- Lock-in voting, with the reveal when all are locked. (Today a vote is final once sent and the votes are revealed when every player still being waited for has voted.)
- Something to tap at night for players with no action.
- Online player count and each player's recent games.
