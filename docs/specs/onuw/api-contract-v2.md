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
  sends nothing and is never waited for. Every answer is the same bytes, a choose from a
  phone with nothing to choose included, and a window's close depends only on the taps of
  the phones with a choice, presence and the clock.
- **Every request names its stage.** A stage-scoped request carries the `stage` that
  `GET /me/` returned; one for a stage that is over is `409 wrong_stage` and does nothing.
- **Sending a request twice leaves the game as sending it once did** (section 9).
- **Refusals never depend on a role.** Generic messages and codes (`bad_request`,
  `wrong_stage`, `already_chosen`, ...).
- **Nothing waits beyond the table's settings.** A stage ends when everyone present has done
  their part, or at its deadline; window 2 never closes before `night_min_window_seconds`.

## 2. Tables (core)

- `POST /lobbies/` `{"game_type": "onuw", "defaults": "v2"}` opens a table. `defaults: "v2"`
  (the app's starting set) writes `card_look_seconds: 30`, `deck: "auto"`,
  `deck_chip: "simple"` and `night_protocol: 2`, and nothing else (no timer length; settings
  given in the body win). `night_protocol: 2` is for the server code before the protocol-1
  cleanup, which still serves for a moment during a deploy; this code ignores it (and writes
  it on every game it deals too). It goes in a later push (`docs/dev/status.md`).
  Any other `defaults` value is `400 bad_request`; without it nothing is written. The merged
  settings are validated (`400 bad_request` with the errors).
- `GET /lobbies/<code>/`, and every lobby answer and `lobby_update` event, carry the whole
  table: `host`, `original_host_id`, `is_acting_host`, `status`, `max_players` (3 to 10),
  `settings`, `players[]` (`user`, `token`, `joined_at`, `connected`), and the
  game's extras:
  - `deck_preview`: the automatic deck the deal would build now for the players at the
    table and the table's `deck_chip` (`{role: count}`, the shape of `settings.roles`); null
    for a custom deck or a player count with no automatic deck.
  - `deal` `{"ok", "need", "have"}`: `ok` is exactly whether the deal would be accepted now
    (waiting, 3 to 10 players, a legal deck of the right size, valid settings; only the host
    check is left out); `need` = players + 3; `have` = the cards in the deck the deal would
    use (0 if none). The phone holds no deck-size rule.
  - `players[].connected`: the member's phone is at the table (a lobby socket or a socket on
    the newest game). A phone that drops stays `true` for `disconnect_grace_seconds`, then
    the table hears a `lobby_update` with `false`; a phone back after being shown as gone
    sends one at once. A member never seen with a socket is `false`.
- `lobby_update` is also sent when a member joins or leaves.
- `PATCH /lobbies/<code>/` (host, waiting tables): `{"settings": {...}}` is MERGED into the
  stored settings (a key given again is replaced whole). `deck` is `auto` or `custom`;
  `deck_chip` is `simple`, `classic` or `chaos`; with `auto` the deal builds the deck
  (`engine/decks.py`, the table in `recommended-setups.md`, "Automatic Decks"). Only the keys
  the PATCH gives are validated (a value older code stored and nobody touches never blocks a
  change; `400 {"detail": [...]}` for a bad one).
- `POST /lobbies/<code>/join/`: `400` `already_in_lobby`, `lobby_closed`, `lobby_full`;
  **one table at a time**: a member of another WAITING table (active within
  `CORE_TABLE_RESUME_HOURS`) gets `409 {"detail": "You are already at another table.",
  "code": "already_at_table", "lobby_code": "<that table>"}`. A table in a game or finished
  does not block a join; anyone can leave a waiting table, so this never traps.
- `POST /lobbies/<code>/leave/`, `POST /lobbies/<code>/play-again/` (host, after the
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
| `deadline`, `stage_started_at` | when the open timed stage ends and began (ISO 8601 with offset); both null when the stage is untimed. A restart's reconnect allowance moves `deadline`, never `stage_started_at` |
| `stage` | the token every stage-scoped request sends back (`look.<g>`, `w1.<g>`, `w2.<g>`, `talk.<g>`, `vote.<g>`, ...) |
| `player_id`, `is_host`, `host_id` | the caller's own id; who hosts now |
| `your_role` | `{"original_role"}`; at the results also `current_role` and `night_action_data` |
| `players[]` | `player_id`, `display_name`, `token`, `seat`, in seat order (who is connected: `GET .../players/`) |
| `roles_in_game` | the deck |
| `action_prompt` | in an open window, for every player (section 5); otherwise null |
| `night_results`, `night_results_seen` | the caller's own results of closed windows (and the Doppelganger's look at once), and how many the phone has shown |
| `ready`, `progress` | the caller's own flag and `{stage, done, needed}` in the look and the talk; `progress` in the vote too |
| `my_vote`, `vote_targets` | in the vote: `{"target_player_id", "locked"}` (own only) and the ids the caller may vote for, in seat order (everyone else) |

`404` for an unknown game, `403` for someone who does not play in it.

## 5. The night

**The look stage.** With `card_look_seconds > 0` the deal opens no window: the game is in
night, window 0, with the look deadline (timer `<game>:look`, job `card_look`) and
`progress {stage: "look", done: 0, needed}`. Every phone sends
`POST .../ready/ {"ready": true, "stage"}` (`false` is `400 bad_request`: looking is one
way). The night opens when every player not gone past grace has looked, at the deadline, or
when the host sends `advance-wave`. With 0 the deal opens the first window at once.

**Windows.** Window 1 is the Doppelganger's (only when she is in the deck); window 2 is
everyone else's. A window opens with ONE group event, `night_window {window, deadline}`;
there is no per-player event at night. Each phone reads its prompt from `/me/`:

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
- Every choose answers `200 {"status": "submitted"}`. Refusals: `400 bad_request`
  (malformed picks, any other `action_type`, `chosen` or `stage` missing), `409
  wrong_stage`, `409 already_chosen` (a prompt that is used up), `403` for someone who does
  not play in the game.
- `chosen` names the prompt the choose answers: lower than the server's count is a resend
  (the same 200, nothing stored), equal is a new choose, higher is `400`. After any 200 the
  phone re-reads `/me/` and trusts `chosen` and `chooses_left`.

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
resolves.

`POST .../night-results/seen/ {"seen": n}` (0 to 10) stores how many results the phone has
shown: `{"night_results_seen": n}`, monotonic (`GREATEST`), clamped to what the caller can
see. Every phone acks once after each window's dawn screen.

## 6. The talk and the vote

**Talk.** `phase_change {phase: "discussion", deadline}` and `progress {stage: "talk", done:
0, needed}`. `POST .../ready/ {"ready": true|false, "stage"}` toggles "ready to vote"
(`{"status": "ok", "ready": ...}`); when every present player is ready the talk ends, as when
the host sends `POST .../end-discussion/ {"stage"}` or the deadline passes.

**Vote.** `phase_change {phase: "voting", deadline}` and `progress {stage: "vote", ...}`.

```json
{"target_player_id": 14, "lock": false, "stage": "vote.…"}
```

- `lock` is required. `false` picks or re-picks (`{"status": "picked",
  "target_player_id": 14}`); `true` picks and locks in one call (`{"status": "submitted"}`).
  A pick sends no event; a lock sends `progress`.
- After locking: the same lock again is the same 200 (nothing stored or sent); any other pick
  or lock is `409 vote_locked`.
- `400`: `invalid_target` (yourself, someone not in the game), `bad_request`
  (`target_player_id` not a JSON integer, `lock` not a bool, no `stage`); `409
  wrong_stage`; `403` for someone who does not play in the game.
- The votes are revealed when every present player has locked, at the deadline, or when the
  host sends `POST .../reveal-votes/ {"stage"}`. At any reveal every stored pick counts,
  locked or not (an unlocked Hunter pick triggers the Hunter chain); no pick is a non-voter.
  The table hears `vote_reveal {votes}` and `game_results`.

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
`game_results`, `player_presence {player_id, connected}`, `host_changed`, `play_again`.
Lobby socket (`/ws/lobby/<code>/`): `player_joined`, `player_left`, `lobby_update`, `game_started`, `host_changed`. Every consumer drops an event type it does
not know, so an older instance never closes a socket over a newer event. Every event is a
count, a window number, public identity or the end of the game.

## 9. Sending a request twice

A phone whose answer is lost sends the same request again. Sending it twice leaves the game
as sending it once did (`backend/tests/onuw/test_resend.py`):

| Request | A resend while its stage is open | A resend after its first copy ended the stage |
|---|---|---|
| `choose` | `chosen` lower than the server's count: the same 200, nothing stored | `409 wrong_stage` |
| `ready` (look, talk) | sets the same value: same answer | `409 wrong_stage` |
| `vote` pick | stores the same pick; after its own lock `409 vote_locked` | n/a |
| `vote` lock | the same 200, nothing stored or sent | `409 wrong_stage` |
| `night-results/seen` | `GREATEST`: same answer | no stage |
| `advance-wave`, `end-discussion`, `reveal-votes` | end their stage | `409 wrong_stage` |
| lobby `start` | n/a | `400` "Lobby is not in waiting state." |
| lobby `play-again` | `200`, the same lobby body | `409` once the next game is dealt |
| lobby `join` | state unchanged; `400 already_in_lobby` | n/a |
| lobby `leave` | state unchanged; `400` (`404` if the table is gone) | n/a |
| lobby `PATCH` | the same values: same answer | n/a |

For `join`, `leave` and `start`, whose second answer differs, the app treats the answer to
its own resend as success and reads the table again. The app sends a phone's requests one at
a time and retries only the latest, so a stale resend never overtakes a newer request.

## 10. Accepted tells and limits

- Who taps at night: only a phone with a choice sends a `choose` (product owner, 20
  November 2026: a friendly game; a sleeper is never asked to act or waited for). Someone
  watching the table or the network can tell who had something to choose, never what.
- An armed Doppelganger's phone is the only one that sends a second `POST .../action/` in
  window 1. Someone watching the network can see that extra request (not its content); the
  answer is the same bytes as anyone's.
- Human tells (thinking time) are out of the server's reach; phones keep sound and haptics
  identical.
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
