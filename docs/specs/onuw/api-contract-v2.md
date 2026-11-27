# Midnight Village — the ONUW server API

What the server answers today, endpoint by endpoint and event by event. There is one game
flow: the look stage, the choose night, the talk, the vote, the results. Real bodies for every
situation below are recorded in `contract_samples/` (`index.json` lists them); where this page
and a sample disagree, the sample is what the server sends and this page is wrong.

All paths are under `/api/` (core) or `/api/onuw/` (the game). Errors are `{"detail": ...}`,
most with a machine `code`. Lock order is **Game → PlayerRole → Lobby → LobbyMember**; every
socket send and timer change runs after commit. Code: `backend/apps/onuw/README.md` (the game)
and `backend/apps/core/README.md` (tables, presence, timers). Rules: the rest of
`docs/specs/onuw/`. Screens: `docs/specs/frontend/first-time-play.md`.

---

## 1. Principles the API keeps

- **Counts, never names.** While a stage runs, the table learns how many have looked, are
  ready or have locked in (`progress`), never who, never what anyone picked.
- **A phone with a choice sends one `choose` per window** (only the Doppelganger may send
  a second in window 1); a phone with nothing to choose (its prompt's `kind` is `none`)
  sends nothing and is never waited for. Every answer has the same keys and status, a
  choose from a phone with nothing to choose included; what differs is the caller's own
  part (its results and `chooses_left`), as in its `/me/`. A window's close depends only
  on the taps of the phones with a choice, presence and the clock.
- **Every request names its stage.** A stage-scoped request carries the `stage` that
  `GET /me/` returned; one for a stage that is over is `409 wrong_stage` and does nothing.
- **Sending a request twice leaves the game as sending it once did** (section 9).
- **Refusals never depend on a role.** Generic messages and codes (`bad_request`,
  `wrong_stage`, `already_chosen`, ...).
- **Nothing waits beyond the table's settings.** A stage ends when everyone present has done
  their part, or at its deadline; window 2 never closes before `night_min_window_seconds`.
- **A phone is told, not asked.** When a stage opens, each person's own `/me/` is sent on
  that person's own socket group just before the table's event (section 8, `me`); a tap's
  answer carries what was stored (section 6). A phone reads `/me/` only when what it holds
  is behind what it hears (an older server, a lost message), and `/me/table/` only when its
  seat may have changed.

## 2. Tables (core)

- `POST /lobbies/` `{"game_type": "onuw", "defaults": "v2"}` opens a table. `defaults: "v2"`
  (the app's starting set) writes `card_look_seconds: 30`, `deck: "auto"`,
  and `deck_chip: "simple"`, and nothing else (no timer length; settings
  given in the body win, `seats` among them: a table can be opened already set for a number).
  A table opened before 23 November 2026 may still store `night_protocol: 2`; it is ignored.
  Any other `defaults` value is `400 bad_request`; without it nothing is written. The merged
  settings are validated (`400 bad_request` with the errors).
- `GET /lobbies/<code>/`, and every lobby answer and `lobby_update` event, carry the whole
  table: `host`, `original_host_id`, `is_acting_host`, `status`, `max_players` (3 to 10),
  `settings`, `players[]` (`user`, `token`, `joined_at`, `connected`), `rev`, and the
  game's extras:
  - `rev`: the table's number, an integer that starts at 0 on a new table (the create
    answer has it) and only rises. Every change the table is told about (a lobby answer, a
    `lobby_update`, a `host_changed`) raises it by one, and everything a write changes gets
    a higher number, in the order the changes were committed (the deal and a game's end
    raise it too). A read (`GET`, the create answer) does not raise it: it carries the
    number of the row it read. One request that answers with the body and sends it as
    `lobby_update` gives both the same number; a request refused, or one that tells nobody,
    leaves it as it was. **The phone's rule:** show a lobby when its `rev` is equal to or
    higher than the newest it has shown; never show a lower one. Equal does not mean
    identical, in exactly two cases: (a) `players[].connected`, because presence partly
    follows time, not a write (two bodies with one `rev` may differ there); (b) a read may
    show content newer than its number, never older (a read that crosses a write: newer
    members, or across play again and a new deal the new game's deck, under the older
    number). So a later builder must not turn "equal" into "skip": a body with an equal
    `rev` is shown. Three more rules:
    - A `host_changed` counts as shown at its `rev`: after it, a body with a lower `rev` is
      not shown (else a read sent before the handover puts the old host back). And a
      `host_changed` whose own `rev` is lower than the newest shown is ignored, like a body
      (else a handover that arrives late puts an older host back).
    - A body or event with NO `rev` (an older server build, during a deploy) is shown as
      today and leaves the newest number as it is.
    - The number belongs to one table: keep the newest per table, its `code` together
      with its `created_at`. A new table, or a table code used again, starts at 0.
  - `deck_preview`: the automatic deck the deal would build for the table's size (the
    number it is set for, `settings.seats`; at an open table the players here now) and its
    `deck_chip` (`{role: count}`, the shape of `settings.roles`); null for a custom deck or a
    size with no automatic deck.
  - `deck_cards`: the roles the table would deal (`{role: count}`, counts above 0), face up
    for every viewer (which roles are in the game is public at the table): a custom deck's
    cards as picked so far; an automatic deck's for the table's size, and for an open table
    of fewer than 3 the deck of the smallest game (3 players), the one it deals first.
  - `lengths`: every length the game would run with if dealt now, in seconds, one per timer
    setting (`discussion_seconds`, `voting_seconds`, `night_wave_seconds`,
    `night_min_window_seconds`, `night_doppelganger_window_seconds`, `card_look_seconds`,
    `disconnect_grace_seconds`, `host_handover_seconds`): what a game dealt now runs with
    (the table's own value as the deal clamps it, else the game's default; the shortest
    window cut to the window as the night cuts it), each inside its own range.
  - `length_ranges`: `{key: [least, most]}` seconds a PATCH of each length takes now, from
    the same rule table the check uses (`engine/validation.py`): 0 to the key's most; this
    server's floors for a night window (1 s) and the shortest window (5 s) unless it allows
    untimed nights; the shortest window never longer than the window; and (again unless
    untimed games are allowed) no stage waits for good: with `disconnect_grace_seconds` 0 the window, the talk and the vote each need a
    clock of at least 1 s, and with any of them at 0 the grace period is at least 1 s.
  - `seats_range`: `[least, most]` the number of players may be set to now: never below the
    players here (nor 3), never above `max_players` (nor 10).
  - In a game (the table not waiting), `deck_cards` and `deal.have` are the deck the newest
    game was dealt, not a deck for whoever is here now.
  - `deal` `{"ok", "need", "have", "seats"}`: `ok` is exactly whether the deal would be
    accepted now (waiting, 3 to 10 players and, at a table set for a number, exactly that
    many; a legal deck of the right size, valid settings; only the host check is left out);
    `seats` = the number the table is set for, null for an open table; `need` = `seats` + 3,
    or the players here + 3 at an open table, so at a table set for a number it never moves
    when people join or leave; `have` = the cards in the deck the deal would use (0 if
    none). The phone holds no deck-size rule.
  - `players[].connected`: the member's phone is at the table (a lobby socket or a socket on
    the newest game). A phone that drops stays `true` for `disconnect_grace_seconds`, then
    the table hears a `lobby_update` with `false`; a phone back after being shown as gone
    sends one at once. A member never seen with a socket is `false`.
  - `players[].practice: true` marks a practice player (a seat the server plays; see below;
    always `connected`). Nobody else has the key.
  - `practice: {"most": n}`, only at a table that switched practice players on or has some
    seated: how many may sit now (those seated plus the free seats).
- `lobby_update` is also sent when a member joins or leaves.
- **Practice players.** `POST /lobbies/<code>/practice/` (host, waiting tables) with
  `{"on": true | false}` and/or `{"count": n}`: on or off for the table (`settings.practice`;
  off takes every one away), and how many sit (a target, so a resend changes nothing; above 0
  switches them on). Answers the lobby body; the table hears `lobby_update`. `400
  bad_request` (malformed), `400 lobby_full` (past the free seats), `403` not the host, `404
  lobby_not_found`, `409 lobby_closed` once dealt. They take seats like anyone (tokens,
  `seats`, "Start game"), are named for village things ("Scarecrow", "Teapot", ...), never
  host (handover and the owner leaving skip them; the last person out closes the table) and
  never drop. A person joining a full table takes the newest one's seat.
  A person has practice players at one table at a time:
  switching them on, or `POST /lobbies/`, takes them off the caller's other tables that are not in a game (those tables hear `lobby_update`).
  The settings `PATCH` and a new table's settings ignore `practice`.
  In the game the
  server plays them through the same requests a phone sends, the moment each stage opens
  (`backend/apps/onuw/README.md`, "Practice players"); every players list marks them
  `practice: true`. An app that knows nothing of them shows them as ordinary players.
- `PATCH /lobbies/<code>/` (host, waiting tables): `{"settings": {...}}` is MERGED into the
  stored settings (a key given again is replaced whole). `deck` is `auto` or `custom`;
  `deck_chip` is `simple`, `classic` or `chaos`; with `auto` the deal builds the deck
  (`engine/decks.py`, the table in `recommended-setups.md`, "Automatic Decks"). `seats` is
  the number of players the game is for: a whole number from 3 to 10, or null (an open table,
  which deals to whoever is there: every table before this key, and a new table until the
  host picks a number). It may change any time before the deal within `seats_range` (`400`
  otherwise); an automatic deck follows it, a custom deck is never changed (`deal`
  says whether it still fits). Only the keys the PATCH gives are validated (a value older
  code stored and nobody touches never blocks a change; `400 {"detail": [...]}` for a bad
  one); of `roles` only each role's own limits (a known role, 0 to its most, Masons in
  pairs): a deck being built is stored card by card and `deal` reports its size.
- `POST /lobbies/<code>/join/`: `400` `already_in_lobby`, `lobby_closed`, `lobby_full` (every
  seat taken: `max_players`, or the number the table is set for);
  **one table at a time**: a member of another WAITING table (active within
  `CORE_TABLE_RESUME_HOURS`) gets `409 {"detail": "You are already at another table.",
  "code": "already_at_table", "lobby_code": "<that table>"}`. A table in a game or finished
  does not block a join; anyone can leave a waiting table, so this never traps.
- `POST /lobbies/<code>/leave/`: `200` when left (the last one out closes the table); `400
  {"code": "not_in_lobby"}` when this player is not at the table (an earlier leave got
  there: the app counts it as left), `404` when the table is gone, `409` while a game runs.
- `POST /lobbies/<code>/play-again/` (host, after the
  results; the table goes back to waiting and hears `play_again`). There is no lobby ready
  flag: the deal checks nobody's readiness.
- Tokens: ten seat tokens (`crow`, `key`, `moth`, `bell`, `thorn`, `antler`, `hare`,
  `lantern`, `spindle`, `scythe`), assigned under the Lobby lock from a permutation seeded by
  the table code, kept across play again, freed on leave. The deal snapshots each player's
  token and seat (join order) into the game.
- `GET /me/table/` ("where am I"): `{"table": {"lobby_code", "game_type", "status",
  "is_host", "token", "game": {"game_id", "phase"} | null}}` or `{"table": null}`. The
  caller's newest table that is in a game or active within `CORE_TABLE_RESUME_HOURS`; `game`
  is its newest game if the caller plays in it. The app routes on this alone.
- `GET /stats/online/` (no auth, `Cache-Control: public, max-age=15`): `{"players",
  "tables"}` counted from fresh socket rows.

## 3. The deal

`POST /onuw/lobbies/<code>/start/` (host): `201 {"game_id", "phase": "night"}`. There is no
ready check: everyone at the table is dealt in. Refused with `400 {"detail": ...}` for the
reason the lobby body's `deal.ok` reports (`"Lobby is not in waiting state."`, too few
players, a deck that does not fit, invalid settings); `403` for a non-host. The Lobby row lock
makes a second deal impossible. Timer settings, all optional (seconds):
`card_look_seconds` (0 to 120), `night_doppelganger_window_seconds`, `night_wave_seconds`,
`night_min_window_seconds`, `discussion_seconds`, `voting_seconds`,
`disconnect_grace_seconds`, `host_handover_seconds`. Where the Django setting
`ONUW_ALLOW_UNTIMED_NIGHT` is false (production), a night window of 0 and a minimum window
under 5 are refused when a lobby PATCH sets them; a table that older code stored with
such values is not stuck: the deal clamps them (a night timer of 0 takes the server's default
length, a minimum window under 5 becomes 5, a value out of range takes the default) and the
game gets the clamped settings. `night_protocol` is ignored (see section 2).

DEBUG only (`403` in production): `{"debug": {"forced_assignment": ...}}` or
`{"debug": {"seed": n}}`; the oracle `GET .../debug-state/` and
`POST .../debug-fire-timer/` (`docs/dev/debug-harness/contract.md`).

## 4. `GET /onuw/games/<id>/me/`

The caller's own view, the same keys in every phase:

| Key | |
|---|---|
| `game_id`, `lobby_code`, `phase`, `current_wave` | `phase` is `night`, `discussion`, `voting` or `results`; `current_wave` 0 (the look), 1 or 2 at night |
| `deadline`, `stage_started_at` | when the open timed stage ends and began (ISO 8601 in UTC ending in `Z`, as every time the server sends: `apps/core/wire.py`); both null when the stage is untimed. A restart's reconnect allowance moves `deadline`, never `stage_started_at` |
| `stage` | the token every stage-scoped request sends back (`look.<g>`, `w1.<g>`, `w2.<g>`, `talk.<g>`, `vote.<g>`, ...) |
| `player_id`, `is_host`, `host_id` | the caller's own id; who hosts now |
| `your_role` | `{"original_role"}`; at the results also `current_role` and `night_action_data` |
| `players[]` | `player_id`, `display_name`, `token`, `seat`, in seat order, and `practice: true` for a practice player (who is connected: `GET .../players/`) |
| `roles_in_game` | the deck |
| `action_prompt` | in an open window, for every player (section 5); otherwise null |
| `night_results`, `night_results_seen` | the caller's own results of closed windows (and, in the open window, the Doppelganger's look and any result settled at the caller's choose), and how many the phone has shown |
| `ready`, `progress` | the caller's own flag and `{stage, done, needed}` in the look and the talk; `progress` in the vote too |
| `my_vote`, `vote_targets` | in the vote: `{"target_player_id", "locked"}` (own only) and the ids the caller may vote for, in seat order (everyone else) |

`404` for an unknown game, `403` for someone who does not play in it.

**Which of two views is newer.** Within a game the stage only moves forward, phase then
window (the look, window 1, window 2, the talk, the vote, the results; `protocol.py`), and
every stage happens once. So of two `/me/` of one game, the one whose (`phase`,
`current_wave`) is later is the newer; of two at the same stage, a read made after the
stage opened is as new as the view sent when it opened, or newer. The phone keeps the
newest by that compare; an older one (a read that crossed a view) changes nothing. The
same body is what the socket sends as `me` (section 8): one builder (`own_view.me_body`).

## 5. The night

**The look stage.** With `card_look_seconds > 0` the deal opens no window: the game is in
night, window 0, with the look deadline (timer `<game>:look`, job `card_look`) and
`progress {stage: "look", done: 0, needed}`. Every phone sends
`POST .../ready/ {"ready": true, "stage"}` (`false` is `400 bad_request`: looking is one
way). The night opens when every player not gone past grace has looked, at the deadline, or
when the host sends `advance-wave`. With 0 the deal opens the first window at once.

**Windows.** Window 1 is the Doppelganger's (only when she is in the deck); window 2 is
everyone else's. A window opens with ONE group event, `night_window {window, deadline}`,
the same for every phone; just before it, in the same batch, each person's own group
carries their own view (`me`, section 8), with their prompt, so no phone asks for it. A
phone that holds no view of that window when the event comes reads `/me/`:

`action_prompt`: `window`, `kind` (`none`, `seer`, `robber`, `troublemaker`, `drunk`,
`lone_werewolf`, `doppelganger_look`), `role_acting_as` (the caller's own), `shapes` (which
picks would do something, as data, e.g. `[{"players": 1}, {"center": 2}]`), `action_types:
["choose"]`, `max_picks` (2), `max_chooses` (what the server accepts: 2 in window 1, 1 in
window 2), `chosen` (how many the server holds), `chooses_left` (0 or 1: what this phone
should still send; 0 from the start when `kind` is `none`: that phone sends nothing), and
`valid_targets`, the same board for everybody. No teammates.

`POST .../action/`:

```json
{"action_type": "choose", "picks": [{"player_id": 14}], "chosen": 0, "stage": "w2.…"}
```

- From a phone with a choice (one sent by any other player is taken alike and does
  nothing), 0 to 2 distinct ordered picks: `{"player_id": n}`,
  `{"center_index": n}`, `{"self": true}` (your own id is `self`).
- The server reads them per role: Seer two centre cards or the first other player; Robber
  the first other player; Troublemaker two other players; Drunk the first centre card; a
  lone Werewolf the first centre card; the Doppelganger's look the first other player;
  everything else nothing. Her FIRST choose in window 1 is her look; her follow-up is read
  as the copied role.
- Picks that mean nothing are no error: the window's close applies the role's default (a
  Drunk is swapped by the server, `made_by_server`; team views and the Insomniac still
  happen; Seer, Robber, Troublemaker and the look skip).
- Every choose answers `200 {"status": "submitted", "night_results": [...],
  "chooses_left": n}`: the caller's own `night_results` exactly as `/me/` lists them right
  after the choose (and any close it caused), and its prompt's `chooses_left` (0 once the
  window is over). A resend gets the same. Refusals: `400 bad_request`
  (malformed picks, any other `action_type`, `chosen` or `stage` missing), `409
  wrong_stage`, `409 already_chosen` (a prompt that is used up), `403` for someone who does
  not play in the game.
- `chosen` names the prompt the choose answers: lower than the server's count is a resend
  (the same 200, nothing stored), equal is a new choose, higher is `400`. The phone shows
  the answer's `night_results` at once and keeps them; it re-reads `/me/` only when
  `chooses_left` is above 0 (the Doppelganger's follow-up is a new turn) or when the answer
  has no `night_results` (an older server, during a deploy).

**Closing.** Window 2 closes when every present phone WITH a choice (`chooses_left` above
0; not gone past grace; one inside its grace holds it) has chosen, never before
`night_min_window_seconds` (counted from the window's opening), else at its deadline. A
phone with nothing to choose is never waited for, dropped or not; a table where every phone
is away waits for one to come back. Window 1 keeps its fixed length
(`night_doppelganger_window_seconds`); with that setting 0 (untimed tables only) it closes
once the Doppelganger has looked and, when her copy chooses in window 1, sent her
follow-up. The host
may close any window with `POST .../advance-wave/ {"stage"}`. A closed window's results
are in each phone's `/me/`; the last window's close moves the game to the talk
(`phase_change`).

**Own results** (`night_results[]`: `wave`, `action_type`, `revealed_info`): role names are
canonical (`"Werewolf"`); a `peek_center` result carries `center_indices` (in the order of
`roles`); a result that is the role's default because nothing chosen meant anything carries
`"nothing_chosen": true` (the caller's own `skip` entries, the Drunk's server swap, a lone
Werewolf who looked at no centre card). The Doppelganger's look is listed as soon as it
resolves. **A result settled at the choose is listed from the choose on** (in its answer
and every `/me/` after it), not at the close: one that no step resolving before it in the
window can change (`engine/night.py`, `settled_at_choose`, decided from the roles, never
from who holds what). That is the Seer (she resolves first in window 2; nothing moves cards
before her), the Robber (only the Seer is before her), the Troublemaker and the Drunk
(their results name only their own picks; the Drunk's server swap is seeded, so it is
settled too), a lone Werewolf's centre look (group 2, before every move), and the
Doppelganger's follow-up as any of these (window 1 holds only her). It is exactly the
entry the close then writes. Everything else waits for the close: the Insomniac (every
swap comes first), team views, a Doppelganger who copied the Minion. A window-2 choose
cannot be changed (`max_chooses` 1), so a shown result is never taken back.

`POST .../night-results/seen/ {"seen": n}` (0 to 10) stores how many results the phone has
shown: `{"night_results_seen": n}`, monotonic (`GREATEST`), clamped to what the caller can
see. Every phone acks once after each window's dawn screen.

## 6. The talk and the vote

**Talk.** `phase_change {phase: "discussion", deadline}` and `progress {stage: "talk", done:
0, needed}`. `POST .../ready/ {"ready": true|false, "stage"}` toggles "ready to vote"
(`{"status": "ok", "ready": ..., "progress": {stage, done, needed}}`: the stored flag and the
count the table was sent for this tap, so the tapper's phone reads nothing after it; the
look's ready answers alike); when every present player is ready the talk ends, as when
the host sends `POST .../end-discussion/ {"stage"}` or the deadline passes. An answer from a
server before 27 November 2026 has no `progress`: the phone then reads `/me/` as before.

**Vote.** `phase_change {phase: "voting", deadline}` and `progress {stage: "vote", ...}`.

```json
{"target_player_id": 14, "lock": false, "stage": "vote.…"}
```

- `lock` is required. `false` picks or re-picks (`{"status": "picked",
  "target_player_id": 14}`); `true` picks and locks in one call (`{"status": "submitted",
  "target_player_id": 14, "locked": true, "progress": {...}}`: the stored lock and the count
  the table was sent). A pick sends no event; a lock sends `progress`.
- After locking: the same lock again is the same 200 (nothing stored or sent); any other pick
  or lock is `409 vote_locked`.
- `400`: `invalid_target` (yourself, someone not in the game), `bad_request`
  (`target_player_id` not a JSON integer, `lock` not a bool, no `stage`); `409
  wrong_stage`; `409 stale_request` (an older `asked`, section 9); `403` for someone who
  does not play in the game.
- The votes are revealed when every present player has locked, at the deadline, or when the
  host sends `POST .../reveal-votes/ {"stage"}`. At any reveal every stored pick counts,
  locked or not (an unlocked Hunter pick triggers the Hunter chain); no pick is a non-voter.
  The table hears `vote_reveal {votes}` and `game_results`; each person's own view of the
  results comes just before them, with the results body (`GET .../results/`), so nothing is
  asked for the end board.

## 7. Results and history

`GET .../results/` (results phase only; `403` before, and for someone who did not play):
`players[]` (`token`, `seat`, `original_role`, `final_role`, `team`, `is_eliminated`,
`elimination_reason`, `outcome`, `vote_target_id`), `winning_teams`, `reason`,
`eliminated_players`, `center_cards`, `night_actions_log` and `night_timeline`:

- `night_timeline` replays the night over the dealt cards (`engine/timeline.py`, pure):
  `seats`, `cards` (one per physical card, `card_id` `k0..`, `role`, `werewolf`), `dealt`,
  `steps[]` (`step`, `window`, `order_group`, `role`, `actors`, `doppelganger_actors`,
  `action`, `made_by_server`, `looked_at`, `team`, `copied_role`, `moves`,
  `positions_after`), `final`, `center_moved`. Team views of one role merge into one step,
  in the order of the rules. Null (and logged) whenever it cannot be built; the rest of the
  results still show.

`GET /onuw/me/recent-games/?limit=5` (max 10): the caller's finished games, newest first
(`game_id`, `ended_at`, `player_count`, `winning_teams`, `you_won`). `GET
/onuw/me/current-game/`: the caller's running game, if any. `GET .../players/`: the players
with `connected`.

## 8. Socket events

Game socket (`/ws/game/<id>/`): `night_window`, `progress`, `phase_change`, `vote_reveal`,
`game_results`, `player_presence {player_id, connected}`, `host_changed`, `play_again`, and
`me`.
Lobby socket (`/ws/lobby/<code>/`): `player_joined`, `player_left`, `lobby_update`, `game_started`, `host_changed`.
`host_changed` is `{host_id, host_name, original_host_id, reason, rev}` on both sockets:
`rev` is the table's number after the change (section 2; an event from a server instance
older than `rev` has no key). Every consumer drops an event type it does
not know, so an older instance never closes a socket over a newer event. Every event the
table hears is a count, a window number, public identity or the end of the game.

**`me`: a player's own view.** `{"type": "me", "me": <GET /me/ body>}`, and at the results
also `"results": <GET .../results/ body>`, sent when a stage opens (each night window, the
talk, the vote, the results), first in the same batch as the table's event, to each person
of the game (not to practice players). It goes ONLY to that player's own group
(`game_<id>_player_<user id>`), the group named from the view's own `player_id`, and the game
socket forwards it only to a socket signed in as that `player_id`; nothing of one player's is
ever on the game's group (`tests/onuw/test_own_view.py`, `test_contract_privacy.py`). The
phone applies it when its stage is later than the `/me/` it holds (section 4), and then the
table's event asks nothing; a phone that holds no such view when the event comes (a server
before 27 November 2026, a lost message) reads `/me/` as before. An older app drops the type.
`player_joined` and `player_left` carry only their type; the `lobby_update` sent with each
carries the whole table, so the app reads nothing on them.

## 9. Sending a request twice

A phone whose answer is lost sends the same request again. Sending it twice leaves the game
as sending it once did (`backend/tests/onuw/test_resend.py`):

| Request | A resend while its stage is open | A resend after its first copy ended the stage |
|---|---|---|
| `choose` | `chosen` lower than the server's count: the same 200, nothing stored | `409 wrong_stage` |
| `ready` (look, talk) | sets the same value: same answer | `409 wrong_stage` |
| `vote` pick | stores the same pick; after its own lock `409 vote_locked` | n/a |
| `vote` lock | the same 200 (the stored lock and the count read again), nothing stored or sent | `409 wrong_stage` |
| `night-results/seen` | `GREATEST`: same answer | no stage |
| `advance-wave`, `end-discussion`, `reveal-votes` | end their stage | `409 wrong_stage` |
| lobby `start` | n/a | `400` "Lobby is not in waiting state." |
| lobby `play-again` | `200`, the same lobby body (a read: the same `rev`) | `409` once the next game is dealt |
| lobby `join` | state unchanged; `400 already_in_lobby` | n/a |
| lobby `leave` | state unchanged; `400` (`404` if the table is gone) | n/a |
| lobby `PATCH` | the same values: same answer (told again, so `rev` one higher) | n/a |
| lobby `practice` | the same switch and count: same answer (told again, so `rev` one higher) | `409 lobby_closed` once dealt |

For `join`, `leave` and `start`, whose second answer differs, the app treats the answer to
its own resend as success and reads the table again.

**A late request (`asked`).** A request whose answer was lost may still reach the server
after a newer one from the same phone. So a settings `PATCH`, `practice`, `vote` and `ready`
may carry `"asked": <int>`: when the tap was made, in milliseconds since 1 January 1970 by
that phone's own clock (never a count from when the app opened: that starts again with the
app), always rising on that phone, at most 2^53 - 1. The server never compares it with its own clock, only with the newest
`asked` it applied for the same thing, and never between two people. A request older than
that changes nothing: `409 {"detail": "A newer tap from this phone already got there.",
"code": "stale_request", "newest": <int>}`, where `newest` is the stored `asked` it lost to
(for a `PATCH` whose every key lost, the largest of them); it is always the caller's own
number, never another player's. An equal `asked` is the same tap sent again. Without `asked`
a request works as before. `asked` that is not a whole number of 0 or more is `400
bad_request`.

A phone whose NEWEST tap is answered stale may send it again with an `asked` above `newest`
(its clock is behind what the server holds); a phone that has sent something newer since
just reads again.

The limit: the server keys `asked` by player, not by phone. The same player on a second
phone whose clock is behind the first's, or a phone whose clock was set back, is answered
stale until it sends above `newest`: at a table that lasts the table's life, in a game until
the stage ends.

| Request | Compared with | When older |
|---|---|---|
| lobby `PATCH` | per settings key: the newest `asked` that set it, if it was this player's | that key is dropped; the other keys apply (`200`); every key dropped: `409 stale_request`, nothing sent |
| lobby `practice` | the newest `asked` of this player's practice requests | `409 stale_request` |
| `vote` (pick or lock) | this player's newest applied vote in this stage | `409 stale_request`; checked after every other refusal, so a locked vote still answers `vote_locked` and its same lock again `200` |
| `ready` | this player's newest applied ready in this stage (the look and the talk are compared apart) | `409 stale_request`; checked after every other refusal |
| `choose`, `night-results/seen`, stage-ending requests | not read (already safe: `chosen`, `GREATEST`, `stage`) | n/a |

The app sends a phone's requests one at a time and retries only the latest; `asked` covers a
request whose answer was lost that still arrives after the next one was applied.

## 10. Accepted tells and limits

- Who taps at night: only a phone with a choice sends a `choose` (product owner, 20
  November 2026: a friendly game; a sleeper is never asked to act or waited for). Someone
  watching the table or the network can tell who had something to choose, never what.
- An armed Doppelganger's phone is the only one that sends a second `POST .../action/` in
  window 1. Someone watching the network can see that extra request (not its content), and
  the `GET /me/` her phone sends after her look (its answer's `chooses_left` is 1).
- A choose's answer carries the caller's own results, so its size varies with what they
  learned, as a `/me/` already does; its `Server-Timing` does not (the same work for every
  caller: `tests/perf/test_header_hides_play.py`). A player's own view (`me`) is a `/me/`, so
  its size varies the same way; every person gets one at the same moments, whatever they
  hold.
- Human tells (thinking time) are out of the server's reach; phones keep sound and haptics
  identical.
- At a table with practice players, the request that opens a stage (the last "ready", the
  choose that closes a window) waits while the server plays them: one request each per
  practice player whatever their cards, so its time says how many there are, never what
  they hold (a practice Doppelganger's look resolving is the same accepted tell as a
  person's).
- The online count misses people on the home screen (it counts players at tables).
- The timeline assumes every card move is logged; a future role that moves cards outside the
  log must log its moves, or `night_timeline` is null.

## Pace presets (client)

The deck screen writes these numbers with the deck; the server only validates them. The
Doppelganger's window and the night's minimum window are not pace knobs.

| preset | `discussion_seconds` | `voting_seconds` | `night_wave_seconds` |
|---|---|---|---|
| quick | 180 | 45 | 20 |
| normal | 300 | 90 | 30 |
| long | 480 | 120 | 45 |
