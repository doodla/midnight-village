# Debug Harness — Frozen Build Contract (v2, post-review + spike)

> **Status:** Re-frozen after a two-lens adversarial review (feasibility + cold-read)
> and a working spike that validated the surface end-to-end. Two agents build
> against this in parallel: a backend agent (Django) and a frontend agent (Flutter).
> The orchestrator owns the final integration gate.
>
> **Spike-validated facts carry a `[SPIKE]` tag** — these were proven by running
> code, not reasoned about. See Appendix A for the spike record.

## 0. Updates since the freeze (two-window night, reference games)

The server now runs the night as **two windows** (`backend/CLAUDE.md`, "Night phase
runs in two windows"), and the scenarios are the **reference games**. Where the
sections below say otherwise, this list wins:

- **`current_wave` / `wave:{n}`** are the night window: `1` = Doppelganger,
  `2` = everyone else (`0` outside night). Night-log entries keep `wave` = the
  *order group* (1-4) so the log stays in wake order. The old "wave 1-4" language,
  `wave_3_result` / `wave_4_result` and "waves auto-advance one by one" no longer apply.
- **Window 2 delivers nothing until it closes** (every `action.result`, then
  `wave.complete`, then `phase.change`). Window 1 (Doppelganger) sends her look
  result on submit, then a follow-up `action.prompt` (also wave 1) when she copied
  Seer/Robber/Troublemaker/Drunk/Minion; the follow-up result arrives when the
  window closes.
- **Timers** are per-game lobby settings: `night_doppelganger_window_seconds`
  (fixed length of window 1; `0` = off), `night_min_window_seconds` (a window never
  closes sooner), `night_wave_seconds` (maximum; `0` = no timer). The harness passes
  `0, 0, 600` (and `0` for discussion / voting) via `createTable(timerSettings:)`, so a
  window closes when its last actor submits, and the 600s maximum gives
  `debug-fire-timer` a real timer to fire.
- **`debug-fire-timer` `wave:{n}` closes night window `n` now** (ignoring the fixed and
  minimum lengths). `fired:false` = no timer pending (e.g. that window's timer setting is
  0, or it already closed): use the host's `advance-wave`.
- **"Do nothing"** is `{"action_type":"skip","targets":{}}` for Seer, Robber,
  Troublemaker (and a Doppelganger follow-up as one of them), when the prompt's
  `action_types` includes `skip`. The Drunk and the Doppelganger's first look cannot skip.
  "Same action with empty targets" (§D4) is still how a lone Werewolf declines the peek.
- **Scenarios** = `docs/specs/onuw/reference-games.md`, data in
  `backend/tests/onuw/data/reference_games.json` (23 full games + 6 night-only
  Doppelganger games). The old nine-scenario matrix (§3) and its `nightScript` DSL (§D4)
  are replaced by that file; the API runner replays all 29, the UI runner a subset
  (`test_e2e/harness/scenarios.dart`).
- **Runners** (`frontend/test_e2e/`, run with `just test-harness` from the repo root or
  `frontend/`): the API runner reads each player's own `GET .../me/` for the pending
  `action_prompt` and answers it from the game's choices (a player who must not or cannot
  answer is left to the window timer, closed with `debug-fire-timer`), then checks final
  cards, center, teams, copied role, what each player learned (rebuilt from the oracle's
  night log) and, for full games, votes / deaths / winners / reason. Three extra tests
  check the wire (what each socket receives, and when) and the window timing. The UI
  runner shows one player's real widget tree with a live WebSocket, taps that player's
  steps, and drives the rest through the API.

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
- **Host handover:** `Lobby.host` is the owner; `Lobby.acting_host` holds the role while the
  owner's phone is away longer than `host_handover_seconds` (default 60, 0-600, 0 = off; send
  it with the other timer settings, `0` to keep a harness table's host fixed). The oracle's
  `players[].is_host` and every host endpoint use the effective host. Sockets: `host_changed`
  on the lobby and game sockets; lobby detail `host` = effective host plus `original_host_id`,
  `is_acting_host`; `/me/` `host_id`. API-only harness players never open sockets, so no
  handover happens for them.
- **`GET .../games/<id>/me/`** also has `lobby_code` (every phase). After a restart a deadline
  that is overdue or under 15 s away is moved to now + 15 s (persisted in `deadline`) so phones
  can reconnect first.
- **`GET .../games/<id>/me/`** has `night_results`: the caller's own results for windows
  that have closed, `[{"wave", "action_type", "revealed_info"}]` in the same shape as the
  `action_result` socket event; empty while the window is open.
- **Play again:** `POST /api/lobbies/<code>/play-again/` (alias
  `/api/onuw/lobbies/<code>/play-again/`), host only, newest game must be in `results`;
  a lobby holds many games (`Game.lobby` is a ForeignKey), so the harness can run several
  games on one table. Socket events: game group `{"type": "play_again", "lobby_code"}`,
  lobby group `lobby_update`. Presence event on the game group:
  `{"type": "player_presence", "player_id", "connected"}`; the player list
  (`GET .../games/<id>/players/`) has `connected` per player.

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
    "connected": true
  }],
  "night_actions_log": [                      // NOTE plural; mirror models.py field exactly
    { "wave": 3, "player_id": 14, "role_acting_as": "Robber",   // wave = order group 1-4 (wake order), NOT the window; role_acting_as enriched from PlayerRole.night_action_data
      "action_type": "swap_with_player", "targets": {...}, "result": {...}, "timestamp_order": 2 }
  ],
  "votes": { "12": 14, "13": null },          // EVERY player is a key; null = has not voted/abstained
  "results": { ... } | null                   // present once phase=results; winning_teams = list of lowercase tokens ⊂ {"village","werewolf","tanner"}, asserted as a SET
}
```

Tests: post-swap `current_role` correct; team `neutral` for Tanner; `votes` includes
all players; `DEBUG=False` → 403.

### B3. Timeout / timer fire hook — **FINALIZED** (shape below is implemented)

Only for **timeout** paths (action-skip-on-expiry; vote auto-finalize); happy-path
transitions use existing host endpoints (`advance-wave`, `end-discussion`,
`reveal-votes`). DEBUG-only. Mechanism (the review corrected the draft):

`apps/onuw/timers.py` `_registry` stores **`threading.Timer` objects, not callbacks**.
To fire synchronously: look up `f"{game_id}:{suffix}"`, then `timer.cancel()` (so the
wall-clock copy doesn't also fire) and call `timer.function(*timer.args)`. This
composes safely — there's no `ATOMIC_REQUESTS`, and `make_idempotent_callback` opens
its own `select_for_update` transaction and is phase-guarded, so firing a stale /
already-fired key is a safe no-op (cannot double-transition).

**Endpoint:** `POST /api/onuw/games/<id>/debug-fire-timer/`

**Request body:**
```jsonc
{ "key": "wave:1" | "wave:2" | "discussion" | "voting" | "current" }
```
- `wave:{n}` — `n` must be a non-negative integer; only `1` and `2` name a night window.
  Firing it closes that window now.
- `discussion`, `voting` — the phase timers.
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
- **Game WebSocket providers (corrected):** the game screen does NOT use
  `webSocketConnection` (that's the lobby's). `GameNotifier` uses its own inline
  providers in `game_notifier.dart`: `gameWebSocketProvider` (Provider.family, ~615),
  `gameWebSocketStreamProvider` (~634), `gameConnectionStateProvider` (~647). `switchTo`
  must invalidate `gameProvider(gameId)` **and** these three so the old player's socket
  is disposed and the new player's attaches.
- REST paths (note `/api/` prefix): guest `POST /api/auth/guest/` → `{access, refresh,
  user:{id, display_name}}`; lobby `POST /api/lobbies/`, `/api/lobbies/<code>/join/`,
  `/ready/`, `PATCH /api/lobbies/<code>/` (`{settings:{roles:{...}}}`, TitleCase keys),
  start `POST /api/onuw/lobbies/<code>/start/`; game `GET /api/onuw/games/<id>/me/`,
  `POST .../action/`, `.../advance-wave/`, `.../vote/`, `.../end-discussion/`,
  `.../reveal-votes/`, `GET .../results/`, `GET .../debug-state/`.
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
  guest's server-assigned `user_id` from the `POST /auth/guest/` response, create lobby,
  join all, ready all, PATCH role config, `start` with `debug.forced_assignment` keyed
  by those **stringified user_ids** (creation order does NOT affect role assignment —
  forced assignment is explicit). Returns a `DebugTable` holding each player's
  `{userId, displayName, accessToken, refreshToken, role}` + `gameId`.
- `switchTo(player)` → `adoptSession(player.user)` (writes token+user, sets authed state
  from the access token, NO refresh) + invalidate `gameProvider(gameId)`,
  `gameWebSocketProvider(gameId)`, `gameWebSocketStreamProvider(gameId)`,
  `gameConnectionStateProvider(gameId)`. Exactly one live WS.
- `driveAs(player, action)` → issue calls AS any player without changing the visible
  perspective, via the §D2 client. Covers night action, vote, end-discussion,
  advance-wave, reveal-votes.
- `oracle()` → `GET .../debug-state/`.
- `fireTimer(TimerKey)` → §B3 hook, the **single** coupling point (see §D4).
- `setConnected(player, bool)` → drop/restore that player's WS (manual disconnect toggle).

### D2. Debug API client

Issues REST with an **explicit** `Authorization: Bearer <token>` per call and
**attaches NO `AuthInterceptor`** (otherwise a 401 would trigger a refresh against the
global `TokenStorage` and cross-contaminate identities). On 401 it fails loudly, never
refreshes. Sets the WS `Origin` header for `driveAs`/connection helpers.

### D3. Debug toolbar (human, dev-only, `/debug` route under `if (Env.isDev)`)

Table setup (player-count + role-config presets from the **Base-Game-Only** section of
`recommended-setups.md`, already encoded in `RoleConfig._presets` — do NOT ingest
Daybreak setups; + the nine matrix scenarios; + a forced-assignment editor + seed
field); perspective switcher (lists players with true roles — debug only — tap to
become any); god panel (live oracle: original→current card, copied role, team, action
log, votes, center); auto-drive (auto-play night actions, advance wave, everyone votes,
end discussion, reveal votes, skip-timer via fireTimer); disconnect toggle; replay
(show/edit seed/assignment). Toolbar uses real wall-clock time.

### D4. Integration harness (`integration_test/`, never ships)

**Scenario-as-data DSL** — one Dart record per scenario:
`{ name, tags (e.g. uiCritical), playerCount, forcedAssignment, nightScript, voteScript,
expected, expectedUiStates }`. Author the **nine** scenarios mirroring `scenarios.md`.

Encoding rules the author needs (the review found these unauthorable otherwise):
- **Action target encoding** (`nightScript` entries `{actorUserId, actionType, targets}`):
  `peek_player {player_id}`; `peek_center {center_indices:[i,j]}` (exactly 2);
  `swap_with_player {player_id}`; `swap_others {player_ids:[a,b]}`;
  `swap_with_center {center_index:i}`; lone-Werewolf center peek =
  `see_team {center_index:i}`; **declined/optional-skip = same action_type with empty
  `targets:{}`** (e.g. scenario 2's declined lone-WW peek — no fire-timer needed).
- **Roles/teams:** role names TitleCase; team tokens `{werewolf,village,neutral}`
  (Tanner=neutral); `winning_teams` lowercase, asserted as a **set**; elimination
  reasons ∈ `{"vote","hunter_chain"}`; eliminations as a set of user ids.
- **Scenario 7** = Sub-Case A only, single entry, not `uiCritical`; assert via oracle
  (Alice/Bob/Carol `team==werewolf`; Dave's Seer peek result = `Doppelganger` from the
  night_actions_log). "Who-sees-what" = each seer's recorded peek result, not a separate
  field.
- **Oracle checkpoints** are per-wave boundaries (the oracle reflects committed state
  after a wave fully resolves; intra-wave ordering like Seer-before-Robber is asserted
  via each actor's recorded `result` in the log, not a mid-wave snapshot). Always assert
  the final-state table.

**API runner** (full matrix every run): drive via `DebugTableController` + §D2 client,
assert `oracle()` at checkpoints and `results` for eliminations/reasons/winners.

**UI runner** (`uiCritical` subset, ~5-6: scenarios 1/3 Seer peek variants, 2/5 lone-WW
peek, 4 multi-wave, 5 Hunter-chain results, 10 three-way tie): boot the real widget tree,
`switchTo` the relevant player, drive by **tapping real widgets**, capture
`RepaintBoundary.toImage()` PNGs (inside `runAsync`, fonts loaded) to
`integration_test/screenshots/<scenario>/NN-<state>.png`. **Assert the rendered role
against `original_role`** (current_role is hidden pre-results by design — asserting
rendered==oracle.current_role can never pass and would tempt leaking it); assert
post-swap truth against the **oracle**.

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
All **nine** scenarios fully populated as data (no empty `expected`/TODO); the API runner
**compiles with complete assertion code** (asserts populated `expected` against
oracle/results); the UI runner captures filmstrips for the `uiCritical` subset. Only the
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
