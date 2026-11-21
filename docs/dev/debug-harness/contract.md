# Debug Harness — Frozen Build Contract (v2, post-review + spike)

> **Status:** Re-frozen after a two-lens adversarial review (feasibility + cold-read)
> and a working spike that validated the surface end-to-end. Two agents build
> against this in parallel: a backend agent (Django) and a frontend agent (Flutter).
> The orchestrator owns the final integration gate.
>
> **Spike-validated facts carry a `[SPIKE]` tag** — these were proven by running
> code, not reasoned about. See Appendix A for the spike record.

## 0. Updates since the freeze (the choose night, reference games)

The server runs ONE night: two windows where every phone with a choice sends a
`choose` and a phone with nothing to choose sends nothing (`backend/apps/onuw/README.md`, "The night: two windows" and "The choose night"; the API:
`docs/specs/onuw/api-contract-v2.md`), and the scenarios are the **reference games**. The
sections below have been brought up to date with it; this list says what changed since the
freeze:

- **A port per run (20 November 2026).** `just test-harness` and `just harness-serve` take
  `HARNESS_PORT` or pick a free port (wherever this file says `127.0.0.1:8001`, read the
  run's port); the tests get it as `--dart-define=HARNESS_PORT` (`HarnessConfig.port`), and
  the runner stops only the backend it started (its process group by pid, a hard kill after
  5 s).
- **Tables.** `DebugTableController.createTable` opens a table as the app does
  (`defaults: "v2"`), makes the deck `custom` from the role counts (an automatic deck would
  not match a forced assignment) and PATCHes the timer settings beside it; the runners pass
  `card_look_seconds: 0` unless they test the look stage. The harness settings set
  `ONUW_ALLOW_UNTIMED_NIGHT = True`, so zero timers are allowed. There is no ready check at
  the deal.
- **`current_wave` / `wave:{n}`** are the night window: `1` = Doppelganger,
  `2` = everyone else (`0` = the look stage at night, and outside night). Night-log entries
  keep `wave` = the *order group* (1-4) so the log stays in wake order.
- **The night request.** Every player posts
  `{"action_type":"choose","picks":[...],"chosen":<n>,"stage":"<from /me/>"}` (0 to 2 of
  `{"player_id"}`, `{"center_index"}`, `{"self":true}`; `chosen` is the prompt's `chosen` it
  answers, and a lower one than the server's count is a resend whose answer was lost: the
  same answer, nothing stored) and always gets `{"status":"submitted"}`; the only refusals are
  `wrong_stage` (409), `already_chosen` (409) and `bad_request` (400). The server reads the
  picks per role (`backend/apps/onuw/engine/choose.py`); a pick with no valid meaning takes
  the role's default (a Drunk is swapped by the server, the Seer, Robber, Troublemaker and
  the Doppelganger's look skip), and the prompt's `shapes` (`[{"players":1},{"center":2}]`:
  alternatives; `any` = one card of the board) tell the phone which picks would do something.
  A phone chooses once per window; only the Doppelganger sends a second in window 1, her
  follow-up as the copied role.
- **Every stage-scoped request names its stage** (`choose`, `ready`, `vote`, and the host's
  `advance-wave`, `end-discussion`, `reveal-votes`): `/me/` carries an opaque `stage` string
  that changes whenever a tap's meaning changes (look, window 1, window 2, talk, vote) and
  carries a piece of the game's id; a request for a stage that has passed is
  `409 {"code":"wrong_stage"}`, the same for every role, compared under the Game lock,
  storing nothing. `DebugTableController.stagedAs(player, tail, body)` reads the player's
  `/me/` and adds the `stage` (and a choose's `chosen`).
- **Windows and events.** Window 1 is ONE fixed-length stage (the table's
  `night_doppelganger_window_seconds`; `0` = it closes once the Doppelganger has chosen);
  window 2 closes when every present phone WITH a choice has chosen (`chooses_left` above 0;
  a phone whose prompt is `none` sends nothing and is never waited for) and
  `night_min_window_seconds` passed, else at `night_wave_seconds`. The only night event is the group
  `night_window {window, deadline}`; a phone reads its `action_prompt` (`kind`, `shapes`,
  `chosen`, `chooses_left`, `max_chooses`, the board) and `night_results` from `GET /me/`,
  where the Doppelganger's look is listed as soon as it resolves. Votes announce counts only
  (`progress`); `lock` is required on a vote.
- **The look stage.** With `card_look_seconds` > 0 the deal opens window 0: every phone posts
  `ready {"ready": true, "stage": ...}` (`progress {stage: "look"}` events); `advance-wave`
  with the stage or `debug-fire-timer look` opens the night.
- **`debug-fire-timer` `wave:{n}` closes night window `n` now** (ignoring the fixed and
  minimum lengths). `fired:false` = no timer pending (that window's timer setting is 0, or it
  already closed): use the host's `advance-wave` with the stage.
- **Scenarios** = `docs/specs/onuw/reference-games.md`, data in
  `backend/tests/onuw/data/reference_games.json` (23 full games + 6 night-only
  Doppelganger games). The old nine-scenario matrix (§3) and its `nightScript` DSL (§D4)
  are replaced by that file.
- **Runners** (`frontend/test_e2e/`, run with `just test-harness` from the repo root or
  `frontend/`): the API runner (`api_runner_test.dart`, `harness/scenario_runner.dart`)
  replays all 29 reference games: everyone looks, then each phone with `chooses_left`
  answers its prompt by `kind` from the game's choices (`picks()`; a player who must not
  answer sends no picks), the day is driven with `stagedAs` (locked votes), and it checks
  final cards, center, teams, copied role, what each player learned (rebuilt from the
  oracle's night log) and, for full games, votes / deaths / winners / reason. Its
  "two-window night" group checks the wire (no per-player event is heard) and the window
  timing. `api_game_test.dart` drives the look stage, a plain choose night, a
  Doppelganger table with a late tap refused with `wrong_stage`, ready to vote, a lock-in vote
  with a changed pick and the automatic deck at 5 and 9 players. `ui_roles_test.dart`
  deals reference games 1, 4, 5, 8 and 21 and plays one phone through the table's shell. The
  backend replays the same 29 games through the real API in
  `backend/tests/onuw/test_reference_games_api.py`, and `backend/tools/game_driver.py` drives
  one game from the command line (`game-driver.md`).

### Updates since: restart recovery, play again, presence, missed results

- **Oracle `players[].connected`** is now real: `true` while any game WebSocket is open for
  that player. API-only players (no socket) therefore read `false`; the UI runner's one
  live socket reads `true`. (It used to be a constant `true`.)
- **`debug-fire-timer` `current`** ignores grace timers (`<game>:grace:<user>`, a dropped
  player's countdown); it still needs exactly one phase / window timer. Timers are rebuilt
  from stored deadlines at server start (`runserver` under daphne imports `config.asgi`,
  which runs the recovery), so a restarted harness backend resumes any game left running
  in its throwaway DB. Presence is reset then: every player of a running game is
  "disconnected" until their socket reconnects, with `disconnect_grace_seconds` (default 25,
  0-60, 0 = off; send it with the other timer settings) as the clock.
- **Timers and presence are durable rows now** (`docs/dev/deploy-vercel.md`, `backend/apps/core/README.md`).
  `debug-fire-timer` claims the `ScheduledTimer` row for the key and runs its job (`current` =
  the single non-grace timer row under the game's prefix; a timer that already fired is gone
  from the table, so a second fire is `fired:false`). The harness keeps the in-process
  `threading.Timer` backend. The oracle's `players[].connected` is "has a fresh socket row"
  (a socket whose heartbeat stopped for 40 s counts as gone). Nothing is reset at backend start:
  a restarted harness backend notices dead sockets through their presence checks.
- **Host handover:** `Lobby.host` is the owner; `Lobby.acting_host` holds the role while the
  owner's phone is away longer than `host_handover_seconds` (default 60, 0-600, 0 = off; send
  it with the other timer settings, `0` to keep a harness table's host fixed). The oracle's
  `players[].is_host` and every host endpoint use the effective host. Sockets: `host_changed`
  on the lobby and game sockets; lobby detail `host` = effective host plus `original_host_id`,
  `is_acting_host`; `/me/` `host_id`. API-only harness players never open sockets, so no
  handover happens for them. `host_changed` `reason` is `"handover"`, `"returned"` or
  `"transferred"`: the OWNER leaving a lobby that still has other members (not while a game
  runs) no longer deletes it; ownership moves for good to the next member (a connected one
  preferred) and `host_id` == `original_host_id` == the new owner. Only the last member
  leaving deletes the lobby. `/me/`'s `night_results` includes swaps (Drunk /
  Troublemaker).
- **`GET .../games/<id>/me/`** also has `lobby_code` (every phase). After a restart a deadline
  that is overdue or under 15 s away is moved to now + 15 s (persisted in `deadline`) so phones
  can reconnect first.
- **`GET .../games/<id>/me/`** has `night_results`: the caller's own results for windows
  that have closed, `[{"wave", "action_type", "revealed_info"}]` (and the Doppelganger's own
  look as soon as it resolves).
- **Play again:** `POST /api/lobbies/<code>/play-again/` (alias
  `/api/onuw/lobbies/<code>/play-again/`), host only, newest game must be in `results`;
  a lobby holds many games (`Game.lobby` is a ForeignKey), so the harness can run several
  games on one table. Socket events: game group `{"type": "play_again", "lobby_code"}`,
  lobby group `lobby_update`. Presence event on the game group:
  `{"type": "player_presence", "player_id", "connected"}`; the player list
  (`GET .../games/<id>/players/`) has `connected` per player.

### Updates since: tokens and seats (v2 contract S1)

- **Tokens and seats.** Every lobby member has a `token` (one of ten: `crow`, `key`, `moth`,
  `bell`, `thorn`, `antler`, `hare`, `lantern`, `spindle`, `scythe`), handed out under the Lobby
  lock in an order seeded by the lobby code. The lobby detail `players[].token`, game `/me/`
  `players[]`, `GET .../players/` and results `players[]` carry `token` and `seat` (join order,
  0-based; `null` seat and `""` token only for games dealt before this). The deal snapshots both
  into `PlayerRole`, so a game keeps them when a member leaves. Players lists come back in seat
  order. The oracle's `players[]` also has `token` and `seat`, and the oracle has
  `dealt_center_cards` (`center_cards` is overwritten as the night swaps cards).
- **Lobby limits.** `max_players` at create is 1 to 10, the token count (400 otherwise; the game
  checks its own 3 to 10 when it deals). Join refusals carry a `code`: `lobby_not_found` (404),
  `already_in_lobby`, `lobby_closed`, `lobby_full` (400). There is no lobby ready flag
  (the deal has no ready check; `POST .../ready/` of a lobby is gone).
- **Where am I.** `GET /api/me/table/` (core) answers `{"table": {"lobby_code", "game_type",
  "status", "is_host", "token", "game": {"game_id", "phase"} | null}}` or `{"table": null}`:
  the caller's newest-joined lobby with activity (`Lobby.updated_at`: join, leave, deal,
  finish, play again, ...) within `CORE_TABLE_RESUME_HOURS` (12; a game nobody finished expires too), and the lobby's newest game if the caller plays in it (also
  between games, when `current-game` is empty). `GET /api/onuw/me/current-game/` is unchanged.
- **Night results ack.** `GET .../me/` has `night_results_seen` (the caller's own count).
  `POST /api/onuw/games/<id>/night-results/seen/` with `{"seen": n}` (a JSON integer 0 to 10;
  400 `bad_request` otherwise) answers `{"night_results_seen": <stored>}`. The count never goes
  down and is capped at the number of `night_results` the caller can see now.
- **Night timeline.** `GET .../results/` also has `night_timeline` (`{seats, cards, dealt, steps,
  final, center_moved}`, or `null` if the night cannot be replayed; see `api-contract-v2.md`
  section 7). Built forwards from `Game.dealt_center_cards`; the debug oracle shows it as
  `dealt_center_cards`.
- **Home extras.** `GET /api/stats/online/` (no auth) answers `{"players", "tables"}` from fresh
  socket rows, `Cache-Control: public, max-age=15, s-maxage=15` (it permits 15 s reuse; it does not guarantee a CDN caches it). `GET /api/onuw/me/recent-games/?limit=`
  answers the caller's finished games (`game_id`, `ended_at`, `player_count`, `winning_teams`,
  `you_won`, `token`, `seat`).
- **Lobby settings PATCH merges.** `PATCH /api/lobbies/<code>/` with `{"settings": {...}}` merges the
  given keys over the stored settings (the harness and the game driver send complete
  settings, which still works), refuses with 409 `lobby_in_game` while a game runs, and
  validates the merged settings (`pace`, if present, is `quick|normal|long|custom`). The ready
  toggle is also 409 `lobby_in_game` while a game runs.

## 1. Goal

Give an autonomous agent (and a human) a fast, deterministic way to drive the
**entire** ONUW multiplayer flow and prove the **real frontend wiring** works
against the **real backend** — not against mocks. The 773 existing frontend tests
mock the HTTP/WS seam, so they don't prove integration; this harness closes that.

Two deliverables share one core:
1. **Debug toolbar** (human, dev-only) — spin up a table, switch to any player's
   perspective, watch all players' ground truth, auto-drive the game.
2. **Integration harness** (automated) — replay reference scenarios deterministically
   through the real widget tree against a booted real backend, asserting authoritative
   state, emitting per-state PNG filmstrips an agent reads.

## 2. Architecture decisions (settled — do not relitigate)

| # | Decision |
|---|----------|
| Perspective | **Switch one player at a time** (not simultaneous multi-screen), backed by a god panel showing all players' truth as data. |
| **Surface** | **Headless `flutter test` on the host Dart VM** — NOT a built macOS `.app` (so no App Sandbox, no `macos/` target needed) and NOT `flutter drive`/Chrome. Real Dio + real WebSocket work here **only after `HttpOverrides.global = null`** — `flutter_test` installs an override that returns HTTP 400 and makes no real request. `[SPIKE]` |
| Visual capture | Wrap the app root in `RepaintBoundary(GlobalKey)`; capture `boundary.toImage()` → PNG **inside `tester.runAsync()`** (raw `toImage` hangs the test clock — flutter#50783). `[SPIKE: no hang, real PNG]` **Load real fonts** (reuse the repo's golden font-loading path in `test/flutter_test_config.dart` / `font_loading_smoke_test.dart`) or text renders as Ahem boxes. `[SPIKE: confirmed boxes without fonts]` |
| Switch mechanism | A debug-only `AuthNotifier.adoptSession(User)` that writes the target's token+user to storage and sets `AuthState.authenticated(user)` **from the access token directly — NO refresh round-trip.** The production restore path (`tryRestoreSession`) refreshes, and the backend has `ROTATE_REFRESH_TOKENS + BLACKLIST_AFTER_ROTATION = True`, so refreshing **blacklists the stored token and breaks re-switching to the same player.** After `adoptSession`, invalidate the game providers named in §C. `[SPIKE: reusing a player's original access token after switching away and back returns 200 — adoptSession avoids rotation entirely]` |
| WebSocket from harness | The harness WS client (`dart:io`) **must set an `Origin` header matching `ALLOWED_HOSTS`** (e.g. `http://127.0.0.1:8001`). channels' `OriginValidator` 403s any handshake with no Origin (`security/websocket.py:52`); browsers always send one, `dart:io` does not. `[SPIKE: no Origin → 403 REJECT; with Origin → CONNECT]` |
| Identity model | App identity is a single global JWT in `TokenStorage`, injected per-request by `AuthInterceptor`. Driving other players without switching the visible perspective uses an explicit-per-player-token client (§D2). |
| Determinism | **Forced assignment** (exact player→role + center), not seed-guessing. Timeout paths via a **DEBUG fire-timer hook** (§B3). Happy-path transitions driven via existing host endpoints. There is **no general virtual clock** — only an on-demand fire-the-pending-timer hook. |
| Backend lifecycle | Harness owns DB + ASGI lifecycle. **Pinned values:** `DJANGO_SETTINGS_MODULE=config.settings.harness` (already created + spike-validated), DB `midnight_village_harness` (throwaway, distinct from dev), ASGI on `127.0.0.1:8001` (Daphne via `runserver`; single process — InMemoryChannelLayer). Scenarios self-isolate via fresh guests/lobby/game. Postgres assumed present. `[SPIKE: harness.py + createdb + migrate + runserver + real HTTP/WS all worked]` |
| Gating | Backend debug endpoints gated by `settings.DEBUG` (prod 403/404, each with a test). Frontend debug code gated by `Env.isDev`, which **must be changed to a true `const bool`** (`static const bool isDev = String.fromEnvironment('ENV', defaultValue: 'dev') == 'dev';`) so `if (Env.isDev)` is provably dead-code-eliminated — today it's a getter, so tree-shaking is "probably," not guaranteed. **Single entrypoint** `main.dart`, const guards. |
| Hidden-info safety (defense in depth) | Other players' roles + the night action log reach the client **only** via the DEBUG-gated `debug-state` endpoint (§B2), which 403s in prod. The frontend gate is then a second layer, not the sole barrier — so a tree-shake miss alone cannot leak. Never route another player's hidden role through any production-reachable screen, WS event, or API response. |

## 3. Scenario matrix (v1)

From `docs/specs/frontend/validation/scenarios.md`. **In scope:** scenarios
**1, 2, 3, 4, 5, 6, 8, 10**, plus **Scenario 7 Sub-Case A only** (Doppelganger-as-
Minion team assignment + each seer's recorded peek result; NOT narrator-cue timing,
NOT Sub-Case B). Nine total.

**Superseded** by the reference games (§0); kept for history.

**Deferred (do not build):** Scenario 9 (Disconnect Nightmare) — six unresolved
display questions in its spec; queued as a separate follow-up. Narrator-cue timing.
Web/Chrome outer-check. Video stitching.

Ship a **manual** "drop / restore this player's connection" toggle in the toolbar
(unasserted).

---

# Part B — Backend contract (backend agent owns)

All endpoints **DEBUG-gated**: when `settings.DEBUG is False`, return 403 and do
nothing; each MUST have a `DEBUG=False`-rejection test. All new code tested to the
project bar (`just check` + `just test` green, coverage ≥80% holds).

Read before changing: `apps/onuw/views.py` (`GameStartView` ~line 35; `ResultsView`
537-639), `apps/onuw/engine/assignment.py`, `apps/onuw/timers.py`, `apps/onuw/services.py`
(`persist_wave_results` ~505), `apps/onuw/models.py:48` (`night_actions_log`),
`apps/onuw/engine/win_conditions.py` (`get_effective_team` ~82), `config/settings/harness.py` (already created).

### B1. Forced-assignment / seed override on game start

Extend `GameStartView.post` (`POST /api/onuw/lobbies/<code>/start/`), honored **only
when `settings.DEBUG`**:

```jsonc
{ "debug": { "forced_assignment": {
    "player_roles": { "12": "Werewolf", "13": "Seer", "14": "Robber" },  // keys = STRINGIFIED user ids (JSON object keys); backend int()-coerces
    "center": ["Werewolf", "Minion", "Drunk"]                            // exactly 3
} } }
// or:  { "debug": { "seed": 123456789 } }
```

Rules:
- No `debug` key or `DEBUG=False` → unchanged behavior (random `secrets.randbits(63)`).
- **Role names are canonical TitleCase** exactly as `lobby.settings["roles"]` keys
  (e.g. `Werewolf`, `Troublemaker`, `Doppelganger`) — never lowercase. Validate every
  name is a known v1 role.
- `forced_assignment`: bypass `assign_roles`; set **`current_role = original_role`**
  (= the forced value) and `center_cards` verbatim. Validate the multiset
  `player_roles.values() + center` equals the configured role counts exactly, every
  lobby player id present exactly once, `len(center) == 3`. On any mismatch → **400**,
  non-leaky message, create nothing.
- `seed`: pass to `assign_roles` instead of random.
- Response unchanged: `{ "game_id", "phase": "night" }`.

Tests: forced lands exactly (current=original); mismatch → 400, no game; seed
reproducible; `DEBUG=False` ignores `debug`.

### B2. Debug-state oracle — `GET /api/onuw/games/<id>/debug-state/` (DEBUG only; 403 otherwise)

Read-only projection of authoritative state — the harness assertion oracle AND the
toolbar god panel. **Shapes pinned to the real backend (the review found the draft
drifted in 5 fields):**

```jsonc
{
  "game_id": "...",
  "phase": "night|discussion|voting|results",
  "current_wave": 0,                         // INT, 0 outside night, 1 or 2 (the window) during (NOT null)
  "center_cards": ["Werewolf","Minion","Drunk"],
  "players": [{
    "user_id": 12, "display_name": "Alice", "is_host": true,
    "original_role": "Werewolf",
    "current_role": "Robber",                // post-swap truth (oracle-only; /me/ hides this pre-results)
    "doppelganger_copied_role": null,        // role the Doppelganger copied, else null (scenarios 4/7/10)
    "team": "village",                        // get_effective_team → "werewolf"|"village"|"neutral" (Tanner = "neutral", NOT "tanner")
    "connected": true,
    "ready": false,                           // PlayerRole.phase_ready: "ready to vote" in the talk, "looked at my card" in the look stage
    "chosen": {"1": 0, "2": 1}                // how many `choose` the server took from this phone per night window (a phone with nothing to choose sends none)
  }],
  "night_actions_log": [                      // NOTE plural; mirror models.py field exactly
    { "wave": 3, "player_id": 14, "role_acting_as": "Robber",   // wave = order group 1-4 (wake order), NOT the window; role_acting_as enriched from PlayerRole.night_action_data
      "action_type": "swap_with_player", "targets": {...}, "result": {...}, "timestamp_order": 2,
      "made_by_server": false }   // true only for a move the server made for a player who timed out / was gone past the grace period (the Drunk's seeded swap)
  ],
  "votes": { "12": 14, "13": null },          // EVERY player is a key; the stored PICK, locked or not (every pick counts at any reveal); null = no pick / abstained
  "vote_locked": { "12": true, "13": false }, // EVERY player is a key; true = locked in (final), false = picked (or nothing)
  "results": { ... } | null,                  // present once phase=results; winning_teams = list of lowercase tokens ⊂ {"village","werewolf","tanner"}, asserted as a SET
  "pending_timers": ["grace:14", "wave:2"]    // sorted names of the ScheduledTimer rows pending now: this game's keys without the "<game id>:" prefix (wave:N, discussion, voting, grace:<user id>) plus "host_handover" while the lobby's handover timer is armed
}
```

`pending_timers` exists so a scenario can assert a timer was started or cancelled (a
reconnect cancelling a grace countdown, the owner coming back cancelling the handover),
which no player-facing response says. "Pending" means the `ScheduledTimer` row exists (an
overdue, not yet fired row still shows). `host_handover` is the LOBBY's timer, so it also
shows on a finished game of the same lobby.

Tests: post-swap `current_role` correct; team `neutral` for Tanner; `votes` includes
all players; `DEBUG=False` → 403.

### B3. Timeout / timer fire hook — **FINALIZED** (shape below is implemented)

Only for **timeout** paths (a window closing on phones that never chose; vote
auto-finalize); happy-path
transitions use existing host endpoints (`advance-wave`, `end-discussion`,
`reveal-votes`). DEBUG-only. Mechanism (the review corrected the draft):

(Superseded: timers are now `ScheduledTimer` rows, `apps/core/timers.py`; the in-process `_registry` only holds the memory backend's threads and `debug-fire-timer` claims the row, see the "durable rows" note above.) It used to read: `apps/onuw/timers.py` `_registry` stores **`threading.Timer` objects, not callbacks**.
To fire synchronously: look up `f"{game_id}:{suffix}"`, then `timer.cancel()` (so the
wall-clock copy doesn't also fire) and call `timer.function(*timer.args)`. This
composes safely — there's no `ATOMIC_REQUESTS`, and `make_idempotent_callback` opens
its own `select_for_update` transaction and is phase-guarded, so firing a stale /
already-fired key is a safe no-op (cannot double-transition).

**Endpoint:** `POST /api/onuw/games/<id>/debug-fire-timer/`

**Request body:**
```jsonc
{ "key": "wave:1" | "wave:2" | "discussion" | "voting" | "look" | "current" }
```
- `wave:{n}` — `n` must be a non-negative integer; only `1` and `2` name a night window.
  Firing it closes that window now.
- `discussion`, `voting` — the phase timers. `look` — the look stage's backstop (`card_look_seconds`): opens the first night window now.
- `current` — resolves to the **single** registry key under prefix `f"{game_id}:"`;
  rejected (400) if there are 0 or >1 pending timers for the game.
- Caller must be a player in the game (same membership bar as all game endpoints).

**Responses:**
```jsonc
// 200 — key was well-formed; `fired` reflects whether a timer was pending.
{ "fired": true,  "key": "wave:2" }       // timer existed → cancelled + callback ran synchronously
{ "fired": false, "key": "wave:2" }       // no pending timer for the resolved key (stale/missing → safe no-op)
{ "fired": true,  "key": "discussion" }   // `current` resolved to this suffix
```
- `key` in the response is the **resolved suffix** (game prefix stripped), so a
  `"current"` request echoes the concrete key it fired (e.g. `"discussion"`).
- **400** — `key` missing/not a string, malformed (`wave:`, `wave:abc`, unknown
  literal), or `"current"` with 0 or >1 pending timers. Message is generic
  (`"Invalid timer key."` / `"'current' requires exactly one pending timer, found N."`),
  no role leak.
- **403** — `settings.DEBUG` is False, or caller is not a player in the game.
- **404** — game does not exist.

The frontend `fireTimer(TimerKey)` (§D1/§D4) targets this exact shape; `TimerKey`
serializes to the `key` string above, and the runner reads `fired` to distinguish a
real fire from a no-op (a no-op on a timeout assertion means the timer wasn't armed —
the harness should treat that as a setup error, not a pass).

### B4. Guest throttle — DONE in `config/settings/harness.py`

`harness.py` raises `anon`/`user` rates to 1,000,000/min (the guest view hardcodes
`throttle_classes=[AnonRateThrottle]`, so raising the rate is the right lever, not
clearing `DEFAULT_THROTTLE_CLASSES`). `[SPIKE: 4 guests created back-to-back, no 429]`
Backend agent: confirm it holds for a full nine-scenario run (each spins a table).

### B5. Lifecycle recipe

Provide a `backend/justfile` recipe (e.g. `harness-serve`) that: creates (if absent)
+ migrates `midnight_village_harness`, then `DJANGO_SETTINGS_MODULE=config.settings.harness
uv run python manage.py runserver 127.0.0.1:8001`. `[SPIKE: exact sequence worked]`
The §D5 frontend recipe invokes this and waits for `GET /api/health/` → 200 before
running tests.

---

# Part C — Frontend wiring the harness depends on (read first; corrected per review)

- Identity = single global JWT in `lib/core/storage/token_storage.dart`, injected by
  `lib/core/api/auth_interceptor.dart`. The shared HTTP client auto-uses whatever
  token is stored — no per-switch rebuild.
- **Perspective switch** uses a NEW debug-only `AuthNotifier.adoptSession(User)` (see
  §2). Do NOT route switching through `tryRestoreSession` (`auth_repository.dart`) — it
  refreshes and the backend rotates+blacklists.
- **Game WebSocket providers:** the game uses its own providers in
  `lib/features/game/presentation/game_socket.dart`: `gameWebSocketProvider`,
  `gameWebSocketStreamProvider`, `gameConnectionStateProvider`. `switchTo` invalidates
  `liveGameProvider(gameId)` (`live_game.dart`) **and** these three so the old player's
  socket is disposed and the new player's attaches.
- REST paths (note `/api/` prefix): guest `POST /api/auth/guest/` → `{access, refresh,
  user:{id, display_name}}`; lobby `POST /api/lobbies/` (`defaults: "v2"`),
  `/api/lobbies/<code>/join/`, `PATCH /api/lobbies/<code>/` (`{settings:{deck:"custom",
  roles:{...}}}`, TitleCase keys), start `POST /api/onuw/lobbies/<code>/start/`; game
  `GET /api/onuw/games/<id>/me/` (its `stage`), and with that `stage`: `POST .../ready/`,
  `.../action/` (a `choose`), `.../vote/` (with `lock`), `.../advance-wave/`,
  `.../end-discussion/`, `.../reveal-votes/`; `GET .../results/`, `GET .../debug-state/`.
- WS routes: `ws://127.0.0.1:8001/ws/lobby/<code>/?token=<access>` and
  `/ws/game/<id>/?token=<access>` — set the `Origin` header (§2).
- `lib/core/config/env.dart` — change `isDev` to a `const bool` (§2). Harness
  integration tests target `127.0.0.1:8001` via their own constants (not `Env`, which
  points at the dev `:8000`).
- Golden font-loading lives in `test/flutter_test_config.dart` + `test/helpers/font_loading_smoke_test.dart`.

---

# Part D — Frontend contract (frontend agent owns)

Debug/harness code reachable ONLY behind const `Env.isDev`. Shared core in `lib/`;
scenario runners in `integration_test/` (never ships). `just analyze` clean; `just gen`
after provider changes; widget/unit tests for the controller + toolbar.

### D1. `DebugTableController` (shared core, `lib/.../debug/`)

- `createTable({ required int playerCount, required Map<String,int> roleCounts /* TitleCase role name → count, as PATCHed */, ForcedAssignment? assignment, String? hostName })`
  → create N guests (the **first guest is the host / lobby creator**), capture each
  guest's server-assigned `user_id` from the `POST /auth/guest/` response, create the
  lobby as the app does (`defaults: "v2"`), join all, PATCH `deck: custom`, the role
  config and the timers, `start` with `debug.forced_assignment` keyed
  by those **stringified user_ids** (creation order does NOT affect role assignment —
  forced assignment is explicit). Returns a `DebugTable` holding each player's
  `{userId, displayName, accessToken, refreshToken, role}` + `gameId`.
- `switchTo(player)` → `adoptSession(player.user)` (writes token+user, sets authed state
  from the access token, NO refresh) + invalidate `liveGameProvider(gameId)`,
  `gameWebSocketProvider(gameId)`, `gameWebSocketStreamProvider(gameId)`,
  `gameConnectionStateProvider(gameId)`. Exactly one live WS.
- `stagedAs(player, tail, body, {lenient = false})` → issue a stage-scoped call AS any
  player without changing the visible perspective, via the §D2 client, naming the stage
  that player's `/me/` carries (and a choose's `chosen`). Covers `choose`, `ready`, vote,
  end-discussion, advance-wave, reveal-votes. **Strict by default: a refusal (including a 409) throws.**
  Only the debug toolbar's one-tap helpers pass `lenient: true` (409 = already done).
  `attachTable(table)` re-points the controller at a later game of the same lobby.
- `oracle()` → `GET .../debug-state/`.
- `fireTimer(TimerKey)` → §B3 hook, the **single** coupling point (see §D4).
- `setConnected(player, bool)` → drop/restore that player's WS (manual disconnect toggle).

### D2. Debug API client

Issues REST with an **explicit** `Authorization: Bearer <token>` per call and
**attaches NO `AuthInterceptor`** (otherwise a 401 would trigger a refresh against the
global `TokenStorage` and cross-contaminate identities). On 401 it fails loudly, never
refreshes. Sets the WS `Origin` header for the connection helpers.

### D3. Debug toolbar (human, dev-only, `/debug` route under `if (Env.isDev)`)

Table setup (player-count + role-config presets from the **Base-Game-Only** section of
`recommended-setups.md`, already encoded in `RoleConfig._presets` — do NOT ingest
Daybreak setups; + the nine matrix scenarios; + a forced-assignment editor + seed
field); perspective switcher (lists players with true roles — debug only — tap to
become any); god panel (live oracle: original→current card, copied role, team, action
log, votes, center); auto-drive for everyone but the phone shown, through `stagedAs`
(everyone ready, keep their card (an empty `choose`), everyone votes someone and locks,
end discussion, reveal votes, fire the pending timer via fireTimer); disconnect toggle; replay
(show/edit seed/assignment). Toolbar uses real wall-clock time.

### D4. Integration harness (`integration_test/`, never ships)

**Scenarios as data**: the reference games (`backend/tests/onuw/data/reference_games.json`,
read by `test_e2e/harness/scenarios.dart`): players, dealt cards, centre, each player's night
choices and votes, and the expected outcome.

Encoding rules:
- **A night choice is a `choose`** (`harness/scenario_runner.dart`, `picks()`): every phone
  with `chooses_left` sends the picks its prompt's `kind` takes from the game's choices
  (`seer`: one other player, or two centre cards; `robber`: one other player;
  `troublemaker`: two other players; `drunk` and `lone_werewolf`: one centre card;
  `doppelganger_look`: one other player, then her follow-up as the copied role); a phone
  whose role has nothing to choose has no `chooses_left` and sends nothing; one that
  declines sends no picks.
- **Roles/teams:** role names TitleCase; team tokens `{werewolf,village,neutral}`
  (Tanner=neutral); `winning_teams` lowercase, asserted as a **set**; elimination
  reasons ∈ `{"vote","hunter_chain"}`; eliminations as a set of user ids.
- "Who-sees-what" = each player's recorded result in the night log, rebuilt the same way
  for every game, not a separate field.
- **Oracle checkpoints** are per-window boundaries (the oracle reflects committed state
  after a window fully resolves; ordering inside a window, like Seer-before-Robber, is
  asserted via each actor's recorded `result` in the log, not a mid-window snapshot).
  Always assert the final-state table.

**API runner** (`api_runner_test.dart`, all 29 reference games every run): drive via
`DebugTableController` + §D2 client, assert `oracle()` at checkpoints and `results` for
eliminations/reasons/winners.

**UI runner** (`ui_roles_test.dart`: reference games 1, 4, 5, 8 and 21; `ui_game_test.dart`,
`ui_end_test.dart`, `ui_journey_test.dart`): boot the real widget tree, `switchTo` the
relevant player, drive by **tapping real widgets** while the others play through the API,
capture `RepaintBoundary.toImage()` PNGs (inside `runAsync`, fonts loaded) to
`integration_test/screenshots/<scenario>/NN-<state>.png`. **Assert the rendered role
against `original_role`** (current_role is hidden pre-results by design — asserting
rendered==oracle.current_role can never pass and would tempt leaking it); assert
post-swap truth against the **oracle**.

**Lifecycle scenarios** (`frontend/test_e2e/api_lifecycle_test.dart`, run by
`just test-harness`; helpers `harness/live_table.dart`, `harness/time_budget.dart`,
`PlayerWire.connectLobby` / `connectToGame` / `waitForEvent`): real HTTP + real sockets,
asserting what clients are told AND the oracle.
- *Play again* (on both URLs): 409 before results, 403 non-host, `play_again` +
  `lobby_update` to every socket, same members/settings, a NEW game id the controller then
  drives, old results readable, `current-game` null; a double-tap Start deals one game.
- *Dropped phone*: `player_presence`, player list, `grace:<id>` in `pending_timers`;
  window / vote held for a dropped player inside `disconnect_grace_seconds` even when
  everyone else is done, then closed with the server's Drunk swap (`made_by_server`) or a
  non-voter; `night_results` in `/me/` after a missed window (including a Doppelganger's two
  window 1 results with window 2 still open); reconnect cancels the countdown (and a
  returning voter's vote counts); a dropped actor and a dropped non-actor close the window
  at the same time with the same events; a second socket closing is not a drop.
- *Host handover*: `host_changed` `handover` / `returned`, lobby detail and `/me/` agree,
  acting host can advance / end discussion / play again / start, a normal player gets 403;
  an acting host who drops hands on to the next connected member, never the owner; the
  handover timer is armed only while the owner has no socket at all, and the owner
  returning cancels it before it fires (`host_handover` in `pending_timers`, no event).
- *Time*: grace and handover are real wall-clock periods set per game (`debug-fire-timer`
  cannot shorten them: their callbacks re-check the stored disconnect stamp). Every "has
  not happened yet" check inside one goes through a `TimeBox` (fails as "inconclusive:
  machine too slow" if the period was already over), every wait has an explicit timeout
  derived from the period, and a "nothing arrived" check is made after a positive barrier
  (an event that travels the same socket after anything sent earlier), never after a sleep.

**Test harness setup** (every harness test): `HttpOverrides.global = null` (real
network), load fonts, target `127.0.0.1:8001`. Use the §B3 fire-timer hook (not
wall-clock waits) for timeout assertions; otherwise advance via host endpoints. Receive
WS-driven state via `tester.runAsync()` + poll-for-condition with bounded wall-clock
timeouts that throw on expiry; never `pumpAndSettle` against the live reconnecting
socket. `[SPIKE: real HTTP+WS from this surface confirmed]`

### D5. One-command runner (`frontend/justfile`, e.g. `just test-harness`)

Boots the §B5 backend (waits for health 200), runs the `integration_test` suite headless
on the host VM, writes PNG filmstrips, exits non-zero on any failure, tears the backend
down. **Machine-readable failure output** an agent can act on: which scenario, which
checkpoint, expected-vs-actual (oracle diff), path to the relevant PNG.

---

# Part E — Definition of done (checkable)

**Backend agent:** B1, B2 (exact shapes above), B3 (implemented + final shape written
back), B5 recipe; B4 confirmed for a full run. Every debug endpoint has a `DEBUG=False`
403 test. `just check` + `just test` green; coverage ≥80%.

**Frontend agent:** `Env.isDev` is a `const bool`; `AuthNotifier.adoptSession` added with
a test; `DebugTableController` + §D2 client + toolbar built with widget/unit tests that
run **without a backend** (mock the §D2 client); `just analyze` clean; `just gen` run.
Every reference game fully populated as data (no empty `expected`/TODO); the API runner
**compiles with complete assertion code** (asserts populated `expected` against
oracle/results); the UI runners capture filmstrips. Only the
live-backend round-trip (actual HTTP/WS) may be left for the gate; everything else is
tested and complete.

**Orchestrator (integration gate, not delegated):** boot the harness backend, run
`just test-harness`, reconcile §B3 drift, confirm filmstrips render real per-player
perspectives, report.

**Deferred follow-ups (tracked):** scenario-9 display spec; web/Chrome outer-check; video.

---

# Appendix A — Spike record (what was actually run and proven)

A throwaway spike (since deleted) validated the load-bearing claims before freezing:

1. **Headless capture** — `flutter test` + `RepaintBoundary.toImage()` in `runAsync`
   wrote a real 11,982-byte PNG, no hang. Text rendered as Ahem boxes (fonts must be
   loaded). ✅
2. **Real HTTP headless** — fails by default (`flutter_test` returns HTTP 400 with no
   real request); succeeds after `HttpOverrides.global = null`. Two guests created, a
   lobby created — all against a live backend. ✅
3. **Access-token-only repeated switch** — created Alice+Bob, authed as Bob, then re-authed
   as Alice with her **original** access token → 200. Confirms `adoptSession` (no refresh)
   avoids the rotation/blacklist bug. ✅
4. **Real authenticated WebSocket** — `dart:io` WS with no Origin → 403 REJECT
   (`OriginValidator`); with `Origin: http://127.0.0.1:8001` → CONNECT. ✅
5. **Backend lifecycle** — `config/settings/harness.py` + `createdb midnight_village_harness`
   + `migrate` + Daphne `runserver 127.0.0.1:8001` all worked; health 200. ✅
