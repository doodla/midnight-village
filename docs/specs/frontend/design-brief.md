# Midnight Village — Design Brief

This is the whole design reference for the app. It replaces the earlier set of 19 design files, which were deleted because they contradicted each other and described a look that was not chosen. Game rules live in `../onuw/`. Where this brief and the rules disagree, the rules win.

Mock screens: https://claude.ai/artifact/AQ2LuLA5KkRPXHiZoGb6j9 (page "Round 3", rows A, D and E). The mocks are the reference for look and layout. They are pictures, not the app.

## 1. What the app is

A phone companion for One Night Ultimate Werewolf played around one table. Each phone shows that player's secret card, their night action and their vote. A server runs every rule. The table is where the game happens; the phone stays out of the way unless it is needed.

- 3 to 10 players, about 10 minutes a game.
- Guests only. No accounts.
- Version 1 is for phones held upright, including a phone's browser. On a wider screen the phone layout is shown centered. Tablet and landscape layouts are later.

## 2. The look

**Chosen: "Shadow paper" (mock row D).** Cut-paper shadow theatre with menace. A second look, **"Night print" (mock row E)**, is wanted later behind a switch.

| | Shadow paper (version 1) |
|---|---|
| Ground, night | Indigo `#14172f` |
| Ground, day and vote | Cold dawn grey `#cfcbd6` |
| Paper and light text | Bone `#e9e2d0` |
| Danger, Werewolf, your pick | Dried blood `#8f2a24` (use `#c2413a` for thin lines on dark) |
| The one warm accent | Lantern amber `#e3a13a`, primary button only |
| Quiet text on dark | `#aab0cf` |
| Hairlines on dark | `#2c3160` |
| Headline type | Gloock |
| Body type | Figtree |
| Shapes | Squared corners (3 to 6px). Hard offset shadows, no soft glows. |

Rules for the look:

- Night screens are dark, day screens are light. Anyone can tell the phase from across the table.
- Two colours do most of the work. No pastel player colours. A player is a name and an ink-outlined initial.
- Timers should come from the world (a candle burning down, the pale sun climbing over the rooftops) with the number kept small beside it.
- Drifting specks are kept, redrawn as paper scraps and ash. Never more than 60 on screen at once. Test early on a mid-range Android phone in the browser and lower the count there if it stutters.
- **One layout, two skins.** Build every screen once. A skin may change art, colours and type only, so "Night print" can be added later without rebuilding screens.

### Role art

All 12 role pictures are generated from one style reference, then one illustrator tidies the set so they look like one hand made them.

Style used for the mocks: *cut-paper shadow theatre illustration for a folk horror tale, layered cut paper with sharp angular edges and deep hard shadows between layers, visible paper grain, restricted palette of midnight indigo, bone white, dried-blood red and a little lantern amber, elongated severe faces with narrow eyes and no smile, eerie and tense, not cute, not childlike, centered portrait bust, no text, no border.*

Art is original to this app. Do not copy the published game's card art.

## 3. Rules every screen follows

1. **A player sees only what their role allows.** The host sees nothing extra.
2. **Every phone looks the same until held.** Secret information (your card, what you saw, your teammates) is behind press-and-hold and hides on release.
3. **Nobody stands out at night.** Players with no night action get something to tap too. No sound or vibration may play on only the acting player's phone.
4. **Use the game's own words.** "Center" cards. Players "die". Masons are added as a pair. Nobody can choose not to vote.
5. **Errors say what happened in plain words.** A themed headline is fine if a plain second line follows.
6. **Lay screens out as a stack**, each part starting where the one above ends. Text is larger on some phones; nothing may rely on a fixed position to avoid overlapping.

## 4. The screens

| # | Screen | What it does |
|---|---|---|
| 1 | Join | Enter a name. Start a table or join one with a code. Shows how many players are online and your recent games. |
| 2 | The table (lobby) | The code, large enough to read aloud. Who is here. Tonight's deck. The host deals. |
| 3 | Build the deck (host) | Add and remove roles. Shows cards needed against cards chosen. Suggested decks for the player count. |
| 4 | Your card | Press and hold to see your role. Night starts when everyone has looked. |
| 5 | Night, waiting | The same dark screen on every phone. |
| 6 | Night, your action | Pick a player or center cards. A "do nothing" choice for optional actions. |
| 7 | Night, what you saw | The card you looked at or took. Hides by itself. |
| 8 | Talk | A large timer and little else. "My night" box. Cards in this game. A count of players ready to vote. |
| 9 | Vote | One name per row. Pick, then lock in. |
| 10 | The count | Who voted for whom, then who dies. Flip the dead player's card. |
| 11 | Results | Who won. Then the night in order, as a picture. Play again. |

Decisions that shape those screens:

- **Voting.** Pick a player, then tap "Lock in". Votes are revealed when everyone has locked in. The timer is only a backstop.
- **"My night" box.** One identical press-and-hold box for every player during the talk. It shows your dealt card, what you saw, and who your teammates were. A player who had no action sees "You slept through the night."
- **Results.** Columns are players, rows are the night in wake order. Each step shows what happened and where the cards moved. The Werewolf card's path is drawn in red. (Mock: D · Results.)
- **Play again.** The host taps it and everyone still connected returns to the lobby with the same players and the same deck. Anyone else taps "Leave".
- **The Doppelganger is in version 1.** It needs its own versions of screens 6 and 7 for each role it can copy, and its result must say what it became.
- **Home screen extras.** Online count and recent games are in version 1. Photo avatars are last.

## 5. How the night runs

**Decided: one shared window.** The server is still built the old way, one group of roles at a time, until this is done.

1. **Doppelganger window**, only if that card is in the deck. The Doppelganger looks at a player, copies the role, and if that role acts (Seer, Robber, Troublemaker, Drunk) does the action straight away.
2. **Shared window.** Every player chooses at once. Players with no action get something to tap.
   - Shown at once: Werewolves, Minion and Masons see their team; a lone Werewolf sees the center card they pick; the Seer sees what they looked at; the Robber sees the card they took.
   - Everything shown is read from the table as it stood when the window opened.
   - When the window closes the server applies the swaps in the official order: Robber, then Troublemaker, then Drunk.
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
| **"I'm staying" button** for non-host players after a game, with a count for the host. | Not built. Host's "Play again" only. |
| **Game length controls.** Three pace presets, or separate timer sliders. | Three presets. |
| **Minion when only the Tanner dies** and no player is a Werewolf. The rules file says both yes and no. | The Tanner wins alone, as the code does now. |
| **A Drunk who runs out of time.** The card game says the Drunk must swap. | No swap, as the code does now. |

## 10. What this needs from the server

None of this exists yet.

- The shared-window night (section 5), replacing the four separate steps.
- **A fix that is needed either way:** the engine works out the Werewolf and Mason teams from the cards players hold now, not the cards they were dealt. After the Doppelganger swaps cards this shows players the wrong team, and it wrongly refuses a lone Werewolf's look at the center. About 1 game in 60 in random play; reference games 4, D2 and D3 trigger it.
- Play again: a lobby that can hold more than one game.
- Countdowns that survive a server restart.
- Noticing a dropped player, the grace period, and continuing without them.
- Lock-in voting, with the reveal when all are locked.
- A "do nothing" night action.
- A minimum length for each night window, so a fast window gives nothing away.
- Something to tap at night for players with no action.
- Online player count and each player's recent games.
